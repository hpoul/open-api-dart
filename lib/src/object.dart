import 'package:meta/meta.dart';
import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/codec/list_archive.dart';

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
      extensions[key] = switch (object.decode<Object?>(key)) {
        // An extension that a `$ref` points into is read as objects;
        // hand out plain data all the same.
        final KeyedArchive value => value.toPrimitive(),
        final ListArchive value => value.toPrimitive(),
        final value => value,
      };
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

  /// How deeply [toString] calls are nested, so that nested objects (and
  /// cycles built in code, such as `schema.items = schema`) stop at
  /// [_maxToStringDepth].
  static int _toStringDepth = 0;
  static const _maxToStringDepth = 3;

  /// A short, single-line description for debugging, such as
  /// `APIParameter(name: id, in: path)`, or `APISchemaObject($ref:
  /// #/components/schemas/Pet)` for a reference.
  ///
  /// Maps show their keys (`{200, 404}`), lists their elements (`[a, b]`),
  /// strings only their first line, shortened. Objects nested more than a
  /// few levels deep print as `Type(…)`. Types with nothing to show print
  /// as `Type()`.
  @override
  String toString() {
    final ref = referenceURI;
    if (ref != null) {
      return '$runtimeType(\$ref: #${ref.path})';
    }
    if (_toStringDepth >= _maxToStringDepth) {
      return '$runtimeType(…)';
    }
    _toStringDepth++;
    try {
      final fields = [
        for (final MapEntry(:key, :value) in toStringFields.entries)
          if (value != null &&
              !(value is Iterable && value.isEmpty) &&
              !(value is Map && value.isEmpty))
            '$key: ${switch (value) {
              Map() => '{${value.keys.map(_short).join(', ')}}',
              Iterable() => '[${value.map(_short).join(', ')}]',
              Enum(:final name) => name,
              _ => _short(value),
            }}',
      ];
      return '$runtimeType(${fields.join(', ')})';
    } finally {
      _toStringDepth--;
    }
  }

  static String _short(Object? value) {
    if (value is! String) {
      return '$value';
    }
    final line = value.split('\n').first.trim();
    return line.length > 40 || line.length < value.trim().length
        ? '${line.length > 40 ? line.substring(0, 40) : line}…'
        : line;
  }
}
