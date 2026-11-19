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

    test('webhook names may start with x-, and webhooks may be refs', () {
      final map = {
        ..._webhookExample,
        'webhooks': {
          'x-hook': {
            'post': {
              'operationId': 'xHook',
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
          'shared': {r'$ref': '#/components/pathItems/Shared'},
        },
        'components': {
          'pathItems': {
            'Shared': {
              'post': {
                'operationId': 'shared',
                'responses': {
                  '200': {'description': 'ok'},
                },
              },
            },
          },
        },
      };
      final doc = _doc(map);
      expect(doc.webhooks!['x-hook']!.operations['post']!.id, 'xHook');
      expect(doc.webhooks!['shared']!.operations['post']!.id, 'shared');
      expect(doc.validate(), isEmpty);
      final encoded = _encoded(doc);
      expect((encoded['webhooks'] as Map)['shared'], {
        r'$ref': '#/components/pathItems/Shared',
      });
      expect(((encoded['webhooks'] as Map)['x-hook'] as Map).keys, ['post']);
    });

    test('empty paths in a 3.1 document stay', () {
      final doc = _doc({
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'paths': <String, Object?>{},
      });
      expect(doc.hasPaths, isTrue);
      expect(_encoded(doc)['paths'], <String, Object?>{});
      expect(doc.validate(), isEmpty);
    });

    test('a 3.0 path item ref exposes the operations of its target', () {
      final doc = _doc({
        'openapi': '3.0.3',
        'info': {'title': 't', 'version': '1'},
        'paths': {
          '/pets': {r'$ref': '#/x-shared/pets'},
        },
        'x-shared': {
          'pets': {
            'get': {
              'operationId': 'listPets',
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
      });
      expect(doc.operations.map((o) => o.operation.id), ['listPets']);
      expect(_encoded(doc)['paths'], {
        '/pets': {r'$ref': '#/x-shared/pets'},
      });
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
      Map<String, Object?> responseWithoutDescription(String id) => {
        'post': {
          'operationId': id,
          'responses': {'200': <String, Object?>{}},
        },
      };
      expect(
        pointers({
          'openapi': '3.1.0',
          'info': {'title': 't', 'version': '1'},
          'webhooks': {'hook': responseWithoutDescription('a')},
          'components': {
            'pathItems': {'Item': responseWithoutDescription('b')},
          },
        }),
        [
          '#/webhooks/hook/post/responses/200/description',
          '#/components/pathItems/Item/post/responses/200/description',
        ],
      );
    });

    test('a 3.1 document needs paths, components or webhooks', () {
      expect(
        pointers({
          'openapi': '3.1.0',
          'info': {'title': 't', 'version': '1'},
        }),
        ['#'],
      );
    });

    test('responses are optional in 3.1 only', () {
      Map<String, Object?> doc(String version) => {
        'openapi': version,
        'info': {'title': 't', 'version': '1'},
        'paths': {
          '/a': {
            'get': {'operationId': 'a'},
          },
        },
      };
      expect(pointers(doc('3.1.0')), isEmpty);
      expect(pointers(doc('3.0.3')), ['#/paths/~1a/get/responses']);
    });

    test('mutualTLS security schemes', () {
      final map = {
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'components': {
          'securitySchemes': {
            'mtls': {'type': 'mutualTLS', 'description': 'Client certs'},
          },
        },
        'security': [
          {'mtls': <String>[]},
        ],
      };
      final doc = _doc(map);
      expect(
        doc.components!.securitySchemes['mtls']!.type,
        APISecuritySchemeType.mutualTLS,
      );
      expect(doc.validate(), isEmpty);
      expect(_encoded(doc), map);
    });

    test('path item refs: templates are checked, sharing is reported', () {
      expect(
        pointers({
          'openapi': '3.1.0',
          'info': {'title': 't', 'version': '1'},
          'paths': {
            '/a/{id}': {r'$ref': '#/components/pathItems/Item'},
            '/b': {r'$ref': '#/components/pathItems/Item'},
          },
          'components': {
            'pathItems': {
              'Item': {
                'get': {'operationId': 'get'},
              },
            },
          },
        }),
        ['#/paths/~1a~1{id}/get/parameters', '#/paths/~1b/\$ref'],
      );
    });

    test('3.1 responses: absent stays absent, empty is reported', () {
      final map = {
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'webhooks': {
          'hook': {'post': <String, Object?>{}},
          'empty': {
            'post': {'responses': <String, Object?>{}},
          },
        },
      };
      final doc = _doc(map);
      expect(doc.webhooks!['hook']!.operations['post']!.hasResponses, isFalse);
      expect(_encoded(doc), map);
      expect(pointers(map), ['#/webhooks/empty/post/responses']);
    });

    test('a 3.1 operation built in code needs a response', () {
      final doc = APIDocument()
        ..version = '3.1.0'
        ..info = APIInfo('t', '1')
        ..webhooks = {
          'hook': APIPath(operations: {'post': APIOperation('x', {})}),
        };
      expect(doc.webhooks!['hook']!.operations['post']!.hasResponses, isTrue);
      expect(
        [for (final e in doc.validate()) e.pointer],
        ['#/webhooks/hook/post/responses'],
      );
    });

    test('role names in security requirements are allowed in 3.1 only', () {
      Map<String, Object?> doc(String version) => {
        'openapi': version,
        'info': {'title': 't', 'version': '1'},
        'paths': <String, Object?>{},
        'components': {
          'securitySchemes': {
            'm': {'type': 'mutualTLS'},
          },
        },
        'security': [
          {
            'm': ['admin'],
          },
        ],
      };
      expect(pointers(doc('3.1.0')), isEmpty);
      expect(pointers(doc('3.0.3')), ['#/security/0/m']);
    });

    test('a path item shared by a path and a webhook is reported', () {
      expect(
        pointers({
          'openapi': '3.1.0',
          'info': {'title': 't', 'version': '1'},
          'paths': {
            '/a': {r'$ref': '#/components/pathItems/Item'},
          },
          'webhooks': {
            'hook': {r'$ref': '#/components/pathItems/Item'},
          },
          'components': {
            'pathItems': {
              'Item': {
                'post': {'operationId': 'post'},
              },
            },
          },
        }),
        ['#/webhooks/hook/\$ref'],
      );
    });
  });
}
