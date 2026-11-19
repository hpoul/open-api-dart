import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/encoding.dart';
import 'package:open_api_forked/src/v3/example.dart';
import 'package:open_api_forked/src/v3/schema.dart';

/// Each [APIMediaType] provides schema and examples for the media type identified by its key.
final class APIMediaType extends APIObject {
  APIMediaType({this.schema, Map<String, APIEncoding>? encoding})
    : encoding = encoding ?? {};
  APIMediaType.empty();

  @override
  Map<String, Object?> get toStringFields => {'schema': schema};

  /// The schema defining the type used for the request body.
  APISchemaObject? schema;

  /// A map between a property name and its encoding information.
  ///
  /// The key, being the property name, MUST exist in the schema as a property. The encoding object SHALL only apply to requestBody objects when the media type is multipart or application/x-www-form-urlencoded.
  Map<String, APIEncoding> encoding = {};

  /// An example of the value, kept as decoded. Mutually exclusive with
  /// [examples].
  Object? example;

  /// Examples of the value, by name. Mutually exclusive with [example].
  Map<String, APIExample> examples = {};

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    schema = object.decodeObject('schema', () => APISchemaObject());
    encoding = object.decodeObjectMap('encoding', () => APIEncoding()) ?? {};
    example = object.decode<Object?>('example');
    examples =
        object.decodeObjectMap('examples', () => APIExample.empty()) ?? {};
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encodeObject('schema', schema);
    object.encodeObjectMap('encoding', encoding, omitEmpty: true);
    object.encode('example', example);
    object.encodeObjectMap('examples', examples, omitEmpty: true);
  }
}
