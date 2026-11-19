import 'package:open_api_forked/src/codec/free_form.dart';
import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/components.dart';
import 'package:open_api_forked/src/v3/external_docs.dart';
import 'package:open_api_forked/src/v3/metadata.dart';
import 'package:open_api_forked/src/v3/operation.dart';
import 'package:open_api_forked/src/v3/path.dart';
import 'package:open_api_forked/src/v3/security.dart';
import 'package:open_api_forked/src/v3/server.dart';
import 'package:open_api_forked/src/validation.dart';

/// This is the root document object of the OpenAPI document.
final class APIDocument extends APIObject {
  /// Creates an empty specification.
  APIDocument();

  @override
  Map<String, Object?> get toStringFields => {
    'openapi': version,
    'title': info?.title,
    'version': info?.version,
    'paths': paths.length,
    'webhooks': webhooks?.length,
  };

  /// Creates a specification from decoded JSON or YAML document object.
  ///
  /// Throws an [OpenApiFormatException] if the document does not have the
  /// shape OpenAPI requires, for example a string where an object is
  /// expected, or a `$ref` that points to another file or to nothing in this
  /// document.
  APIDocument.fromMap(Map<String, dynamic> map) {
    final prepared = Map<String, dynamic>.from(
      _prepare(map, map, '#', _Node.object, _References.of(map))! as Map,
    );
    decode(KeyedArchive.unarchive(prepared, allowReferences: true));
  }

  /// Fields of OpenAPI objects whose values are free-form data: schema
  /// `example`/`default`/`enum`/`const`, the `example` of parameters, headers and
  /// media types, an Example's `value`, and server variable
  /// `default`/`enum`.
  static const _freeFormFields = {
    'example',
    'default',
    'enum',
    'value',
    'const',
  };

  /// Link fields holding constants or runtime expressions.
  static const _freeFormLinkFields = {'parameters', 'requestBody'};

  /// Fields whose value is a map from names to OpenAPI objects.
  static const _nameMapFields = {
    'schemas',
    'parameters',
    'examples',
    'requestBodies',
    'headers',
    'securitySchemes',
    'properties',
    'content',
    'encoding',
    'variables',
    'flows',
  };

  /// Fields whose value is a map from names to strings.
  static const _stringMapFields = {'mapping', 'scopes'};

  /// Returns a copy of [node] in which free-form values are wrapped in
  /// [FreeForm], so that [KeyedArchive] keeps them as data, and checks
  /// every other `$ref` before [KeyedArchive] resolves it, so that bad
  /// references fail with a clear message instead of a [TypeError], and
  /// references into other files are not silently resolved against this
  /// document.
  ///
  /// Which values are free-form depends on their position: in a name map
  /// such as `examples` or `properties`, a key like `default` is a name.
  ///
  /// Free-form data that a `$ref` points into (such as shared definitions
  /// under an `x-` key) is read as OpenAPI objects instead, see
  /// [_References].
  static Object? _prepare(
    Map<String, dynamic> root,
    Object? node,
    String pointer,
    _Node kind,
    _References refs,
  ) {
    if (node is List) {
      return [
        for (final (i, item) in node.indexed)
          _prepare(root, item, appendPointer(pointer, i), _Node.object, refs),
      ];
    }
    if (node is! Map) {
      return node;
    }
    if (kind != _Node.passThrough) {
      _checkReference(root, node, pointer);
    }
    return <dynamic, dynamic>{
      for (final MapEntry(:key, :value) in node.entries)
        key: switch (key) {
          String() => switch (refs.kindOf(
            kind,
            key,
            value,
            appendPointer(pointer, key),
          )) {
            null => FreeForm(value, appendPointer(pointer, key)),
            final child => _prepare(
              root,
              value,
              appendPointer(pointer, key),
              child,
              refs,
            ),
          },
          _ => value,
        },
    };
  }

  static void _checkReference(
    Map<String, dynamic> root,
    Map<dynamic, dynamic> node,
    String pointer,
  ) {
    final ref = node[r'$ref'];
    if (ref is String) {
      if (!ref.startsWith('#')) {
        throw OpenApiFormatException(
          "Reference '$ref' is not a local reference ('#/...'); references "
          'to other documents are not supported.',
          pointer: appendPointer(pointer, r'$ref'),
          source: ref,
        );
      }
      if (_resolvePointer(root, ref) is! Map) {
        throw OpenApiFormatException(
          "Reference '$ref' does not point to an object in document.",
          pointer: appendPointer(pointer, r'$ref'),
          source: ref,
        );
      }
      // A chain of objects that are only `$ref`s must end somewhere, or
      // looking up a missing key would follow it forever.
      final seen = {ref};
      var target = _resolvePointer(root, ref);
      while (target is Map && target[r'$ref'] is String) {
        final next = target[r'$ref'] as String;
        if (!seen.add(next)) {
          throw OpenApiFormatException(
            "Reference '$ref' is part of a cycle of references.",
            pointer: appendPointer(pointer, r'$ref'),
            source: ref,
          );
        }
        target = _resolvePointer(root, next);
      }
    }
  }

  /// Walks [ref] from [root] the way [KeyedArchive] resolves it, including
  /// following `$ref`s met along the way.
  static dynamic _resolvePointer(
    Map<String, dynamic> root,
    String ref, [
    int depth = 0,
  ]) {
    if (depth > 32) {
      return null;
    }
    dynamic target = root;
    for (final segment in Uri.parse(Uri.parse(ref).fragment).pathSegments) {
      if (target is! Map) {
        return null;
      }
      final next = target[segment];
      final via = target[r'$ref'];
      if (next == null && via is String && via.startsWith('#')) {
        final resolved = _resolvePointer(root, via, depth + 1);
        target = resolved is Map ? resolved[segment] : null;
      } else {
        target = next;
      }
    }
    return target;
  }

  /// Checks this document for missing REQUIRED fields and similar rule
  /// violations, and returns one [OpenApiFormatException] per problem.
  ///
  /// Decoding is lenient: [APIDocument.fromMap] accepts a document that
  /// lacks, say, a response `description`, so that tools can still read it.
  /// Call this to find such problems. An empty list means none were found;
  /// it does not check everything the specification requires.
  ///
  /// `$ref`s are not followed: a referenced object is checked where it is
  /// defined.
  List<OpenApiFormatException> validate() => validateDocument(this);

  /// Every operation in [paths], with its path and method.
  ///
  /// Paths come in map order (document order when decoded); within a path,
  /// methods come in the fixed order get, put, post, delete, options, head,
  /// patch, trace. `x-` extension keys in [paths] are skipped. A path item
  /// that is a `$ref` yields the operations of its target, so a target
  /// used by several paths yields the same [APIOperation]s for each (and
  /// `validate()` reports it). This is a
  /// lazy iterable: each iteration, including `.length`, walks the paths
  /// again.
  ///
  /// ```dart
  /// for (final (:path, :method, :operation, pathItem: _) in doc.operations) {
  ///   print('$method $path ${operation.id}');
  /// }
  /// ```
  Iterable<
    ({String path, APIPath pathItem, String method, APIOperation operation})
  >
  get operations sync* {
    for (final MapEntry(key: path, value: pathItem) in paths.entries) {
      if (path.startsWith('x-')) {
        continue;
      }
      for (final MapEntry(key: method, value: operation)
          in pathItem.operations.entries) {
        yield (
          path: path,
          pathItem: pathItem,
          method: method,
          operation: operation,
        );
      }
    }
  }

  /// This string MUST be the semantic version number of the OpenAPI Specification version that the OpenAPI document uses.
  ///
  /// REQUIRED. The openapi field SHOULD be used by tooling specifications and clients to interpret the OpenAPI document. This is not related to the API info.version string.
  String? version = '3.0.0';

  /// Provides metadata about the API.
  ///
  /// REQUIRED. The metadata MAY be used by tooling as required.
  APIInfo? info;

  /// An array of [APIServerDescription], which provide connectivity information to a target server.
  ///
  /// If the servers property is not provided, or is an empty array, the default value would be a [APIServerDescription] with a url value of /.
  List<APIServerDescription>? servers;

  /// The available paths and operations for the API.
  ///
  /// REQUIRED in OpenAPI 3.0. In 3.1 a document needs at least one of
  /// [paths], [components] or [webhooks]; an empty map is then not
  /// written when the document had no `paths`.
  Map<String, APIPath> paths = {};

  /// Incoming requests the API may send to its consumers, keyed by a name
  /// (OpenAPI 3.1). `null` when the document has no `webhooks`.
  ///
  /// The operations are not part of [operations].
  Map<String, APIPath>? webhooks;

  /// The default `$schema` for the schemas in this document (OpenAPI 3.1).
  String? jsonSchemaDialect;

  /// Whether the document has `paths`: a non-empty [paths], or `paths`
  /// in the decoded input. OpenAPI 3.1 documents may leave them out.
  bool get hasPaths => paths.isNotEmpty || _decodedPaths;

  bool _decodedPaths = false;

  /// Whether [version] is an OpenAPI 3.1 version (`3.1.x`).
  bool get isOpenApi31 => version?.startsWith('3.1.') ?? false;

  /// An element to hold various schemas for the specification.
  APIComponents? components;

  /// A declaration of which security mechanisms can be used across the API.
  ///
  /// The list of values includes alternative security requirement objects that can be used. Only one of the security requirement objects need to be satisfied to authorize a request. Individual operations can override this definition.
  List<APISecurityRequirement>? security;

  /// A list of tags used by the specification with additional metadata.
  ///
  /// The order of the tags can be used to reflect on their order by the parsing tools. Not all tags that are used by the Operation Object must be declared. The tags that are not declared MAY be organized randomly or based on the tools' logic. Each tag name in the list MUST be unique.
  List<APITag> tags = [];

  /// Additional external documentation.
  APIExternalDocumentation? externalDocs;

  Map<String, dynamic> asMap() {
    return KeyedArchive.archive(this, allowReferences: true);
  }

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    version = object.decode('openapi');
    info = object.decodeObject('info', () => APIInfo.empty());
    jsonSchemaDialect = object.decode('jsonSchemaDialect');
    servers = object.decodeObjects(
      'servers',
      () => APIServerDescription.empty(),
    );
    paths = object.decodeObjectMap('paths', () => APIPath()) ?? {};
    _decodedPaths = object.rawValue('paths') != null;
    webhooks = object.decodeObjectMap('webhooks', () => APIPath());
    components = object.decodeObject('components', () => APIComponents());
    security = object.decodeObjects(
      'security',
      () => APISecurityRequirement.empty(),
    );
    tags = object.decodeObjects('tags', () => APITag.empty()) ?? [];
    externalDocs = object.decodeObject(
      'externalDocs',
      () => APIExternalDocumentation.empty(),
    );
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    if (version == null || info == null) {
      throw ArgumentError(
        "APIDocument must have non-null values for: 'version', 'info'.",
      );
    }

    object.encode('openapi', version);
    object.encodeObject('info', info);
    object.encode('jsonSchemaDialect', jsonSchemaDialect);
    object.encodeObjects('servers', servers);
    object.encodeObjectMap('paths', paths, omitEmpty: isOpenApi31);
    object.encodeObjectMap('webhooks', webhooks);
    object.encodeObject('components', components);
    object.encodeObjects('security', security);
    object.encodeObjects('tags', tags, omitEmpty: true);
    object.encodeObject('externalDocs', externalDocs);
  }
}

/// What a map in a document is, for deciding which of its values are
/// free-form.
enum _Node {
  /// An OpenAPI object, such as a schema or an operation.
  object,

  /// The Components Object.
  components,

  /// A Link Object.
  link,

  /// A map from names to OpenAPI objects, such as `properties`.
  nameMap,

  /// A map from names to OpenAPI objects that may also hold `x-`
  /// extensions: the Paths, Responses and Callback Objects.
  extensibleMap,

  /// A map from names to Link Objects.
  linkMap,

  /// A map from names to Callback Objects (`callbacks`).
  callbackMap,

  /// A map from names to strings, or free-form data.
  data,

  /// Free-form data on the way to something a `$ref` points into: only
  /// the parts on that way are read as objects.
  passThrough;

  /// The kind of the value for [key] in a map of this kind.
  _Node child(String key, Object? value) => switch (this) {
    _ when value is! Map => _Node.object,
    nameMap || extensibleMap || passThrough => _Node.object,
    components => switch (key) {
      'links' => _Node.linkMap,
      'callbacks' => _Node.callbackMap,
      _ => _Node.nameMap,
    },
    linkMap => _Node.link,
    callbackMap => _Node.extensibleMap,
    data => _Node.data,
    object || link => switch (key) {
      'components' => _Node.components,
      'paths' || 'responses' => _Node.extensibleMap,
      'webhooks' => _Node.nameMap,
      'links' => _Node.linkMap,
      'callbacks' => _Node.callbackMap,
      _ when APIDocument._stringMapFields.contains(key) => _Node.data,
      _ when APIDocument._nameMapFields.contains(key) => _Node.nameMap,
      _ => _Node.object,
    },
  };

  /// Whether [value], for [key] in a map of this kind, is free-form data.
  bool isFreeForm(String key, Object? value) => switch (this) {
    object =>
      key.startsWith('x-') ||
          APIDocument._freeFormFields.contains(key) ||
          // `examples` as a list, as in JSON Schema or converted Swagger 2
          // documents, which 3.0 does not have.
          (key == 'examples' && value is List),
    link =>
      key.startsWith('x-') || APIDocument._freeFormLinkFields.contains(key),
    components || extensibleMap => key.startsWith('x-'),
    nameMap || linkMap || callbackMap || data || passThrough => false,
  };
}

/// The `$ref`s of a document, for reading free-form data that a `$ref`
/// points into (such as shared definitions under an `x-` key) as objects.
final class _References {
  _References._(this.targets, this.prefixes);

  /// Collects the `$ref`s outside free-form data, including those in
  /// free-form data that other `$ref`s point into, until no more are found.
  factory _References.of(Map<String, dynamic> document) {
    var refs = _References._({}, {});
    while (true) {
      final found = _References._({}, {});
      refs._collect(document, '#', _Node.object, found);
      if (found.targets.length == refs.targets.length) {
        return refs;
      }
      refs = found;
    }
  }

  /// The pointers that `$ref`s point to, as written (escaped).
  final Set<String> targets;

  /// The pointers that `$ref`s pass through on the way to their targets.
  final Set<String> prefixes;

  void _add(String ref) {
    if (!ref.startsWith('#/')) {
      return;
    }
    // As [appendPointer] writes them: percent-decoded, `~` escapes kept.
    var pointer = '#';
    for (final segment in ref.substring(2).split('/')) {
      pointer = '$pointer/${_decode(segment)}';
      prefixes.add(pointer);
    }
    targets.add(pointer);
  }

  static String _decode(String segment) {
    try {
      return Uri.decodeComponent(segment);
    } on ArgumentError {
      return segment;
    }
  }

  /// How the value for [key] at [pointer] is read in a map of [kind]:
  /// null for free-form data.
  _Node? kindOf(_Node kind, String key, Object? value, String pointer) {
    if (kind != _Node.passThrough && !kind.isFreeForm(key, value)) {
      return kind.child(key, value);
    }
    if (targets.contains(pointer)) {
      return _Node.object;
    }
    if (value is Map && prefixes.contains(pointer)) {
      return _Node.passThrough;
    }
    return null;
  }

  void _collect(Object? node, String pointer, _Node kind, _References found) {
    if (node is List) {
      if (kind != _Node.passThrough) {
        for (final (i, item) in node.indexed) {
          _collect(item, appendPointer(pointer, i), _Node.object, found);
        }
      }
      return;
    }
    if (node is! Map) {
      return;
    }
    final ref = node[r'$ref'];
    if (ref is String && kind != _Node.passThrough) {
      found._add(ref);
    }
    node.forEach((key, value) {
      if (key is String) {
        final child = kindOf(kind, key, value, appendPointer(pointer, key));
        if (child != null) {
          _collect(value, appendPointer(pointer, key), child, found);
        }
      }
    });
  }
}
