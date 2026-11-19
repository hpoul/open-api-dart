import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

APIParameter param(Map<String, dynamic> p) => APIDocument.fromMap({
  'openapi': '3.0.0',
  'info': {'title': 'x', 'version': '1'},
  'paths': {
    '/a': {
      'parameters': [p],
    },
  },
}).paths['/a']!.parameters.single;

void main() {
  group('APIParameter defaults by location', () {
    for (final (location, style, explode) in [
      ('query', 'form', true),
      ('cookie', 'form', true),
      ('path', 'simple', false),
      ('header', 'simple', false),
    ]) {
      test(location, () {
        final p = param({'name': 'p', 'in': location});
        expect(p.style, isNull);
        expect(p.explode, isNull);
        expect(p.effectiveStyle, style);
        expect(p.effectiveExplode, explode);
        expect(p.effectiveAllowReserved, isFalse);
        expect(p.effectiveAllowEmptyValue, isFalse);
      });
    }
  });

  test('explode defaults from the given style', () {
    final p = param({'name': 'p', 'in': 'query', 'style': 'spaceDelimited'});
    expect(p.effectiveStyle, 'spaceDelimited');
    expect(p.effectiveExplode, isFalse);
  });

  test('explicit values win', () {
    final p = param({
      'name': 'p',
      'in': 'query',
      'explode': false,
      'allowReserved': true,
      'allowEmptyValue': true,
    });
    expect(p.effectiveExplode, isFalse);
    expect(p.effectiveAllowReserved, isTrue);
    expect(p.effectiveAllowEmptyValue, isTrue);
  });

  test('unset flags are not encoded', () {
    final p = APIParameter.empty()
      ..name = 'p'
      ..location = APIParameterLocation.query;
    expect(p.explode, isNull);
    expect(p.effectiveExplode, isTrue);
    final doc = APIDocument()
      ..info = APIInfo('x', '1')
      ..paths = {
        '/a': APIPath(parameters: [p]),
      };
    expect(doc.asMap()['paths']['/a']['parameters'][0], {
      'name': 'p',
      'in': 'query',
    });
  });

  test('APIHeader defaults', () {
    final h = APIHeader();
    expect(h.effectiveStyle, 'simple');
    expect(h.effectiveExplode, isFalse);
    expect((APIHeader()..style = 'form').effectiveExplode, isTrue);
  });

  test('APIEncoding defaults', () {
    final e = APIEncoding.empty();
    expect(e.effectiveStyle, 'form');
    expect(e.effectiveExplode, isTrue);
    expect(e.effectiveAllowReserved, isFalse);
    expect(
      (APIEncoding.empty()..style = 'deepObject').effectiveExplode,
      isFalse,
    );
  });

  test('explicit path styles and unknown locations', () {
    final p = param({'name': 'p', 'in': 'path', 'style': 'matrix'});
    expect(p.effectiveStyle, 'matrix');
    expect(p.effectiveExplode, isFalse);
    expect(param({'name': 'p', 'in': 'body'}).effectiveStyle, 'simple');
  });

  test('APIParameter.path() writes no default flags', () {
    final doc = APIDocument()
      ..info = APIInfo('x', '1')
      ..paths = {
        '/a/{id}': APIPath(parameters: [APIParameter.path('id')]),
      };
    expect(doc.asMap()['paths']['/a/{id}']['parameters'][0], {
      'name': 'id',
      'in': 'path',
      'required': true,
      'schema': {'type': 'string'},
    });
  });
}
