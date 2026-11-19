import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/path.dart';

/// A map of possible out-of band callbacks related to the parent operation.
///
/// Each value in the map is a [APIPath] that describes a set of requests that may be initiated by the API provider and the expected responses. The key value used to identify the callback object is an expression, evaluated at runtime, that identifies a URL to use for the callback operation.
final class APICallback extends APIObject {
  APICallback({Map<String, APIPath>? paths}) : paths = paths ?? {};
  APICallback.empty() : paths = {};

  /// Callback paths.
  ///
  /// The key that identifies the [APIPath] is a runtime expression that can be evaluated in the context of a runtime HTTP request/response to identify the URL to be used for the callback request. A simple example might be $request.body#/url.
  Map<String, APIPath> paths = {};

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    paths = {};
    for (final key in object.keys) {
      // Extensions are decoded by `super.decode`.
      if (key.startsWith('x-') || key == r'$ref') {
        continue;
      }
      if (object[key] is! KeyedArchive) {
        throw OpenApiFormatException(
          'Expected a path item object in callback.',
          pointer: object.pointerTo(key),
          source: object[key],
        );
      }
      paths[key] = object.decodeObject(key, () => APIPath())!;
    }
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    paths.forEach((key, path) {
      object.encodeObject(key, path);
    });
  }
}
