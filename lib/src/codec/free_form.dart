import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/codec/resolver.dart';
import 'package:open_api_forked/src/exception.dart';

/// Free-form data in a document, such as an `example`, a schema `default`
/// or an `x-` extension value.
///
/// [KeyedArchive] keeps it as is: maps inside are not turned into archives,
/// and a `$ref` inside is data, not a reference.
final class FreeForm {
  FreeForm(Object? value, this.pointer) : value = _plain(value, pointer);

  /// Where the value is in its document.
  final String pointer;

  KeyedArchive? _archive;

  /// The value as an archive, for a `$ref` that points into it, such as
  /// shared definitions kept under an `x-` key. Its own `$ref`s are
  /// resolved with [resolver]. Null if the value is not a map.
  KeyedArchive? archive(ReferenceResolver resolver) {
    final existing = _archive;
    if (existing != null) {
      return existing;
    }
    final value = this.value;
    if (value is! Map) {
      return null;
    }
    // A copy, because the archive converts maps in place.
    final archive = _archive = KeyedArchive.fromMap(
      _plain(value, pointer)! as Map,
      pointer,
    );
    archive.resolveOrThrow(resolver);
    return archive;
  }

  /// The value, with maps as `Map<String, dynamic>` and lists as
  /// `List<dynamic>`.
  final Object? value;

  static Object? _plain(Object? value, String pointer) {
    if (value is List) {
      return <dynamic>[
        for (final (i, e) in value.indexed)
          _plain(e, appendPointer(pointer, i)),
      ];
    }
    if (value is! Map) {
      return value;
    }
    final map = <String, dynamic>{};
    for (final MapEntry(:key, value: v) in value.entries) {
      if (key is! String) {
        throw OpenApiFormatException(
          'Keys must be strings, found ${key.runtimeType} $key.',
          pointer: appendPointer(pointer, '$key'),
          source: key,
        );
      }
      map[key] = _plain(v, appendPointer(pointer, key));
    }
    return map;
  }
}
