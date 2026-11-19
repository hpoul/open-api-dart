/// Thrown when a document does not have the shape OpenAPI requires, such as
/// a string where an object is expected or a `$ref` that points nowhere.
///
/// [pointer] locates the offending value, such as
/// `#/paths/~1pets/get/responses/200`.
final class OpenApiFormatException implements FormatException {
  const OpenApiFormatException(
    this.message, {
    required this.pointer,
    this.source,
  });

  @override
  final String message;

  /// A JSON pointer (RFC 6901) to the offending value, prefixed with `#`.
  ///
  /// `~` and `/` in keys are escaped as `~0` and `~1`; nothing is
  /// percent-encoded, so `{id}` stays readable. A value reached through a
  /// `$ref` is reported at the referencing object.
  final String pointer;

  /// The offending value, if any. Objects and lists are internal views of
  /// the decoded data, not the caller's original map or list.
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
