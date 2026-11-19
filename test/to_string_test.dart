import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

void main() {
  final doc = APIDocument.fromMap({
    'openapi': '3.0.0',
    'info': {'title': 'Pets', 'version': '1.0'},
    'paths': {
      '/pets': {
        'get': {
          'operationId': 'listPets',
          'responses': {
            '200': {'description': 'ok'},
          },
        },
        'post': {
          'operationId': 'addPet',
          'responses': {
            '201': {'description': 'created'},
          },
        },
      },
      '/pets/{id}': {
        'parameters': [
          {'name': 'id', 'in': 'path', 'required': true},
        ],
        'get': {
          'responses': {
            '200': {
              'description': 'a pet',
              'content': {
                'application/json': {
                  'schema': {r'$ref': '#/components/schemas/Pet'},
                },
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
          'properties': {
            'id': {'type': 'integer', 'format': 'int64'},
            'name': {'type': 'string'},
          },
        },
      },
    },
  });

  test('operations yields every operation in order', () {
    expect(
      [
        for (final (:path, :method, :operation, :pathItem) in doc.operations)
          '$method $path ${operation.id} ${pathItem.parameters.length}',
      ],
      ['get /pets listPets 0', 'post /pets addPet 0', 'get /pets/{id} null 1'],
    );
  });

  test('toString', () {
    expect(
      doc.toString(),
      'APIDocument(openapi: 3.0.0, title: Pets, version: 1.0, paths: 2)',
    );
    expect(
      doc.components!.schemas['Pet'].toString(),
      'APISchemaObject(type: object, properties: {id, name})',
    );
    expect(
      doc.components!.schemas['Pet']!.properties['id'].toString(),
      'APISchemaObject(type: integer, format: int64)',
    );
    expect(
      doc.paths['/pets/{id}']!.parameters.single.toString(),
      'APIParameter(name: id, in: path, required: true)',
    );
    final op = doc.paths['/pets']!.operations['get']!;
    expect(
      op.toString(),
      'APIOperation(operationId: listPets, responses: {200})',
    );
    final response =
        doc.paths['/pets/{id}']!.operations['get']!.responses['200']!;
    expect(
      response.toString(),
      'APIResponse(description: a pet, content: {application/json})',
    );
    expect(
      response.content['application/json']!.schema.toString(),
      r'APISchemaObject($ref: #/components/schemas/Pet)',
    );
    expect(APIEncoding.empty().toString(), 'APIEncoding()');
  });

  test('operations skips x- keys in paths', () {
    final d = APIDocument.fromMap({
      'openapi': '3.0.0',
      'info': {'title': 't', 'version': '1'},
      'paths': {
        'x-foo': {
          'get': {
            'responses': {
              '200': {'description': 'ok'},
            },
          },
        },
        '/a': {
          'get': {
            'responses': {
              '200': {'description': 'ok'},
            },
          },
        },
      },
    });
    expect([for (final o in d.operations) o.path], ['/a']);
    expect(APIDocument().operations, isEmpty);
  });

  test('toString shows enum, nullable and additionalProperties', () {
    final s = APISchemaObject.string()
      ..isNullable = true
      ..enumerated = ['a', 'b'];
    expect(
      s.toString(),
      'APISchemaObject(type: string, nullable: true, enum: 2)',
    );
    expect(APISchemaObject().toString(), 'APISchemaObject()');
    expect(
      APISchemaObject.freeForm().toString(),
      'APISchemaObject(type: object, additionalProperties: freeForm)',
    );
  });

  test('toString nests items and allOf', () {
    final s = APISchemaObject.array(ofSchema: APISchemaObject.string());
    expect(
      s.toString(),
      'APISchemaObject(type: array, items: APISchemaObject(type: string))',
    );
    final c = APISchemaObject()..allOf = [APISchemaObject.integer()];
    expect(
      c.toString(),
      'APISchemaObject(allOf: [APISchemaObject(type: integer)])',
    );
  });

  test('toString stops on cycles built in code', () {
    final s = APISchemaObject.array(ofType: APIType.string);
    s.items = s;
    expect(s.toString(), startsWith('APISchemaObject(type: array, items: '));
    expect(s.toString(), endsWith('APISchemaObject(…))))'));
    final a = APISchemaObject()..allOf = [];
    a.allOf.add(a);
    expect(a.toString(), contains('APISchemaObject(…)'));
    // The depth counter is reset afterwards.
    expect(
      APISchemaObject.string().toString(),
      'APISchemaObject(type: string)',
    );
  });

  test('toString keeps strings on one line', () {
    expect(
      APIResponse('line1\nline2').toString(),
      'APIResponse(description: line1…)',
    );
    expect(
      APIResponse('x' * 50).toString(),
      'APIResponse(description: ${'x' * 40}…)',
    );
    expect(APIContact(name: 'Ann').toString(), 'APIContact(name: Ann)');
    expect(
      APISecurityRequirement({'key': []}).toString(),
      'APISecurityRequirement(requirements: {key})',
    );
  });
}
