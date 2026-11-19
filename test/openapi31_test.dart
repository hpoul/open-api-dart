import 'dart:convert';

import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

/// Decodes [map] after a JSON round trip, so that it has the types a
/// decoded JSON document has.
APIDocument _doc(Map<String, Object?> map) =>
    APIDocument.fromMap(json.decode(json.encode(map)) as Map<String, dynamic>);

Map<String, Object?> _encodedSchema(APISchemaObject schema) =>
    _encoded(
          APIDocument()
            ..version = '3.1.0'
            ..info = APIInfo('t', '1')
            ..components = (APIComponents()..schemas = {'S': schema}),
        )['components']['schemas']['S']
        as Map<String, Object?>;

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

  group('schema', () {
    APIDocument schemaDoc(Map<String, Object?> schemas) => _doc({
      'openapi': '3.1.0',
      'info': {'title': 't', 'version': '1'},
      'components': {'schemas': schemas},
    });

    Map<String, Object?> encodedSchemas(APIDocument doc) =>
        (_encoded(doc)['components'] as Map)['schemas'] as Map<String, Object?>;

    test('type arrays and the null type', () {
      final schemas = {
        'NullableString': {
          'type': ['string', 'null'],
        },
        'StringOrInt': {
          'type': ['string', 'integer'],
        },
        'OnlyNull': {'type': 'null'},
        'Plain': {'type': 'string'},
        'Legacy': {'type': 'string', 'nullable': true},
        'Unknown': {
          'type': ['string', 'file'],
        },
      };
      final doc = schemaDoc(schemas);
      final s = doc.components!.schemas;
      expect(s['NullableString']!.type, APIType.string);
      expect(s['NullableString']!.types, [APIType.string]);
      expect(s['NullableString']!.isNullable, isTrue);
      expect(s['StringOrInt']!.type, isNull);
      expect(s['StringOrInt']!.types, [APIType.string, APIType.integer]);
      expect(s['StringOrInt']!.isNullable, isFalse);
      expect(s['OnlyNull']!.type, isNull);
      expect(s['OnlyNull']!.types, isEmpty);
      expect(s['OnlyNull']!.isNullable, isTrue);
      expect(s['Plain']!.types, [APIType.string]);
      expect(s['Plain']!.isNullable, isFalse);
      expect(s['Legacy']!.isNullable, isTrue);
      expect(s['Unknown']!.type, APIType.string);

      final encoded = encodedSchemas(doc);
      expect(encoded['NullableString'], schemas['NullableString']);
      expect(encoded['StringOrInt'], schemas['StringOrInt']);
      expect(encoded['OnlyNull'], schemas['OnlyNull']);
      expect(encoded['Plain'], schemas['Plain']);
      expect(encoded['Legacy'], schemas['Legacy']);
      // Types this package does not know are dropped.
      expect(encoded['Unknown'], {
        'type': ['string'],
      });
    });

    test('isNullable keeps the form the schema was written in', () {
      final doc = schemaDoc({
        'A': {
          'type': ['string'],
        },
        'B': {'type': 'string'},
        'C': {
          'type': ['string', 'null'],
        },
        'D': {'type': 'null'},
      });
      final s = doc.components!.schemas;
      s['A']!.isNullable = true;
      s['B']!.isNullable = true;
      s['C']!.isNullable = false;
      s['D']!.isNullable = false;
      final encoded = encodedSchemas(doc);
      expect(encoded['A'], {
        'type': ['string', 'null'],
      });
      expect(encoded['B'], {'type': 'string', 'nullable': true});
      expect(encoded['C'], {
        'type': ['string'],
      });
      expect(encoded['D'], <String, Object?>{});
      expect(s['D']!.isNullable, isFalse);
    });

    test('setting type or types', () {
      final schema = APISchemaObject()
        ..types = [APIType.string, APIType.integer];
      expect(schema.type, isNull);
      schema.isNullable = true;
      expect(_encodedSchema(schema), {
        'type': ['string', 'integer', 'null'],
      });
      schema.type = APIType.number;
      expect(schema.types, [APIType.number]);
      // Still nullable, so it needs the array form.
      expect(_encodedSchema(schema), {
        'type': ['number', 'null'],
      });
      expect(_encodedSchema(APISchemaObject.string()), {'type': 'string'});
      // No types and not nullable: no `type`, not an empty array.
      expect(_encodedSchema(APISchemaObject()..types = []), isEmpty);
      expect(
        () => APISchemaObject.string().types.add(APIType.number),
        throwsUnsupportedError,
      );
    });

    test('a type that is not a string or list is a format error', () {
      expect(
        () => schemaDoc({
          'A': {'type': 1},
        }),
        throwsA(
          isA<OpenApiFormatException>().having(
            (e) => e.pointer,
            'pointer',
            '#/components/schemas/A/type',
          ),
        ),
      );
      expect(
        () => schemaDoc({
          'A': {
            'type': [1],
          },
        }),
        throwsA(isA<OpenApiFormatException>()),
      );
    });

    test('numeric and boolean exclusive limits', () {
      final schemas = {
        'V31': {'type': 'integer', 'exclusiveMinimum': 0, 'maximum': 10},
        'V30': {
          'type': 'integer',
          'minimum': 0,
          'exclusiveMinimum': true,
          'maximum': 10,
          'exclusiveMaximum': false,
        },
      };
      final doc = schemaDoc(schemas);
      final v31 = doc.components!.schemas['V31']!;
      final v30 = doc.components!.schemas['V30']!;
      expect(v31.exclusiveMinimum, isNull);
      expect(v31.exclusiveMinimumValue, 0);
      expect(v31.effectiveExclusiveMinimum, 0);
      expect(v31.effectiveExclusiveMaximum, isNull);
      expect(v30.exclusiveMinimum, isTrue);
      expect(v30.exclusiveMinimumValue, isNull);
      expect(v30.effectiveExclusiveMinimum, 0);
      expect(v30.effectiveExclusiveMaximum, isNull);
      expect(encodedSchemas(doc), schemas);
      expect(
        () => schemaDoc({
          'A': {'exclusiveMinimum': 'yes'},
        }),
        throwsA(isA<OpenApiFormatException>()),
      );
    });

    test('const, examples, contentMediaType and contentEncoding', () {
      final schemas = {
        'A': {
          'const': {
            r'$ref': 'not a reference',
            'nested': [1, 2],
          },
          'examples': [
            'a',
            {r'$ref': 'also data'},
          ],
        },
        'Upload': {
          'type': 'string',
          'contentMediaType': 'image/png',
          'contentEncoding': 'base64',
        },
      };
      final doc = schemaDoc(schemas);
      final a = doc.components!.schemas['A']!;
      expect(a.constValue, {
        r'$ref': 'not a reference',
        'nested': [1, 2],
      });
      expect(a.examples, [
        'a',
        {r'$ref': 'also data'},
      ]);
      final upload = doc.components!.schemas['Upload']!;
      expect(upload.contentMediaType, 'image/png');
      expect(upload.contentEncoding, 'base64');
      expect(encodedSchemas(doc), schemas);
    });
  });

  group(r'$ref siblings', () {
    test('are decoded over the target and encoded again', () {
      final map = {
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'paths': {
          '/pets': {
            'get': {
              'responses': {
                '200': {
                  r'$ref': '#/components/responses/Ok',
                  'description': 'Pets',
                },
              },
            },
          },
        },
        'components': {
          'schemas': {
            'Pet': {
              'type': 'object',
              'properties': {
                'parent': {
                  r'$ref': '#/components/schemas/Pet',
                  'description': 'The parent pet',
                  'readOnly': true,
                },
                'sibling': {r'$ref': '#/components/schemas/Pet'},
              },
            },
          },
          'responses': {
            'Ok': {'description': 'ok'},
          },
        },
      };
      final doc = _doc(map);
      final parent = doc.components!.schemas['Pet']!.properties['parent']!;
      expect(parent.referenceURI, Uri(path: '/components/schemas/Pet'));
      expect(parent.description, 'The parent pet');
      expect(parent.isReadOnly, isTrue);
      expect(parent.type, APIType.object);
      expect(parent.referenceSiblingKeys, {'description', 'readOnly'});
      expect(
        doc
            .components!
            .schemas['Pet']!
            .properties['sibling']!
            .referenceSiblingKeys,
        isEmpty,
      );
      expect(_encoded(doc), map);
    });

    test('follow edits, and can be added in code', () {
      final doc = _doc({
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'components': {
          'schemas': {
            'Pet': {'type': 'object'},
            'Owner': {
              'properties': {
                'pet': {
                  r'$ref': '#/components/schemas/Pet',
                  'description': 'old',
                },
                'other': {r'$ref': '#/components/schemas/Pet'},
              },
            },
          },
        },
      });
      final owner = doc.components!.schemas['Owner']!;
      owner.properties['pet']!.description = 'new';
      owner.properties['other']!
        ..description = 'added'
        ..referenceSiblingKeys.add('description');
      final properties =
          ((_encoded(doc)['components'] as Map)['schemas']
              as Map)['Owner']['properties'];
      expect(properties, {
        'pet': {r'$ref': '#/components/schemas/Pet', 'description': 'new'},
        'other': {r'$ref': '#/components/schemas/Pet', 'description': 'added'},
      });
    });

    test('a sibling that leads back to the reference ends', () {
      final doc = _doc({
        'openapi': '3.1.0',
        'info': {'title': 't', 'version': '1'},
        'components': {
          'schemas': {
            'Pet': {
              'type': 'object',
              'properties': {
                'parent': {
                  r'$ref': '#/components/schemas/Pet',
                  'description': 'The parent',
                },
              },
            },
          },
        },
      });
      final pet = doc.components!.schemas['Pet']!;
      final parent = pet.properties['parent']!;
      // The reference holds its target's properties, which hold itself.
      expect(parent.properties['parent'], same(parent));
      parent.referenceSiblingKeys.add('properties');
      final encoded =
          ((_encoded(doc)['components'] as Map)['schemas'] as Map)['Pet']
              as Map;
      expect(encoded['properties']['parent'], {
        r'$ref': '#/components/schemas/Pet',
        'description': 'The parent',
        'properties': {
          'parent': {r'$ref': '#/components/schemas/Pet'},
        },
      });
    });

    test('3.0 nullable next to a ref round trips', () {
      final map = {
        'openapi': '3.0.3',
        'info': {'title': 't', 'version': '1'},
        'paths': <String, Object?>{},
        'components': {
          'schemas': {
            'Pet': {'type': 'object'},
            'Owner': {
              'type': 'object',
              'properties': {
                'pet': {r'$ref': '#/components/schemas/Pet', 'nullable': true},
              },
            },
          },
        },
      };
      final doc = _doc(map);
      final pet = doc.components!.schemas['Owner']!.properties['pet']!;
      expect(pet.isNullable, isTrue);
      expect(pet.type, APIType.object);
      expect(_encoded(doc), map);
    });
  });
}
