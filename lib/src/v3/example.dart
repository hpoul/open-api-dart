import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';

/// An [Example Object](https://spec.openapis.org/oas/v3.0.3#example-object),
/// used in the `examples` of parameters, headers, media types and
/// components.
final class APIExample extends APIObject {
  APIExample({this.summary, this.description, this.value, this.externalValue});

  APIExample.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'summary': summary,
    'externalValue': externalValue,
  };

  /// A short description of the example.
  String? summary;

  /// A long description of the example.
  ///
  /// CommonMark syntax MAY be used for rich text representation.
  String? description;

  /// The example value, kept as decoded. Mutually exclusive with
  /// [externalValue].
  Object? value;

  /// A URL pointing to the example, for values that can't easily be
  /// included in the document. Mutually exclusive with [value].
  Uri? externalValue;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    summary = object.decode('summary');
    description = object.decode('description');
    value = object.decode<Object?>('value');
    externalValue = object.decode('externalValue');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('summary', summary);
    object.encode('description', description);
    object.encode('value', value);
    object.encode('externalValue', externalValue);
  }
}
