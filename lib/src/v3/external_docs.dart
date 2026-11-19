import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';

/// An [External Documentation Object](https://spec.openapis.org/oas/v3.0.3#external-documentation-object):
/// a reference to documentation outside the document.
final class APIExternalDocumentation extends APIObject {
  APIExternalDocumentation(this.url, {this.description});

  APIExternalDocumentation.empty();

  @override
  Map<String, Object?> get toStringFields => {'url': url};

  /// A short description of the target documentation.
  ///
  /// CommonMark syntax MAY be used for rich text representation.
  String? description;

  /// The URL of the target documentation.
  ///
  /// REQUIRED.
  Uri? url;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    description = object.decode('description');
    url = object.decode('url');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('description', description);
    object.encode('url', url);
  }
}
