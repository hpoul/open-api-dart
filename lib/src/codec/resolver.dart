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

  KeyedArchive? resolve(Uri ref) {
    return ref.pathSegments.fold<KeyedArchive?>(document, (objectPtr, segment) {
      return (objectPtr! as Map)[segment] as KeyedArchive?;
    });
  }
}
