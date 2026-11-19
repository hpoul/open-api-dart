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
      'APISchemaObject(type: object, properties: [id, name])',
    );
    expect(
      doc.components!.schemas['Pet']!.properties['id'].toString(),
      'APISchemaObject(type: integer, format: int64)',
    );
    expect(
      doc.paths['/pets/{id}']!.parameters.single.toString(),
      'APIParameter(name: id, in: path)',
    );
    final op = doc.paths['/pets']!.operations['get']!;
    expect(
      op.toString(),
      'APIOperation(operationId: listPets, responses: [200])',
    );
    final response =
        doc.paths['/pets/{id}']!.operations['get']!.responses['200']!;
    expect(
      response.toString(),
      'APIResponse(description: a pet, content: [application/json])',
    );
    expect(
      response.content['application/json']!.schema.toString(),
      r'APISchemaObject($ref: #/components/schemas/Pet)',
    );
    expect(APIEncoding.empty().toString(), 'APIEncoding()');
  });
}
