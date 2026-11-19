import 'dart:convert';

import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

/// Decodes [map] after a JSON round trip, so that it has the types a
/// decoded JSON document has.
APIDocument _doc(Map<String, Object?> map) =>
    APIDocument.fromMap(json.decode(json.encode(map)) as Map<String, dynamic>);

Map<String, dynamic> _encoded(APIDocument doc) =>
    json.decode(json.encode(doc.asMap())) as Map<String, dynamic>;

/// The webhook example from the OpenAPI 3.1 specification.
final _webhookExample = <String, Object?>{
  'openapi': '3.1.0',
  'info': {'title': 'Webhook Example', 'version': '1.0.0'},
  'webhooks': {
    'newPet': {
      'post': {
        'requestBody': {
          'description': 'Information about a new pet in the system',
          'content': {
            'application/json': {
              'schema': {r'$ref': '#/components/schemas/Pet'},
            },
          },
        },
        'responses': {
          '200': {
            'description':
                'Return a 200 status to indicate that the data was '
                'received successfully',
          },
        },
      },
    },
  },
  'components': {
    'schemas': {
      'Pet': {
        'required': ['id', 'name'],
        'properties': {
          'id': {'type': 'integer', 'format': 'int64'},
          'name': {'type': 'string'},
          'tag': {'type': 'string'},
        },
      },
    },
  },
};

void main() {
  group('document', () {
    test('webhooks decode, and paths may be absent', () {
      final doc = _doc(_webhookExample);
      expect(doc.isOpenApi31, isTrue);
      expect(doc.paths, isEmpty);
      expect(doc.operations, isEmpty);
      final newPet = doc.webhooks!['newPet']!;
      final schema = newPet
          .operations['post']!
          .requestBody!
          .content['application/json']!
          .schema!;
      expect(schema.referenceURI, Uri(path: '/components/schemas/Pet'));
      expect(schema.properties.keys, ['id', 'name', 'tag']);
      expect(doc.validate(), isEmpty);
    });

    test('webhooks round trip, and absent paths stay absent in 3.1', () {
      final encoded = _encoded(_doc(_webhookExample));
      expect(encoded.containsKey('paths'), isFalse);
      expect(encoded.keys, containsAll(<String>['webhooks', 'components']));
      final post = (encoded['webhooks'] as Map)['newPet']['post'] as Map;
      expect(post['responses'], {
        '200': {
          'description':
              'Return a 200 status to indicate that the data was '
              'received successfully',
        },
      });
      expect(_encoded(APIDocument.fromMap(encoded)), encoded);
    });

    test('3.0 documents keep writing empty paths', () {
      final doc = APIDocument()
        ..info = APIInfo('t', '1')
        ..version = '3.0.3';
      expect(_encoded(doc)['paths'], <String, Object?>{});
    });

    test('a document without webhooks has none', () {
      final doc = _doc({
        'openapi': '3.0.3',
        'info': {'title': 't', 'version': '1'},
        'paths': <String, Object?>{},
      });
      expect(doc.isOpenApi31, isFalse);
      expect(doc.webhooks, isNull);
      expect(_encoded(doc).containsKey('webhooks'), isFalse);
    });

    test('x- keys in webhooks are data, not path items', () {
      final doc = _doc({
        ..._webhookExample,
        'webhooks': {
          'x-note': {'post': 'not an operation'},
        },
      });
      expect(doc.webhooks, isEmpty);
    });

    test('jsonSchemaDialect, info summary and license identifier', () {
      final map = {
        'openapi': '3.1.0',
        'jsonSchemaDialect': 'https://spec.openapis.org/oas/3.1/dialect/base',
        'info': {
          'title': 't',
          'summary': 'A short summary',
          'version': '1',
          'license': {'name': 'Apache 2.0', 'identifier': 'Apache-2.0'},
        },
        'paths': <String, Object?>{},
      };
      final doc = _doc(map);
      expect(
        doc.jsonSchemaDialect,
        'https://spec.openapis.org/oas/3.1/dialect/base',
      );
      expect(doc.info!.summary, 'A short summary');
      expect(doc.info!.license!.identifier, 'Apache-2.0');
      expect(_encoded(doc), map);
      expect(doc.validate(), isEmpty);
    });

    test('components pathItems decode, resolve and are referenced', () {
      final doc = _doc({
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'paths': {
          '/pets': {r'$ref': '#/components/pathItems/Pets'},
        },
        'components': {
          'pathItems': {
            'Pets': {
              'get': {
                'operationId': 'listPets',
                'responses': {
                  '200': {'description': 'ok'},
                },
              },
            },
          },
        },
      });
      final item = doc.components!.pathItems['Pets']!;
      expect(item.operations['get']!.id, 'listPets');
      expect(
        doc.components!.resolveUri(Uri(path: '/components/pathItems/Pets')),
        same(item),
      );
      final pets = doc.paths['/pets']!;
      expect(pets.referenceURI, Uri(path: '/components/pathItems/Pets'));
      expect(pets.operations['get']!.id, 'listPets');
      expect(doc.operations.map((o) => o.operation.id), ['listPets']);
      expect(doc.validate(), isEmpty);
    });

    test(r'$ref siblings summary and description override the target', () {
      final doc = _doc({
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'paths': {
          '/pets': {
            'get': {
              'responses': {
                '200': {
                  r'$ref': '#/components/responses/Ok',
                  'description': 'Pets, overridden',
                },
              },
            },
          },
        },
        'components': {
          'responses': {
            'Ok': {'description': 'ok'},
          },
        },
      });
      final response = doc.paths['/pets']!.operations['get']!.responses['200']!;
      expect(response.description, 'Pets, overridden');
      expect(doc.components!.responses['Ok']!.description, 'ok');
    });
  });

  group('validate', () {
    List<String> pointers(Map<String, Object?> map) => [
      for (final e in _doc(map).validate()) e.pointer,
    ];

    test('unsupported versions are reported', () {
      expect(
        pointers({
          'openapi': '2.0',
          'info': {'title': 't', 'version': '1'},
          'paths': <String, Object?>{},
        }),
        ['#/openapi'],
      );
    });

    test('license identifier and url are mutually exclusive', () {
      expect(
        pointers({
          'openapi': '3.1.0',
          'info': {
            'title': 't',
            'version': '1',
            'license': {
              'name': 'MIT',
              'identifier': 'MIT',
              'url': 'https://opensource.org/license/mit',
            },
          },
          'paths': <String, Object?>{},
        }),
        ['#/info/license'],
      );
    });

    test('webhooks and components pathItems are checked', () {
      Map<String, Object?> operationWithoutResponses(String id) => {
        'post': {'operationId': id},
      };
      expect(
        pointers({
          'openapi': '3.1.0',
          'info': {'title': 't', 'version': '1'},
          'webhooks': {'hook': operationWithoutResponses('a')},
          'components': {
            'pathItems': {'Item': operationWithoutResponses('b')},
          },
        }),
        [
          '#/webhooks/hook/post/responses',
          '#/components/pathItems/Item/post/responses',
        ],
      );
    });
  });
}
