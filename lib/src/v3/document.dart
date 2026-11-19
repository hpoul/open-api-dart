import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/components.dart';
import 'package:open_api_forked/src/v3/metadata.dart';
import 'package:open_api_forked/src/v3/path.dart';
import 'package:open_api_forked/src/v3/security.dart';
import 'package:open_api_forked/src/v3/server.dart';

/// This is the root document object of the OpenAPI document.
final class APIDocument extends APIObject {
  /// Creates an empty specification.
  APIDocument();

  /// Creates a specification from decoded JSON or YAML document object.
  ///
  /// Throws an [OpenApiFormatException] if the document does not have the
  /// shape OpenAPI requires, for example a string where an object is
  /// expected, or a `$ref` that points to another file or to nothing in this
  /// document.
  APIDocument.fromMap(Map<String, dynamic> map) {
    _checkReferences(map, map, '#');
    decode(KeyedArchive.unarchive(map, allowReferences: true));
  }

  /// Keys whose values are free-form data, not OpenAPI objects. A `$ref`
  /// in there is just data, so it is not checked.
  static const _freeFormKeys = {
    'example',
    'examples',
    'default',
    'enum',
    'value',
  };

  /// Validates every `$ref` in [node] before [KeyedArchive] resolves them,
  /// so that bad references fail with a clear message instead of a
  /// [TypeError], and references into other files are not silently
  /// resolved against this document.
  static void _checkReferences(
    Map<String, dynamic> root,
    Object? node,
    String pointer,
  ) {
    if (node is List) {
      for (final (i, item) in node.indexed) {
        _checkReferences(root, item, appendPointer(pointer, i));
      }
      return;
    }
    if (node is! Map) {
      return;
    }
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
    node.forEach((key, value) {
      if (key is String &&
          (key.startsWith('x-') || _freeFormKeys.contains(key))) {
        return;
      }
      _checkReferences(root, value, appendPointer(pointer, key as Object));
    });
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
  /// REQUIRED.
  Map<String, APIPath> paths = {};

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

  Map<String, dynamic> asMap() {
    return KeyedArchive.archive(this, allowReferences: true);
  }

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    version = object.decode('openapi');
    info = object.decodeObject('info', () => APIInfo.empty())!;
    servers = object.decodeObjects(
      'servers',
      () => APIServerDescription.empty(),
    );
    paths = object.decodeObjectMap('paths', () => APIPath()) ?? {};
    components = object.decodeObject('components', () => APIComponents());
    security = object.decodeObjects(
      'security',
      () => APISecurityRequirement.empty(),
    );
    tags = object.decodeObjects('tags', () => APITag.empty()) ?? [];
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
    object.encodeObjects('servers', servers);
    object.encodeObjectMap('paths', paths);
    object.encodeObject('components', components);
    object.encodeObjects('security', security);
    object.encodeObjects('tags', tags, omitEmpty: true);
  }
}
