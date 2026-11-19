import 'dart:convert';

import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

/// Decodes [spec] after a JSON round trip, so nested literals become the
/// `Map<String, dynamic>`/`List<dynamic>` that `jsonDecode` produces.
APIDocument decode(Map<String, dynamic> spec) =>
    APIDocument.fromMap(json.decode(json.encode(spec)) as Map<String, dynamic>);

Map<String, dynamic> base({
  Map<String, dynamic> paths = const {},
  Map<String, dynamic>? components,
  Object? security,
  Object? servers,
}) => {
  'openapi': '3.0.0',
  'info': {'title': 'x', 'version': '1'},
  'paths': paths,
  'components': ?components,
  'security': ?security,
  'servers': ?servers,
};

void main() {
  group('Absent collections', () {
    final doc = decode(
      base(
        paths: {
          '/a': {
            'get': {
              'responses': {
                '200': {'description': 'ok'},
              },
            },
          },
        },
        components: {
          'schemas': {
            'S': {'type': 'object'},
          },
        },
      ),
    );
    final op = doc.paths['/a']!.operations['get']!;
    final schema = doc.components!.schemas['S']!;

    test('decode as empty', () {
      expect(doc.tags, isEmpty);
      expect(op.tags, isEmpty);
      expect(op.parameters, isEmpty);
      expect(op.callbacks, isEmpty);
      expect(op.responses['200']!.content, isEmpty);
      expect(op.responses['200']!.headers, isEmpty);
      expect(schema.properties, isEmpty);
      expect(schema.required, isEmpty);
      expect(schema.allOf, isEmpty);
      expect(doc.components!.responses, isEmpty);
    });

    test('are growable', () {
      final d = decode(base(components: {'schemas': <String, dynamic>{}}));
      final s = APISchemaObject.object({});
      d.components!.schemas['New'] = s;
      s.required.add('id');
      expect(s.required, ['id']);
    });

    test('stay absent when encoded', () {
      final encoded = decode(base(components: {})).asMap();
      expect(encoded['components'], <String, dynamic>{});
      expect(encoded.containsKey('tags'), isFalse);
    });

    test('are encoded once filled', () {
      final d = decode(base());
      d.tags.add(APITag.empty()..name = 't');
      expect(d.asMap()['tags'], [
        {'name': 't'},
      ]);
    });
  });

  group('Empty collections present in the input', () {
    test('round trip as empty', () {
      final spec = base(
        paths: {
          '/a': {
            'parameters': <dynamic>[],
            'post': {
              'tags': <dynamic>[],
              'requestBody': {
                'required': false,
                'content': {
                  'multipart/form-data': {
                    'schema': {
                      'type': 'object',
                      'properties': <String, dynamic>{},
                      'required': <dynamic>[],
                    },
                    'encoding': <String, dynamic>{},
                  },
                },
              },
              'responses': {
                '200': {'description': 'ok', 'headers': <String, dynamic>{}},
              },
            },
          },
        },
        components: {'schemas': <String, dynamic>{}},
      );
      final normalized = json.decode(json.encode(spec));
      expect(decode(spec).asMap(), normalized);
    });

    test('are omitted again after being emptied', () {
      final doc = decode(
        base(
          components: {
            'schemas': {
              'S': {
                'properties': {
                  'a': {'type': 'string'},
                },
              },
            },
          },
        ),
      );
      doc.components!.schemas['S']!.properties.clear();
      expect(
        (doc.asMap()['components']['schemas']['S'] as Map).containsKey(
          'properties',
        ),
        isFalse,
      );
    });
  });

  group('security and servers stay nullable', () {
    test('absent decodes as null and stays absent', () {
      final doc = decode(base());
      expect(doc.security, isNull);
      expect(doc.servers, isNull);
      final encoded = doc.asMap();
      expect(encoded.containsKey('security'), isFalse);
      expect(encoded.containsKey('servers'), isFalse);
    });

    test('empty is kept, meaning no auth', () {
      final doc = decode(
        base(
          paths: {
            '/a': {
              'get': {
                'security': <dynamic>[],
                'responses': {
                  '200': {'description': 'ok'},
                },
              },
            },
          },
          security: [
            {'key': <dynamic>[]},
          ],
        ),
      );
      final op = doc.paths['/a']!.operations['get']!;
      expect(op.security, isEmpty);
      expect(op.servers, isNull);
      expect(doc.asMap()['paths']['/a']['get']['security'], isEmpty);
    });

    test('empty list set in code is encoded', () {
      final doc = decode(base())..security = [];
      expect(doc.asMap()['security'], isEmpty);
    });
  });

  test('a null element is rejected', () {
    expect(
      () => decode(
        base(
          components: {
            'schemas': {'S': null},
          },
        ),
      ),
      throwsArgumentError,
    );
  });

  test('a reference exposes the target collections', () {
    final doc = decode(
      base(
        components: {
          'schemas': {
            'Target': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
              },
              'required': ['id'],
            },
            'Ref': {r'$ref': '#/components/schemas/Target'},
          },
        },
      ),
    );
    final target = doc.components!.schemas['Target']!;
    final ref = doc.components!.schemas['Ref']!;
    expect(ref.properties['id'], same(target.properties['id']));
    expect(ref.required, ['id']);
    expect(doc.asMap()['components']['schemas']['Ref'], {
      r'$ref': '#/components/schemas/Target',
    });
  });

  test('addContent merges a second schema into oneOf', () {
    final a = APISchemaObject.string();
    final b = APISchemaObject.integer();
    final c = APISchemaObject.boolean();
    final response = APIResponse('ok')
      ..addContent('application/json', a)
      ..addContent('application/json', b)
      ..addContent('application/json', c);
    final schema = response.content['application/json']!.schema!;
    expect(schema.oneOf, [a, b, c]);
  });

  test('constructors default to growable empty collections', () {
    final op = APIOperation('id', null);
    op.addParameter(APIParameter.path('p'));
    op.responses['200'] = APIResponse('ok');
    expect(op.parameters, hasLength(1));
    expect(op.tags, isEmpty);
    expect(op.security, isNull);
    expect(APIPath().parameters, isEmpty);
    expect(APIServerVariable('d').availableValues, isEmpty);
  });

  test('required collections are always encoded', () {
    final doc = APIDocument()
      ..version = '3.0.0'
      ..info = APIInfo('x', '1');
    expect(doc.asMap()['paths'], <String, dynamic>{});
    final op = APIOperation('x', null);
    final body = APIRequestBody({});
    final archive = APIDocument()
      ..version = '3.0.0'
      ..info = APIInfo('x', '1')
      ..paths = {
        '/a': APIPath(operations: {'post': op..requestBody = body}),
      };
    final encoded = archive.asMap()['paths']['/a']['post'] as Map;
    expect(encoded['responses'], <String, dynamic>{});
    expect(encoded['requestBody']['content'], <String, dynamic>{});
  });

  test('decoding again forgets earlier empty keys', () {
    final schema = APISchemaObject()
      ..decode(KeyedArchive.unarchive({'required': <dynamic>[]}));
    expect(KeyedArchive.archive(schema).containsKey('required'), isTrue);
    schema.decode(KeyedArchive.unarchive({'type': 'string'}));
    expect(KeyedArchive.archive(schema).containsKey('required'), isFalse);
  });
}
