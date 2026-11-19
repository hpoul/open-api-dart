// ignore_for_file: deprecated_member_use_from_same_package

import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

void main() {
  test('every enum value round-trips through its json value', () {
    for (final type in APIType.values) {
      expect(APIType.fromJson(type.jsonValue), type);
      expect(type.toJson(), type.jsonValue);
    }
    for (final location in APIParameterLocation.values) {
      expect(APIParameterLocation.fromJson(location.jsonValue), location);
    }
    for (final type in APISecuritySchemeType.values) {
      expect(APISecuritySchemeType.fromJson(type.jsonValue), type);
    }
  });

  test('json values match the OpenAPI spelling', () {
    expect(APIType.values.map((e) => e.jsonValue), [
      'string',
      'number',
      'integer',
      'boolean',
      'array',
      'object',
    ]);
    expect(APIParameterLocation.values.map((e) => e.jsonValue), [
      'query',
      'header',
      'path',
      'cookie',
    ]);
    expect(APISecuritySchemeType.openIdConnect.jsonValue, 'openIdConnect');
  });

  test('legacy openID decodes as openIdConnect', () {
    expect(
      APISecuritySchemeType.fromJson('openID'),
      APISecuritySchemeType.openIdConnect,
    );
    final doc = APIDocument.fromMap({
      'openapi': '3.0.0',
      'info': {'title': 'x', 'version': '1'},
      'paths': <String, dynamic>{},
      'components': {
        'securitySchemes': {
          'oidc': {
            'type': 'openID',
            'openIdConnectUrl': 'https://example.com/.well-known/oidc',
          },
        },
      },
    });
    final encoded =
        // ignore: avoid_dynamic_calls
        doc.asMap()['components']['securitySchemes']['oidc'] as Map;
    expect(encoded['type'], 'openIdConnect');
  });

  test('unknown and null values decode to null', () {
    expect(APIType.fromJson('null'), isNull);
    expect(APIType.fromJson(null), isNull);
    expect(APIParameterLocation.fromJson('body'), isNull);
    expect(APISecuritySchemeType.fromJson('someFutureType'), isNull);
  });

  test('deprecated codecs still work', () {
    expect(APITypeCodec.decode('integer'), APIType.integer);
    expect(APITypeCodec.encode(APIType.array), 'array');
    expect(APITypeCodec.encode(null), isNull);
    expect(APIParameterLocationCodec.decode('path'), APIParameterLocation.path);
    expect(
      APIParameterLocationCodec.encode(APIParameterLocation.cookie),
      'cookie',
    );
    expect(
      APISecuritySchemeTypeCodec.decode('http'),
      APISecuritySchemeType.http,
    );
    expect(
      APISecuritySchemeTypeCodec.encode(APISecuritySchemeType.apiKey),
      'apiKey',
    );
  });
}
