/// Thrown when a document does not have the shape OpenAPI requires, such as
/// a string where an object is expected or a `$ref` that points nowhere.
///
/// [pointer] is a JSON pointer to the offending value, such as
/// `#/paths/~1pets/get/responses/200`.
final class OpenApiFormatException implements FormatException {
  OpenApiFormatException(this.message, {required this.pointer, this.source});

  @override
  final String message;

  /// JSON pointer (RFC 6901, as a URI fragment) to the offending value.
  final String pointer;

  /// The offending value, if any.
  @override
  final Object? source;

  @override
  int? get offset => null;

  @override
  String toString() => 'OpenApiFormatException: $message (at $pointer)';
}

/// Appends [key] to the JSON [pointer], escaping `~` and `/` (RFC 6901).
String appendPointer(String pointer, Object key) =>
    '$pointer/${key.toString().replaceAll('~', '~0').replaceAll('/', '~1')}';
