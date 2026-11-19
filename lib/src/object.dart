import 'package:meta/meta.dart';
import 'package:open_api_forked/src/codec/keyed_archive.dart';

/// Base class of every object in an OpenAPI document.
///
/// Subclasses read their fields in [decode] and write them in [encode].
class APIObject {
  /// If this object is a `$ref`, the path of the referenced object, e.g.
  /// `/components/schemas/Pet` for `#/components/schemas/Pet`.
  ///
  /// When decoded, a reference object also exposes the fields of the object
  /// it references.
  Uri? referenceURI;

  /// Specification extensions: the `x-` keys of this object.
  Map<String, dynamic> extensions = {};

  @mustCallSuper
  void decode(KeyedArchive object) {
    referenceURI = object.referenceURI;

    final extensionKeys = object.keys.where((k) => k.startsWith('x-'));
    for (final key in extensionKeys) {
      extensions[key] = object.decode<Object?>(key);
    }
  }

  @mustCallSuper
  void encode(KeyedArchive object) {
    final invalidKeys = extensions.keys
        .where((key) => !key.startsWith('x-'))
        .map((key) => "'$key'")
        .toList();
    if (invalidKeys.isNotEmpty) {
      throw ArgumentError(
        "extension keys must start with 'x-'. The following keys are invalid: ${invalidKeys.join(", ")}",
      );
    }

    extensions.forEach((key, value) {
      object.encode(key, value);
    });
  }
}
