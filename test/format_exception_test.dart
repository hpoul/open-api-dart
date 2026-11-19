import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

Map<String, dynamic> spec(Map<String, dynamic> paths) => {
  'openapi': '3.0.0',
  'info': {'title': 'x', 'version': '1'},
  'paths': paths,
};

Matcher failsAt(String pointer, [String? message]) => throwsA(
  isA<OpenApiFormatException>()
      .having((e) => e.pointer, 'pointer', pointer)
      .having((e) => e.message, 'message', contains(message ?? '')),
);

void main() {
  test('is a FormatException', () {
    expect(OpenApiFormatException('m', pointer: '#/a'), isA<FormatException>());
    expect(
      OpenApiFormatException('m', pointer: '#/a').toString(),
      'OpenApiFormatException: m (at #/a)',
    );
  });

  test('wrong scalar type points at the value, escaping the path', () {
    expect(
      () => APIDocument.fromMap(
        spec({
          '/pets/{id}': {
            'get': {'summary': 42, 'responses': <String, dynamic>{}},
          },
        }),
      ),
      failsAt(
        '#/paths/~1pets~1{id}/get/summary',
        'Expected a string, found a number',
      ),
    );
  });

  test('a string where an object is expected', () {
    expect(
      () => APIDocument.fromMap(
        spec({
          '/a': {
            'get': {
              'responses': {'200': 'ok'},
            },
          },
        }),
      ),
      failsAt('#/paths/~1a/get/responses/200', 'Expected an object'),
    );
  });

  test('a bad list element points at its index', () {
    expect(
      () => APIDocument.fromMap(
        spec({
          '/a': {
            'get': {
              'tags': ['a', 3],
              'responses': <String, dynamic>{},
            },
          },
        }),
      ),
      failsAt('#/paths/~1a/get/tags/1'),
    );
    expect(
      () => APIDocument.fromMap(
        spec({
          '/a': {
            'parameters': [
              {'name': 'p', 'in': 'query'},
              'nope',
            ],
          },
        }),
      ),
      failsAt('#/paths/~1a/parameters/1', 'Expected an object'),
    );
  });

  test('a list where an object is expected', () {
    expect(
      () => APIDocument.fromMap(spec({})..['components'] = <dynamic>[]),
      failsAt('#/components', 'Expected an object, found a list'),
    );
  });

  test('a non-string key, as YAML can produce', () {
    expect(
      () => APIDocument.fromMap(
        spec({
          '/a': {
            'get': {
              'responses': {200: <String, dynamic>{}},
            },
          },
        }),
      ),
      failsAt('#/paths/~1a/get/responses/200', 'Keys must be strings'),
    );
  });

  test('an invalid URI', () {
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['info'] = {
            'title': 'x',
            'version': '1',
            'license': {'name': 'MIT', 'url': 'http://[::1'},
          },
      ),
      failsAt('#/info/license/url', 'Invalid Uri'),
    );
  });

  test('an unknown security scheme type', () {
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['components'] = {
            'securitySchemes': {
              'k': {'type': 'magic'},
            },
          },
      ),
      failsAt('#/components/securitySchemes/k/type'),
    );
  });

  test('a callback with a non-object path item', () {
    expect(
      () => APIDocument.fromMap(
        spec({
          '/a': {
            'post': {
              'responses': <String, dynamic>{},
              'callbacks': {
                'cb': {'{\$request.body#/url}': 'nope'},
              },
            },
          },
        }),
      ),
      failsAt(r'#/paths/~1a/post/callbacks/cb/{$request.body#~1url}'),
    );
  });

  test('a non-string scope description', () {
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['components'] = {
            'securitySchemes': {
              'o': {
                'type': 'oauth2',
                'flows': {
                  'implicit': {
                    'authorizationUrl': 'https://a',
                    'scopes': {'read': 1},
                  },
                },
              },
            },
          },
      ),
      failsAt('#/components/securitySchemes/o/flows/implicit/scopes/read'),
    );
  });

  test('bad security requirement lists', () {
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['security'] = [
            {'a': null},
          ],
      ),
      failsAt('#/security/0/a'),
    );
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['security'] = [
            {
              'a': [1],
            },
          ],
      ),
      failsAt('#/security/0/a/0', 'Expected a string, found a number'),
    );
  });

  test('an integer field names the expected type plainly', () {
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['components'] = {
            'schemas': {
              'S': {'maxLength': 1.5},
            },
          },
      ),
      failsAt(
        '#/components/schemas/S/maxLength',
        'Expected an integer, found a number',
      ),
    );
  });

  test('a cycle of references', () {
    expect(
      () => APIDocument.fromMap(
        spec({})
          ..['components'] = {
            'schemas': {
              'A': {r'$ref': '#/components/schemas/B'},
              'B': {r'$ref': '#/components/schemas/A'},
            },
          },
      ),
      failsAt(r'#/components/schemas/A/$ref', 'cycle'),
    );
  });

  test('a self-referencing schema is not a cycle', () {
    final doc = APIDocument.fromMap(
      spec({})
        ..['components'] = {
          'schemas': {
            'Node': {
              'type': 'object',
              'properties': {
                'next': {r'$ref': '#/components/schemas/Node'},
              },
            },
          },
        },
    );
    expect(doc.components!.schemas['Node']!.properties['next'], isNotNull);
  });
}
