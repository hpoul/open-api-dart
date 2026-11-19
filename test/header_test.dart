import 'dart:convert';

import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

void main() {
  final spec = {
    'openapi': '3.0.0',
    'info': {'title': 'x', 'version': '1'},
    'paths': {
      '/items': {
        'get': {
          'responses': {
            '200': {
              'description': 'ok',
              'headers': {
                'X-Rate-Limit': {
                  'description': 'Requests left',
                  'example': 42,
                  'examples': {
                    'low': {'value': 1},
                  },
                  'required': true,
                  'schema': {'type': 'integer'},
                },
                'X-Trace': {r'$ref': '#/components/headers/Trace'},
              },
            },
          },
        },
      },
    },
    'components': {
      // An absent `schemas` encodes as {} (decoding defaults it).
      'schemas': <String, dynamic>{},
      'headers': {
        'Trace': {
          'deprecated': true,
          'schema': {'type': 'string'},
        },
      },
    },
  };

  Map<String, dynamic> roundTripJson(Map<String, dynamic> map) =>
      json.decode(json.encode(map)) as Map<String, dynamic>;

  test('decodes response and component headers', () {
    final doc = APIDocument.fromMap(roundTripJson(spec));
    final headers =
        doc.paths!['/items']!.operations['get']!.responses!['200']!.headers!;
    final rateLimit = headers['X-Rate-Limit']!;
    expect(rateLimit.description, 'Requests left');
    expect(rateLimit.isRequired, isTrue);
    expect(rateLimit.isDeprecated, isFalse);
    expect(rateLimit.schema!.type, APIType.integer);

    final trace = doc.components!.headers!['Trace']!;
    expect(trace.isDeprecated, isTrue);
    expect(trace.schema!.type, APIType.string);
  });

  test('a decoded document with headers encodes back unchanged', () {
    final original = roundTripJson(spec);
    final encoded = roundTripJson(APIDocument.fromMap(original).asMap());
    expect(encoded, original);
  });

  test('headers never encode name or in', () {
    final header = APIHeader(
      schema: APISchemaObject.string(),
      isRequired: true,
    );
    final encoded = KeyedArchive.archive(header);
    expect(encoded.keys, unorderedEquals(['schema', 'required']));
  });
}
