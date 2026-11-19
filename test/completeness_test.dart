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
                'operationId': 'getOwner',
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
    expect(owner.operationId, 'getOwner');
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
    final op = (spec['paths'] as Map)['/pets/{id}']['get'] as Map;
    (op['parameters'] as List).last['examples'] = {
      'x': {'value': 1, 'externalValue': 'https://example.com/x'},
    };
    final links = (op['responses'] as Map)['200']['links'] as Map;
    links['owner']['operationRef'] = '#/paths/~1x/get';
    (links['owner']['server'] as Map).remove('url');
    final components = spec['components'] as Map;
    components['links']['Self'].remove('operationRef');
    components['examples']['bad key'] = {'value': 1};
    expect(
      [for (final e in APIDocument.fromMap(spec).validate()) e.pointer],
      [
        '#/paths/~1pets~1{id}/get/parameters/1',
        '#/paths/~1pets~1{id}/get/parameters/1/examples/x',
        '#/paths/~1pets~1{id}/get/responses/200/links/owner',
        '#/paths/~1pets~1{id}/get/responses/200/links/owner/server/url',
        '#/components/examples/bad key',
        '#/components/links/Self',
        '#/externalDocs/url',
      ],
    );
  });
}
