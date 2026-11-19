// Originally from package:codable (stable/kernel, BSD-2-Clause), via
// codable_forked. See LICENSE.

import 'package:open_api_forked/src/codec/keyed_archive.dart';

/// Something that holds `$ref`s to resolve against a document.
abstract interface class Referencable {
  void resolveOrThrow(ReferenceResolver resolver);
}

final class ReferenceResolver {
  ReferenceResolver(this.document);

  final KeyedArchive document;

  /// The object at [ref], or null if there is none (or it is not an
  /// object, for example free-form data).
  KeyedArchive? resolve(Uri ref) {
    KeyedArchive? object = document;
    for (final segment in ref.pathSegments) {
      final next = object?[segment];
      object = next is KeyedArchive ? next : null;
    }
    return object;
  }
}
