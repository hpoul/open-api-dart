import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/src/object.dart';

/// A [Discriminator Object](https://spec.openapis.org/oas/v3.0.3#discriminator-object):
/// names the property whose value tells which `oneOf`/`anyOf` (or `allOf`
/// subtype) schema a payload matches.
final class APIDiscriminator extends APIObject {
  APIDiscriminator(this.propertyName, {Map<String, String>? mapping})
    : mapping = mapping ?? {};

  APIDiscriminator.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'propertyName': propertyName,
    'mapping': mapping,
  };

  /// The name of the property in the payload that holds the discriminator
  /// value.
  ///
  /// REQUIRED.
  String? propertyName;

  /// Maps payload values to schema names or references, such as
  /// `{'dog': '#/components/schemas/Dog'}`. Kept as written: the values are
  /// not resolved.
  Map<String, String> mapping = {};

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    propertyName = object.decode('propertyName');
    final decoded = object.decode<Map<String, Object?>>('mapping');
    mapping = {
      for (final MapEntry(:key, :value) in (decoded ?? {}).entries)
        key: value is String
            ? value
            : throw OpenApiFormatException(
                'Expected a string schema name or reference.',
                pointer: appendPointer(object.pointerTo('mapping'), key),
                source: value,
              ),
    };
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('propertyName', propertyName);
    object.encode('mapping', mapping, omitEmpty: true);
  }
}
