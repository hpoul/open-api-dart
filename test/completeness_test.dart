import 'dart:convert';

import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

/// Through JSON, so that every map is `Map<String, dynamic>` and can be
/// changed in tests.
Map<String, dynamic> _spec() =>
    json.decode(json.encode(_specLiteral)) as Map<String, dynamic>;

const _specLiteral = {
  'openapi': '3.0.3',
  'info': {'title': 'Pets', 'version': '1'},
  'externalDocs': {'url': 'https://example.com/docs', 'description': 'Docs'},
  'tags': [
    {
      'name': 'pets',
      'externalDocs': {'url': 'https://example.com/pets'},
    },
  ],
  'paths': {
    '/pets/{id}': {
      'servers': [
        {'url': '/v2'},
      ],
      'get': {
        'operationId': 'getPet',
        'externalDocs': {'url': 'https://example.com/get'},
        'parameters': [
          {
            'name': 'id',
            'in': 'path',
            'required': true,
            'schema': {'type': 'string'},
            'examples': {
              'short': {'summary': 'A short id', 'value': 'a1'},
              'shared': {r'$ref': '#/components/examples/Id'},
            },
          },
          {
            'name': 'q',
            'in': 'query',
            'schema': {'type': 'string'},
            'example': 'cat',
          },
        ],
        'responses': {
          '200': {
            'description': 'ok',
            'headers': {
              'X-Rate': {
                'schema': {'type': 'integer'},
                'examples': {
                  'low': {'value': 1},
                },
              },
            },
            'content': {
              'application/json': {
                'schema': {r'$ref': '#/components/schemas/Pet'},
                'examples': {
                  'cat': {
                    'value': {'petType': 'cat', 'name': 'Tom'},
                  },
                  'remote': {'externalValue': 'https://example.com/dog.json'},
                },
              },
              'text/plain': {'example': 'Tom'},
            },
            'links': {
              'owner': {
                'operationId': 'getPet',
                'parameters': {'petId': r'$response.body#/id'},
                'server': {'url': 'https://owners.example.com'},
              },
              'shared': {r'$ref': '#/components/links/Self'},
            },
          },
        },
      },
    },
  },
  'components': {
    'schemas': {
      'Pet': {
        'type': 'object',
        'required': ['petType'],
        'properties': {
          'petType': {'type': 'string'},
          'name': {
            'type': 'string',
            'xml': {'name': 'petName', 'attribute': true},
          },
        },
        'discriminator': {
          'propertyName': 'petType',
          'mapping': {'cat': '#/components/schemas/Cat'},
        },
        'xml': {
          'name': 'pet',
          'namespace': 'https://example.com/schema',
          'prefix': 'p',
          'wrapped': false,
        },
        'example': {'petType': 'cat'},
        'externalDocs': {'url': 'https://example.com/pet'},
      },
      'Cat': {
        'allOf': [
          {r'$ref': '#/components/schemas/Pet'},
        ],
      },
    },
    'examples': {
      'Id': {'summary': 'Shared id', 'description': 'An id.', 'value': 'b2'},
    },
    'links': {
      'Self': {
        'operationRef': '#/paths/~1pets~1{id}/get',
        'parameters': {'id': r'$request.path.id'},
        'requestBody': {'x': 1},
        'description': 'The same pet.',
      },
    },
  },
};

void main() {
  test('decodes the remaining 3.0 objects', () {
    final doc = APIDocument.fromMap(_spec());
    expect(doc.externalDocs!.url, Uri.parse('https://example.com/docs'));
    expect(doc.externalDocs!.description, 'Docs');
    expect(
      doc.tags.single.externalDocs!.url,
      Uri.parse('https://example.com/pets'),
    );

    final op = doc.paths['/pets/{id}']!.operations['get']!;
    expect(op.externalDocs!.url.toString(), 'https://example.com/get');
    final id = op.parameters.first;
    expect(id.examples['short']!.value, 'a1');
    expect(id.examples['short']!.summary, 'A short id');
    expect(
      id.examples['shared']!.referenceURI!.path,
      '/components/examples/Id',
    );
    expect(id.examples['shared']!.value, 'b2');
    expect(op.parameters.last.example, 'cat');

    final response = op.responses['200']!;
    expect(response.headers['X-Rate']!.examples['low']!.value, 1);
    final json = response.content['application/json']!;
    expect(json.examples['cat']!.value, {'petType': 'cat', 'name': 'Tom'});
    expect(
      json.examples['remote']!.externalValue,
      Uri.parse('https://example.com/dog.json'),
    );
    expect(response.content['text/plain']!.example, 'Tom');

    final owner = response.links['owner']!;
    expect(owner.operationId, 'getPet');
    expect(owner.parameters, {'petId': r'$response.body#/id'});
    expect(owner.server!.url, 'https://owners.example.com');
    final self = response.links['shared']!;
    expect(self.operationRef, '#/paths/~1pets~1{id}/get');
    expect(self.requestBody, {'x': 1});

    final pet = doc.components!.schemas['Pet']!;
    expect(pet.discriminator!.propertyName, 'petType');
    expect(pet.discriminator!.mapping, {'cat': '#/components/schemas/Cat'});
    expect(pet.xml!.name, 'pet');
    expect(pet.xml!.namespace, Uri.parse('https://example.com/schema'));
    expect(pet.xml!.prefix, 'p');
    expect(pet.xml!.wrapped, false);
    expect(pet.properties['name']!.xml!.attribute, true);
    expect(pet.example, {'petType': 'cat'});
    expect(pet.externalDocs!.url.toString(), 'https://example.com/pet');

    expect(doc.components!.examples['Id']!.description, 'An id.');
    expect(doc.components!.links['Self']!.description, 'The same pet.');
    expect(
      doc.components!.resolveUri(Uri(path: '/components/links/Self')),
      same(doc.components!.links['Self']),
    );
    expect(doc.validate(), isEmpty);
  });

  test('round-trips the remaining 3.0 objects', () {
    final encoded = APIDocument.fromMap(_spec()).asMap();
    expect(json.decode(json.encode(encoded)), _spec());
  });

  test('toString', () {
    final doc = APIDocument.fromMap(_spec());
    final pet = doc.components!.schemas['Pet']!;
    expect(
      pet.discriminator.toString(),
      'APIDiscriminator(propertyName: petType, mapping: {cat})',
    );
    expect(pet.xml.toString(), 'APIXml(name: pet)');
    expect(
      doc.externalDocs.toString(),
      'APIExternalDocumentation(url: https://example.com/docs)',
    );
    expect(APILink(operationId: 'x').toString(), 'APILink(operationId: x)');
    expect(APIExample(summary: 's').toString(), 'APIExample(summary: s)');
  });

  test('a non-string discriminator mapping is a format error', () {
    final spec = _spec();
    ((spec['components'] as Map)['schemas']
        as Map)['Pet']['discriminator']['mapping'] = {
      'cat': 1,
    };
    expect(
      () => APIDocument.fromMap(spec),
      throwsA(
        isA<OpenApiFormatException>().having(
          (e) => e.pointer,
          'pointer',
          '#/components/schemas/Pet/discriminator/mapping/cat',
        ),
      ),
    );
  });

  test('validate reports the new MUST rules', () {
    final spec = _spec();
    spec['externalDocs'] = {'description': 'no url'};
    final path = (spec['paths'] as Map)['/pets/{id}'] as Map;
    path['servers'] = [
      {'description': 'no url'},
    ];
    final op = path['get'] as Map;
    (op['parameters'] as List).last['examples'] = {
      'x': {'value': 1, 'externalValue': 'https://example.com/x'},
    };
    final links = (op['responses'] as Map)['200']['links'] as Map;
    links['owner']['operationRef'] = '#/paths/~1x/get';
    (links['owner']['server'] as Map).remove('url');
    final components = spec['components'] as Map;
    components['links']['Self'].remove('operationRef');
    components['links']['Other'] = {'operationId': 'nope'};
    components['examples']['bad key'] = {'value': 1};
    final pet = components['schemas']['Pet'] as Map;
    (pet['discriminator'] as Map).remove('propertyName');
    pet['properties']['name']['externalDocs'] = <String, Object?>{};
    expect(
      [for (final e in APIDocument.fromMap(spec).validate()) e.pointer],
      [
        '#/paths/~1pets~1{id}/servers/0/url',
        '#/paths/~1pets~1{id}/get/parameters/1/examples',
        '#/paths/~1pets~1{id}/get/parameters/1/examples/x/externalValue',
        '#/paths/~1pets~1{id}/get/responses/200/links/owner',
        '#/paths/~1pets~1{id}/get/responses/200/links/owner/server/url',
        '#/components/examples/bad key',
        '#/components/schemas/Pet/discriminator/propertyName',
        '#/components/schemas/Pet/properties/name/externalDocs/url',
        '#/components/links/Self',
        '#/externalDocs/url',
        '#/components/links/Other/operationId',
      ],
    );
  });

  group('free-form values', () {
    Map<String, dynamic> withExampleValue(Object? value) {
      final spec = _spec();
      ((spec['components'] as Map)['examples'] as Map)['Id'] = {'value': value};
      return spec;
    }

    for (final value in [
      {r'$ref': '#/nope/deeper'},
      {r'$ref': '#/info/title'},
      {r'$ref': 'other.json#/x'},
      {r'$ref': '#/components/schemas/Pet'},
    ]) {
      test('keep a \$ref-shaped value as data: $value', () {
        final doc = APIDocument.fromMap(withExampleValue(value));
        final example = doc.components!.examples['Id']!;
        expect(example.value, value);
        expect(example.value, isA<Map<String, dynamic>>());
        expect(doc.asMap()['components']['examples']['Id'], {'value': value});
      });
    }

    test('schema example, default and enum are data', () {
      final spec = _spec();
      final pet = (spec['components'] as Map)['schemas']['Pet'] as Map;
      pet['example'] = {r'$ref': '#/info/title/x'};
      pet['default'] = {r'$ref': 'other.json'};
      pet['enum'] = [
        {r'$ref': '#/nope'},
      ];
      final decoded = APIDocument.fromMap(spec).components!.schemas['Pet']!;
      expect(decoded.example, {r'$ref': '#/info/title/x'});
      expect(decoded.defaultValue, {r'$ref': 'other.json'});
      expect(decoded.enumerated, [
        {r'$ref': '#/nope'},
      ]);
    });

    test('link parameters and requestBody are data', () {
      final spec = _spec();
      spec['components']['links']['Self']['requestBody'] = {
        r'$ref': '#/info/title',
      };
      final link = APIDocument.fromMap(spec).components!.links['Self']!;
      expect(link.requestBody, {r'$ref': '#/info/title'});
    });

    test('names like default in name maps are still checked', () {
      final spec = _spec();
      final content =
          (spec['paths']
                  as Map)['/pets/{id}']['get']['responses']['200']['content']['application/json']
              as Map;
      content['examples'] = {
        'default': {r'$ref': 'other.yaml#/components/examples/Id'},
      };
      expect(
        () => APIDocument.fromMap(spec),
        throwsA(
          isA<OpenApiFormatException>().having(
            (e) => e.pointer,
            'pointer',
            '#/paths/~1pets~1{id}/get/responses/200/content/application~1json/examples/default/\$ref',
          ),
        ),
      );
      content['examples'] = {
        'default': {r'$ref': '#/components/examples/Id'},
      };
      final doc = APIDocument.fromMap(spec);
      expect(
        doc
            .paths['/pets/{id}']!
            .operations['get']!
            .responses['200']!
            .content['application/json']!
            .examples['default']!
            .value,
        'b2',
      );
    });

    test('a JSON Schema examples list on a schema is ignored', () {
      final spec = _spec();
      spec['components']['schemas']['Pet']['examples'] = [
        {r'$ref': 'https://json-schema.org/draft/2020-12/schema'},
      ];
      expect(APIDocument.fromMap(spec).components!.schemas['Pet'], isNotNull);
    });

    test('a reference into free-form data is a format error', () {
      final spec = _spec();
      spec['components']['schemas']['Pet']['example'] = {
        'a': {'type': 'string'},
      };
      spec['components']['schemas']['Ref'] = {
        r'$ref': '#/components/schemas/Pet/example/a',
      };
      expect(
        () => APIDocument.fromMap(spec),
        throwsA(isA<OpenApiFormatException>()),
      );
    });
  });

  group('malformed input is a format error', () {
    for (final (name, change, pointer)
        in <(String, void Function(Map<String, dynamic>), String)>[
          ('externalDocs', (s) => s['externalDocs'] = 'str', '#/externalDocs'),
          (
            'xml attribute',
            (s) =>
                s['components']['schemas']['Pet']['xml']['attribute'] = 'yes',
            '#/components/schemas/Pet/xml/attribute',
          ),
          (
            'links entry',
            (s) => s['components']['links']['Other'] = 1,
            '#/components/links/Other',
          ),
          (
            'null example',
            (s) => s['components']['examples']['Other'] = null,
            '#/components/examples/Other',
          ),
          (
            'link server',
            (s) =>
                s['paths']['/pets/{id}']['get']['responses']['200']['links']['owner']['server'] =
                    's',
            '#/paths/~1pets~1{id}/get/responses/200/links/owner/server',
          ),
          (
            'externalValue',
            (s) =>
                s['paths']['/pets/{id}']['get']['parameters'][0]['examples']['short']['externalValue'] =
                    1,
            '#/paths/~1pets~1{id}/get/parameters/0/examples/short/externalValue',
          ),
          (
            'path servers',
            (s) => s['paths']['/pets/{id}']['servers'] = 'x',
            '#/paths/~1pets~1{id}/servers',
          ),
        ]) {
      test(name, () {
        final spec = _spec();
        change(spec);
        expect(
          () => APIDocument.fromMap(spec),
          throwsA(
            isA<OpenApiFormatException>().having(
              (e) => e.pointer,
              'pointer',
              pointer,
            ),
          ),
        );
      });
    }
  });
}
