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
- **Breaking:** removed `APISecuritySchemeType.openID`. The non-standard
  `openID` type still decodes, as `openIdConnect`, and encodes as
  `openIdConnect`. `APISecurityScheme.openID()` is deprecated in favour of
  `APISecurityScheme.openIdConnect()`.
- **Breaking:** `APIHeader` is its own class instead of an `APIParameter`
  subclass, so it no longer has `name` or `location`. It has the Header
  Object fields: `description`, `isRequired`, `isDeprecated`, `style`,
  `explode`, `schema`, `content`, and `example`/`examples` kept as decoded
  data. This fixes
  re-encoding a decoded document with headers, which threw because the
  header had no `name`/`in`.
- **Breaking:** `APIServerDescription.url` is a `String` instead of a `Uri`.
  It is a template (`{scheme}://{host}/v1`) and parsing it as a `Uri`
  mangled it. New `APIServerDescription.resolve()` substitutes the variables
  (given values, then defaults) and returns a `Uri`.
- **Breaking:** `codable_forked` is no longer a dependency. Its decoding code
  lives privately in `lib/src/codec`. `Coding`, `KeyedArchive`, `ListArchive`
  and the `cast` library are no longer exported; `APIObject` no longer extends
  `Coding`. It keeps `referenceURI` and `extensions`; its `decode` and
  `encode` take the internal `KeyedArchive`, so calling or overriding them
  from outside the package is not supported. Use `APIDocument.fromMap` and
  `asMap()` to read and write documents.
- **Breaking:** class modifiers. Every model class (`APIDocument`,
  `APISchemaObject`, `APIParameter`, ...) is `final`, so it can no longer be
  extended or implemented outside the package; wrap it instead. `APIObject`
  is an `abstract base class`: it can no longer be implemented, and a
  subclass must be `base`, `final` or `sealed`. The deprecated `*Codec`
  classes are `abstract final`.
- **Breaking:** collections are non-null, with non-null elements, and default
  to empty growable collections: `Map<String, APISchemaObject> schemas = {}`,
  `List<APIParameter> parameters = []`, `Map<String, APIOperation> operations`,
  and so on. Constructors still accept `null` for them. Two exceptions stay
  nullable because absent means something different from empty:
  `security` (absent inherits, `[]` means no auth) and `servers`. Free-form
  values (`enum`, `example`, `examples`) are unchanged.
- Absent and empty collections now round-trip: an empty collection is only
  encoded if it was present in the decoded input, or was filled in code.
  This fixes `components` without `schemas` encoding as `schemas: {}`.
- A `null` value inside a map or list of objects (such as `schemas: {A: null}`)
  is rejected with an `ArgumentError`.
- Encoding no longer throws for an empty `paths`, operation `responses`,
  request body `content` or OAuth2 `flows`; checking required fields moves to
  validation.
- Invalid `tags` or `required` lists now throw `TypeError` instead of
  `FailedCast`.
- Maps not typed `Map<String, dynamic>` (such as YAML maps) inside lists now
  decode; their keys must be strings.

## 3.0.1

- Fix crash decoding `components` without `schemas` (schemas is now an empty map, so it encodes back as `schemas: {}` in 3.0.1).
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
