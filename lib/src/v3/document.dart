import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/components.dart';
import 'package:open_api_forked/src/v3/metadata.dart';
import 'package:open_api_forked/src/v3/path.dart';
import 'package:open_api_forked/src/v3/security.dart';
import 'package:open_api_forked/src/v3/server.dart';

/// This is the root document object of the OpenAPI document.
class APIDocument extends APIObject {
  /// Creates an empty specification.
  APIDocument();

  /// Creates a specification from decoded JSON or YAML document object.
  ///
  /// Throws an [ArgumentError] if the document contains a `$ref` that points
  /// to another file, or that does not point to an object in this document.
  APIDocument.fromMap(Map<String, dynamic> map) {
    _checkReferences(map, map);
    decode(KeyedArchive.unarchive(map, allowReferences: true));
  }

  /// Validates every `$ref` in [node] before [KeyedArchive] resolves them,
  /// so that bad references fail with a clear message instead of a
  /// [TypeError], and references into other files are not silently
  /// resolved against this document.
  static void _checkReferences(Map root, dynamic node) {
    if (node is List) {
      for (final item in node) {
        _checkReferences(root, item);
      }
      return;
    }
    if (node is! Map) {
      return;
    }
    final ref = node[r"$ref"];
    if (ref is String) {
      if (!ref.startsWith("#")) {
        throw ArgumentError(
            "Invalid document. Reference '$ref' points to another document; "
            "only references within the same document ('#/...') are supported.");
      }
      dynamic target = root;
      for (final segment in Uri.parse(Uri.parse(ref).fragment).pathSegments) {
        target = target is Map ? target[segment] : null;
      }
      if (target is! Map) {
        throw ArgumentError(
            "Invalid document. Reference '$ref' does not point to an object "
            "in document.");
      }
    }
    for (final value in node.values) {
      _checkReferences(root, value);
    }
  }

  /// This string MUST be the semantic version number of the OpenAPI Specification version that the OpenAPI document uses.
  ///
  /// REQUIRED. The openapi field SHOULD be used by tooling specifications and clients to interpret the OpenAPI document. This is not related to the API info.version string.
  String? version = "3.0.0";

  /// Provides metadata about the API.
  ///
  /// REQUIRED. The metadata MAY be used by tooling as required.
  APIInfo? info;

  /// An array of [APIServerDescription], which provide connectivity information to a target server.
  ///
  /// If the servers property is not provided, or is an empty array, the default value would be a [APIServerDescription] with a url value of /.
  List<APIServerDescription?>? servers;

  /// The available paths and operations for the API.
  ///
  /// REQUIRED.
  Map<String, APIPath?>? paths;

  /// An element to hold various schemas for the specification.
  APIComponents? components;

  /// A declaration of which security mechanisms can be used across the API.
  ///
  /// The list of values includes alternative security requirement objects that can be used. Only one of the security requirement objects need to be satisfied to authorize a request. Individual operations can override this definition.
  List<APISecurityRequirement?>? security;

  /// A list of tags used by the specification with additional metadata.
  ///
  /// The order of the tags can be used to reflect on their order by the parsing tools. Not all tags that are used by the Operation Object must be declared. The tags that are not declared MAY be organized randomly or based on the tools' logic. Each tag name in the list MUST be unique.
  List<APITag?>? tags;

  Map<String, dynamic> asMap() {
    return KeyedArchive.archive(this, allowReferences: true);
  }

  void decode(KeyedArchive object) {
    super.decode(object);

    version = object.decode("openapi");
    info = object.decodeObject("info", () => APIInfo.empty())!;
    servers =
        object.decodeObjects("servers", () => APIServerDescription.empty());
    paths = object.decodeObjectMap("paths", () => APIPath());
    components = object.decodeObject("components", () => APIComponents());
    security =
        object.decodeObjects("security", () => APISecurityRequirement.empty());
    tags = object.decodeObjects("tags", () => APITag.empty());
  }

  void encode(KeyedArchive object) {
    super.encode(object);

    if (version == null || info == null || paths == null) {
      throw ArgumentError(
          "APIDocument must have non-null values for: 'version', 'info', 'paths'.");
    }

    object.encode("openapi", version);
    object.encodeObject("info", info);
    object.encodeObjects("servers", servers);
    object.encodeObjectMap("paths", paths);
    object.encodeObject("components", components);
    object.encodeObjects("security", security);
    object.encodeObjects("tags", tags);
  }
}
