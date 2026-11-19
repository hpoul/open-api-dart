# Changelog

## 4.0.0-dev.1 (unreleased)

- **Breaking:** removed Swagger 2.0 support (`package:open_api_forked/v2.dart`
  and everything under `lib/src/v2`). Use 3.0.x if you need it.
- **Breaking:** requires Dart 3.8 (`sdk: ^3.8.0`).
- Analysis with `strict-casts`, `strict-inference` and `strict-raw-types`,
  lints 6, and `dart fix` applied (single quotes, `@override`, ...).
- Getter/setter pairs that only wrapped a private field are plain fields now
  (`explode`, `allowReserved` and `allowEmptyValue` on `APIParameter`,
  `APIOperation.isDeprecated`). Same names and types, so callers are
  unaffected.
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
  `explode`, `schema`, `content`, `example` and `examples`. This fixes
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
  and so on. Most constructors still accept `null` for optional collections.
  `APIResponse.addHeader` takes a non-null header. Two exceptions stay
  nullable because absent means something different from empty:
  `security` (absent inherits, `[]` means no auth) and `servers`. Free-form
  values (`enum`, `example`, `examples`) are unchanged.
- Absent and empty collections now round-trip: an optional empty collection
  is only encoded if it was present in the decoded input. This fixes
  `components` without `schemas` encoding as `schemas: {}`. The REQUIRED
  `paths`, operation `responses`, request body `content`, OAuth2 `flows` and
  `scopes` are always encoded, even when empty.
- A `null` value inside a map or list of objects (such as `schemas: {A: null}`)
  is rejected with an `ArgumentError`.
- Encoding no longer throws for `paths`, operation `responses`, request body
  `content` or OAuth2 `flows` being missing, since they can no longer be
  null.
- **Breaking:** decoding a malformed document throws an
  `OpenApiFormatException` (which implements `FormatException`) instead of
  an `ArgumentError`, `TypeError` or `FailedCast`. Its `pointer` is a JSON
  pointer (RFC 6901, prefixed with `#`, not percent-encoded) to the
  offending value, such as `#/paths/~1pets/get/responses/200`. This covers
  wrong value types, a `null` inside a map or list of objects, non-string
  keys (as YAML can produce), non-string, unresolvable or non-local `$ref`s,
  and cycles of `$ref`s (which overflowed the stack). Code that catches `ArgumentError` or `TypeError` around
  `APIDocument.fromMap` should catch `FormatException` or
  `OpenApiFormatException` instead. Errors when encoding an invalid model
  built in code are still `ArgumentError`s.
- New `APIDocument.validate()` returns an `OpenApiFormatException`, with a
  pointer, for each problem it finds: missing REQUIRED fields (`info`,
  `title`, `version`, parameter `name`/`in`, response `description`,
  request body `content`, server `url`, variable `default`, tag and license
  `name`, and the fields each security scheme type needs), operations
  without responses, path keys not starting with `/`, invalid response keys
  and component names, path template parameters that are not declared (or
  declared but not in the template), duplicate parameters, operationIds and
  tag names, parameters with both or neither of `schema` and `content`,
  unknown OAuth2 flows, and security requirements that name no declared
  scheme or give scopes to a scheme that takes none. It is not a full
  validator: schemas are not checked, `$ref`s are checked at their target,
  and an empty list does not prove a document valid.
- Decoding stays lenient so that tools can read imperfect documents, and the
  REQUIRED fields stay nullable. A document without `info`, or a security
  scheme with a missing or unknown `type`, now decodes (with `null`) instead
  of throwing; `validate()` reports them.
- New getters apply the spec defaults: `effectiveStyle` (by parameter
  location) and `effectiveExplode` (true only for `form`) on `APIParameter`,
  `APIHeader` and `APIEncoding`; `effectiveAllowReserved` on `APIParameter`
  and `APIEncoding`; `effectiveAllowEmptyValue` on `APIParameter`. The raw
  fields stay `bool?`/`String?`, with `null` meaning not given.
- **Breaking:** `explode`, `allowReserved`, `allowEmptyValue`, `required` and
  `deprecated` on `APIParameter`, and `explode`/`allowReserved` on
  `APIEncoding`, now start as `null` instead of `false` for objects built
  with `APIParameter.empty()`, `APIParameter.path()` and
  `APIEncoding.empty()`, so they are no longer written as an explicit
  `false`. For a query or cookie parameter (or an encoding) a missing
  `explode` means true, so code that relied on the implicit `false` must now
  set `explode = false`. Decoded documents are unaffected.
- **Breaking:** a schema without `additionalProperties` now has
  `additionalPropertyPolicy == null` instead of `restricted` with no schema.
  JSON Schema treats a missing value as `freeForm`; the generator has
  treated it as `disallowed`. Code that merges `allOf` members should take
  the member's policy when the schema's own is null.
  `APISchemaObject.map()` now sets the policy too (`restricted`, or
  `freeForm` for `any: true`), so a decoded or `.map()`-built `restricted`
  always comes with an `additionalPropertySchema`.
- New `APIDocument.operations` yields every operation as a record
  `(path, pathItem, method, operation)`, so callers no longer need to nest
  loops over `paths` and each path's `operations`. Methods come in a fixed
  order (get, put, post, ...) and `x-` keys in `paths` are skipped.
- Model objects have a short, single-line `toString()` for debugging, such
  as `APIParameter(name: id, in: path)` or
  `APISchemaObject($ref: #/components/schemas/Pet)`, instead of
  `Instance of '...'`. Some types print only `TypeName()`; nesting is cut
  off after a few levels, so cycles built in code don't overflow.
- The remaining OpenAPI 3.0 objects are modelled, so these fields are no
  longer dropped when a document is decoded and encoded again:
  - New `APIExternalDocumentation` as `externalDocs` on `APIDocument`,
    `APIOperation`, `APITag` and `APISchemaObject`.
  - New `APIDiscriminator` (`discriminator`), `APIXml` (`xml`) and
    `example` on `APISchemaObject`.
  - New `APIExample`: `example`/`examples` on `APIParameter` and
    `APIMediaType`, and `APIComponents.examples`.
  - New `APILink`: `APIResponse.links` and `APIComponents.links`.
  - `APIPath.servers`.
  - `resolveUri` handles `#/components/examples/...` and
    `#/components/links/...`.
  URLs (`externalDocs.url`, `externalValue`, `xml.namespace`) are `Uri`s,
  like the other URLs except server templates, so they are normalised when
  encoded again. Explicit `null` values are not encoded.
- **Breaking:** `APIHeader.examples` is a `Map<String, APIExample>` (empty
  by default) instead of decoded data.
- Free-form values are decided by position, not by key name, and kept as
  plain data: `example`, schema `default` and `enum`, an Example's `value`,
  a Link's `parameters` and `requestBody`, and `x-` extension values. A
  `$ref`-shaped map in there is returned as is (it used to be resolved,
  rejected, or crash with a `TypeError`), and maps in there are
  `Map<String, dynamic>`. Conversely, a `$ref` under a name such as
  `default` in `examples`, `properties` or `links` is now checked like any
  other reference instead of being skipped. An `examples` list (JSON
  Schema, or converted Swagger 2) is ignored.
- A `$ref` may still point into free-form data, such as shared definitions
  under an `x-` key: what a `$ref` (outside free-form data) points into is
  read as OpenAPI objects, with its own `$ref`s checked and resolved and
  its examples kept as data. Its siblings stay data, and decoded fields
  such as `extensions` and `example` are still plain data.
- `x-` extensions directly in `paths`, operation `responses` and callbacks
  are ignored instead of being decoded as a path item or response (which
  failed for anything but an object, and lost its content).
- `validate()` also reports a missing `externalDocs.url` (in schemas too)
  or discriminator `propertyName`, `example` together with `examples`, an
  example with both `value` and `externalValue`, a link without exactly one
  of `operationRef` and `operationId`, a link `operationId` that no
  operation has, and path-level servers without `url`. It now walks
  schemas, but checks only these OpenAPI additions in them.
- Maps not typed `Map<String, dynamic>` (such as YAML maps) inside lists now
  decode; their keys must be strings.

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
