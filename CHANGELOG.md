# Changelog

## 4.0.0-dev.1 (unreleased)

- **Breaking:** removed Swagger 2.0 support (`package:open_api_forked/v2.dart`
  and everything under `lib/src/v2`). Use 3.0.x if you need it.
- **Breaking:** requires Dart 3.8 (`sdk: ^3.8.0`).
- Analysis with `strict-casts`, `strict-inference` and `strict-raw-types`,
  lints 6, and `dart fix` applied (single quotes, `@override`, ...).
- Getter/setter pairs that only wrapped a private field are plain fields now
  (`explode`, `allowReserved`, `allowEmptyValue`, `isDeprecated`,
  `isRequired`). Same names and types, so callers are unaffected.
- `APIType`, `APIParameterLocation` and `APISecuritySchemeType` are enhanced
  enums with `jsonValue`, `fromJson` (returns `null` for unknown values) and
  `toJson`. The `*Codec` classes are deprecated and will be removed.

## 3.0.1

- Fix crash decoding `components` without `schemas` (schemas is now an empty map, so it encodes back as `schemas: {}`).
- Fix decoding and encoding of callbacks (decoding crashed on any callback, encoding threw).
- Fix crash decoding a server variable without `enum`.
- Fix crash encoding an `openIdConnect` security scheme.
- Fix document-level `security` encoding to non-JSON objects (`json.encode(doc.asMap())` threw).
- An OAuth2 flow without `scopes` decodes to empty scopes instead of crashing.
- `APIDocument.fromMap` throws an `ArgumentError` naming the reference when a `$ref` does not point to an object, instead of a `TypeError`.
- **Behaviour change:** `APIDocument.fromMap` throws an `ArgumentError` for a `$ref` that is not a local `#/...` reference, e.g. `other.yaml#/...` or `https://example.com/schema.json`. These used to be resolved against the current document (a fragment-less ref resolved to the document root), silently picking the wrong object. `$ref` inside free-form data (`example`, `examples`, `default`, `enum`, `value`, `x-*` extensions) is not checked.

## 3.0.0+6

- add openIDConnect security scheme type.

## 3.0.0+5

- Remove forced null unwraps.

## 3.0.0+3

- fix header parameters, update dependency on codable.

## 3.0.0+2

- Rename APISchemaObject.isRequired back to required

## 3.0.0

- nullsafety migration

## 2.0.1+1

- forked version to fix v3 security requirements

## 2.0.1

- Fix bug when merging APIResponse bodies

# 2.0.0

- Update for Dart 2

## 1.0.2

- Adds `APIResponse.addHeader` and `APIResponse.addContent`.
- Adds `APIOperation.addResponse`.

## 1.0.1 

- Adds `APISchemaObject.isFreeForm` and related support for free-form schema objects.

## 1.0.0

- Adds support for OpenAPI 3.0
- Splits Swagger (2.0) and OpenAPI (3.0) into 'package:open_api/v2.dart' and 'package:open_api/v3.dart'.

## 0.9.1

- Moves shared properties from `APISchema`, `APIHeader` and `APIParameter` into `APIProperty`.

## 0.9.0

- Initial data structures
- Parsing specifications
- Writing specifications to disk
