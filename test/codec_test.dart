import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> spec() => {
    'openapi': '3.0.0',
    'info': {'title': 'x', 'version': '1'},
    'paths': {
      '/pets': {
        'get': {
          'tags': ['pets'],
          'responses': {
            '200': {
              'description': 'ok',
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
          'required': ['name'],
          'properties': {
            'name': {'type': 'string'},
            'owner': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
              },
            },
          },
        },
      },
    },
  };

  test('string lists decode as growable List<String>', () {
    final doc = APIDocument.fromMap(spec());
    final op = doc.paths['/pets']!.operations['get']!;
    expect(op.tags, isA<List<String>>());
    op.tags.add('more');

    final pet = doc.components!.schemas['Pet']!;
    expect(pet.required, isA<List<String>>());
    // The generator adds to `required`.
    pet.required.addAll(['owner']);
    expect(pet.required, ['name', 'owner']);
  });

  test('a reference exposes the fields of its target', () {
    final doc = APIDocument.fromMap(spec());
    final ref = doc
        .paths['/pets']!
        .operations['get']!
        .responses['200']!
        .content['application/json']!
        .schema!;
    expect(ref.referenceURI, Uri(path: '/components/schemas/Pet'));
    expect(ref.type, APIType.object);
    expect(ref.required, ['name']);
  });

  test('children reached through a reference are the target\'s instances', () {
    // The generator keys generated classes by schema identity.
    final doc = APIDocument.fromMap(spec());
    final target = doc.components!.schemas['Pet']!;
    final ref = doc
        .paths['/pets']!
        .operations['get']!
        .responses['200']!
        .content['application/json']!
        .schema!;
    expect(
      identical(ref.properties['owner'], target.properties['owner']),
      isTrue,
    );
  });

  test('maps with dynamic keys inside lists are decoded', () {
    final raw = spec();
    raw['servers'] = [
      <dynamic, dynamic>{'url': 'https://example.com'},
    ];
    final doc = APIDocument.fromMap(raw);
    expect(doc.servers!.single.url, 'https://example.com');
  });
}
