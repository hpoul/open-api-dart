# open_api_forked

Reads and writes [OpenAPI 3.0](https://spec.openapis.org/oas/v3.0.3)
and [3.1](https://spec.openapis.org/oas/v3.1.0) documents. A fork of `open_api` by stable|kernel, maintained for
[openapi_code_builder](https://pub.dev/packages/openapi_code_builder).

```dart
import 'dart:convert';
import 'dart:io';

import 'package:open_api_forked/v3.dart';

void main() {
  final json = jsonDecode(File('openapi.json').readAsStringSync());
  final doc = APIDocument.fromMap(json as Map<String, dynamic>);
  print(doc.info?.title);

  print(jsonEncode(doc.asMap()));
}
```

Swagger 2.0 (`package:open_api_forked/v2.dart`) was removed in 4.0.

For OpenAPI 3.1, schemas model the common JSON Schema 2020-12 keywords:
`type` arrays and the `"null"` type (`APISchemaObject.types`, and
`isNullable`), numeric `exclusiveMinimum`/`exclusiveMaximum`, `const`,
`examples`, `contentMediaType`, `contentEncoding`, and keywords next to a
`$ref`. Other keywords, such as `prefixItems`, `if`/`then`/`else` or
`$defs`, are not modelled: they are dropped when a document is encoded,
though `$ref`s into them still resolve.
