import 'package:meta/meta.dart';
import 'package:open_api_forked/src/codec/keyed_archive.dart';

/// Base class of every object in an OpenAPI document.
///
/// Subclasses read their fields in [decode] and write them in [encode].
/// Both take the package's internal `KeyedArchive`; calling or overriding
/// them from outside this package is not supported. Use
/// `APIDocument.fromMap` and `asMap()` instead.
abstract base class APIObject {
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
    object.rememberEmptyKeys(this);

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

  /// The fields that [toString] shows. Null and empty values are left out.
  @protected
  Map<String, Object?> get toStringFields => const {};

  /// A short description for debugging, such as
  /// `APIParameter(name: id, in: path)`, or `APISchemaObject($ref:
  /// #/components/schemas/Pet)` for a reference.
  @override
  String toString() {
    final ref = referenceURI;
    if (ref != null) {
      return '$runtimeType(\$ref: #${ref.path})';
    }
    final fields = [
      for (final MapEntry(:key, :value) in toStringFields.entries)
        if (value != null &&
            !(value is Iterable && value.isEmpty) &&
            !(value is Map && value.isEmpty))
          '$key: ${switch (value) {
            Map() => '[${value.keys.join(', ')}]',
            Iterable() => '[${value.join(', ')}]',
            Enum(:final name) => name,
            _ => value,
          }}',
    ];
    return '$runtimeType(${fields.join(', ')})';
  }
}
