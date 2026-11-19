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

void main() {
  test('a minimal document is valid', () {
    expect(issues(spec()), isEmpty);
  });

  test('missing info decodes, and is reported', () {
    final map = spec()..remove('info');
    final doc = APIDocument.fromMap(map);
    expect(doc.info, isNull);
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

  test('operations, parameters and responses', () {
    expect(
      issues(
        spec({
          'paths': {
            '/a/{id}': {
              'parameters': [
                {'in': 'path'},
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
                },
              },
            },
          },
        }),
      ),
      [
        "#/paths/~1a~1{id}/parameters/0/name Missing required field 'name'.",
        '#/paths/~1a~1{id}/get/responses An operation must have at least one '
            'response.',
        '#/paths/~1a~1{id}/post/requestBody/content Missing required field '
            "'content'.",
        '#/paths/~1a~1{id}/post/responses/200/description Missing required '
            "field 'description'.",
      ],
    );
  });

  test('references are checked at their target only', () {
    expect(
      issues(
        spec({
          'paths': {
            '/a': {
              'get': {
                'responses': {
                  '200': {r'$ref': '#/components/responses/Ok'},
                },
              },
            },
          },
          'components': {
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
            {'key': <dynamic>[]},
          ],
          'components': {
            'securitySchemes': {
              'key': {'type': 'apiKey'},
              'basic': {'type': 'http'},
              'oauth': {
                'type': 'oauth2',
                'flows': {
                  'implicit': {'scopes': <String, dynamic>{}},
                  'password': {'scopes': <String, dynamic>{}},
                },
              },
              'oidc': {'type': 'openIdConnect'},
              'no flows': {'type': 'oauth2'},
            },
          },
        }),
      ),
      [
        '#/components/securitySchemes/no flows Component name \'no flows\' '
            r'must match ^[a-zA-Z0-9.\-_]+$.',
        "#/components/securitySchemes/key/name Missing required field 'name'.",
        "#/components/securitySchemes/key/in Missing required field 'in'.",
        '#/components/securitySchemes/basic/scheme Missing required field '
            "'scheme'.",
        '#/components/securitySchemes/oauth/flows/implicit/authorizationUrl '
            "Missing required field 'authorizationUrl'.",
        '#/components/securitySchemes/oauth/flows/password/tokenUrl Missing '
            "required field 'tokenUrl'.",
        '#/components/securitySchemes/oidc/openIdConnectUrl Missing required '
            "field 'openIdConnectUrl'.",
        '#/components/securitySchemes/no flows/flows Missing required field '
            "'flows'.",
        "#/security/0/missing Security requirement 'missing' names no "
            'security scheme in components.',
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
          'tags': [<String, dynamic>{}],
        }),
      ),
      [
        "#/servers/0/url Missing required field 'url'.",
        "#/servers/0/variables/v/default Missing required field 'default'.",
        "#/tags/0/name Missing required field 'name'.",
      ],
    );
  });

  test('the Stripe spec is valid', () {
    final map =
        json.decode(File('test/specs/stripe.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(issues(map), isEmpty);
  });
}
