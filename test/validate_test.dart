import 'dart:convert';
import 'dart:io';

import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

Map<String, dynamic> spec([Map<String, dynamic> extra = const {}]) => {
  'openapi': '3.0.0',
  'info': {'title': 'x', 'version': '1'},
  'paths': <String, dynamic>{},
  ...extra,
};

List<String> issues(Map<String, dynamic> map) => [
  for (final e in APIDocument.fromMap(map).validate())
    '${e.pointer} ${e.message}',
];

const ok = {
  '200': {'description': 'ok'},
};
const stringSchema = {'type': 'string'};

void main() {
  test('a minimal document has no issues', () {
    expect(issues(spec()), isEmpty);
  });

  test('missing info decodes, and is reported', () {
    final map = spec()..remove('info');
    expect(APIDocument.fromMap(map).info, isNull);
    expect(issues(map), ["#/info Missing required field 'info'."]);
  });

  test('missing info fields', () {
    expect(
      issues(
        spec({
          'info': {'license': <String, dynamic>{}},
        }),
      ),
      [
        "#/info/title Missing required field 'title'.",
        "#/info/version Missing required field 'version'.",
        "#/info/license/name Missing required field 'name'.",
      ],
    );
  });

  test('paths, operations, parameters and responses', () {
    expect(
      issues(
        spec({
          'paths': {
            'a': <String, dynamic>{},
            'x-ext': {'anything': 1},
            '/a/{id}': {
              'parameters': [
                {'in': 'path', 'schema': stringSchema},
                {'name': 'q', 'in': 'body'},
              ],
              'get': {'responses': <String, dynamic>{}},
              'post': {
                'requestBody': {'description': 'no content'},
                'responses': {
                  '200': {
                    'headers': {
                      'X-H': {
                        'content': {'text/plain': <String, dynamic>{}},
                      },
                    },
                  },
                  '600': {'description': 'odd'},
                  'x-note': {'a': 1},
                },
              },
            },
          },
        }),
      ),
      [
        "#/paths/a Path 'a' must begin with '/'.",
        "#/paths/~1a~1{id}/parameters/0/name Missing required field 'name'.",
        '#/paths/~1a~1{id}/parameters/1/in Missing or invalid required field '
            "'in'.",
        '#/paths/~1a~1{id}/parameters/1 A parameter must have exactly one of '
            "'schema' and 'content'.",
        '#/paths/~1a~1{id}/get/responses An operation must have at least one '
            'response.',
        "#/paths/~1a~1{id}/get/parameters Path parameter 'id' in '/a/{id}' is "
            'not declared.',
        '#/paths/~1a~1{id}/post/requestBody/content Missing required field '
            "'content'.",
        "#/paths/~1a~1{id}/post/responses/600 Response key '600' must be "
            "'default', a status code or a range like '2XX'.",
        '#/paths/~1a~1{id}/post/responses/200/description Missing required '
            "field 'description'.",
        "#/paths/~1a~1{id}/post/parameters Path parameter 'id' in '/a/{id}' "
            'is not declared.',
      ],
    );
  });

  test('path templates, duplicates and operationIds', () {
    expect(
      issues(
        spec({
          'paths': {
            '/a/{id}': {
              'parameters': [
                {'name': 'id', 'in': 'path', 'schema': stringSchema},
              ],
              'get': {
                'operationId': 'getA',
                'parameters': [
                  {'name': 'q', 'in': 'query', 'schema': stringSchema},
                  {'name': 'q', 'in': 'query', 'schema': stringSchema},
                  {'name': 'q', 'in': 'header', 'schema': stringSchema},
                ],
                'responses': ok,
              },
            },
            '/b': {
              'get': {
                'operationId': 'getA',
                'parameters': [
                  {'name': 'extra', 'in': 'path', 'schema': stringSchema},
                ],
                'responses': {'2XX': ok['200'], 'default': ok['200']},
              },
            },
          },
        }),
      ),
      [
        "#/paths/~1a~1{id}/get/parameters/1 Duplicate parameter 'q' in "
            "'query'.",
        "#/paths/~1b/get/operationId Duplicate operationId 'getA', also used "
            'at #/paths/~1a~1{id}/get.',
        "#/paths/~1b/get/parameters Path parameter 'extra' does not appear in "
            "'/b'.",
      ],
    );
  });

  test('references are checked at their target only', () {
    expect(
      issues(
        spec({
          'paths': {
            '/a/{id}': {
              'get': {
                'parameters': [
                  {r'$ref': '#/components/parameters/Id'},
                ],
                'responses': {
                  '200': {r'$ref': '#/components/responses/Ok'},
                },
              },
            },
          },
          'components': {
            'parameters': {
              'Id': {'name': 'id', 'in': 'path', 'schema': stringSchema},
            },
            'responses': {'Ok': <String, dynamic>{}},
          },
        }),
      ),
      [
        '#/components/responses/Ok/description Missing required field '
            "'description'.",
      ],
    );
  });

  test('security schemes and requirements', () {
    expect(
      issues(
        spec({
          'security': [
            {'missing': <dynamic>[]},
            {
              'key': ['scope'],
            },
            {
              'oauth': ['read'],
            },
          ],
          'components': {
            'securitySchemes': {
              'key': {'type': 'apiKey', 'in': 'path'},
              'basic': {'type': 'http'},
              'oauth': {
                'type': 'oauth2',
                'flows': {
                  'implicit': {'scopes': <String, dynamic>{}},
                  'password': {'scopes': <String, dynamic>{}},
                  'authorization_code': {'scopes': <String, dynamic>{}},
                  'x-vendor': {'scopes': <String, dynamic>{}},
                },
              },
              'oidc': {'type': 'openIdConnect'},
              'untyped': <String, dynamic>{},
              'future': {'type': 'mutualTLS'},
              'no flows': {'type': 'oauth2'},
            },
          },
        }),
      ),
      [
        "#/components/securitySchemes/no flows Component name 'no flows' "
            r'must match ^[a-zA-Z0-9.\-_]+$.',
        "#/components/securitySchemes/key/name Missing required field 'name'.",
        "#/components/securitySchemes/key/in An apiKey must be in 'query', "
            "'header' or 'cookie'.",
        '#/components/securitySchemes/basic/scheme Missing required field '
            "'scheme'.",
        '#/components/securitySchemes/oauth/flows/implicit/authorizationUrl '
            "Missing required field 'authorizationUrl'.",
        '#/components/securitySchemes/oauth/flows/password/tokenUrl Missing '
            "required field 'tokenUrl'.",
        '#/components/securitySchemes/oauth/flows/authorization_code Unknown '
            "OAuth2 flow 'authorization_code'; expected one of implicit, "
            'password, clientCredentials, authorizationCode.',
        '#/components/securitySchemes/oidc/openIdConnectUrl Missing required '
            "field 'openIdConnectUrl'.",
        '#/components/securitySchemes/untyped/type Missing or invalid '
            "required field 'type'.",
        '#/components/securitySchemes/future/type Missing or invalid '
            "required field 'type'.",
        '#/components/securitySchemes/no flows/flows Missing required field '
            "'flows'.",
        "#/security/0/missing Security requirement 'missing' names no "
            'security scheme in components.',
        "#/security/1/key Security requirement 'key' must have no scopes, "
            'because its scheme is not oauth2 or openIdConnect.',
      ],
    );
  });

  test('servers and tags', () {
    expect(
      issues(
        spec({
          'servers': [
            {
              'variables': {'v': <String, dynamic>{}},
            },
          ],
          'tags': [
            <String, dynamic>{},
            {'name': 't'},
            {'name': 't'},
          ],
        }),
      ),
      [
        "#/servers/0/url Missing required field 'url'.",
        "#/servers/0/variables/v/default Missing required field 'default'.",
        "#/tags/0/name Missing required field 'name'.",
        "#/tags/2/name Duplicate tag name 't'.",
      ],
    );
  });

  test('callbacks are checked, without path templates', () {
    expect(
      issues(
        spec({
          'paths': {
            '/a': {
              'post': {
                'responses': ok,
                'callbacks': {
                  'cb': {
                    r'{$request.body#/url}': {
                      'post': {
                        'responses': {'200': <String, dynamic>{}},
                      },
                    },
                  },
                },
              },
            },
          },
        }),
      ),
      [
        r'#/paths/~1a/post/callbacks/cb/{$request.body#~1url}/post/responses/'
            "200/description Missing required field 'description'.",
      ],
    );
  });

  test('the Stripe spec only has duplicate operationIds', () {
    final map =
        json.decode(File('test/specs/stripe.json').readAsStringSync())
            as Map<String, dynamic>;
    final found = issues(map);
    expect(found, isNotEmpty);
    expect(found, everyElement(contains('Duplicate operationId')));
  });
}
