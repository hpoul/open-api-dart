import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

APISchemaObject schema(Map<String, dynamic> s) => APIDocument.fromMap({
  'openapi': '3.0.0',
  'info': {'title': 'x', 'version': '1'},
  'paths': <String, dynamic>{},
  'components': {
    'schemas': {'S': s},
  },
}).components!.schemas['S']!;

void main() {
  test('absent additionalProperties decodes as a null policy', () {
    final s = schema({'type': 'object'});
    expect(s.additionalPropertyPolicy, isNull);
    expect(s.additionalPropertySchema, isNull);
  });

  test('false, true, {} and a schema', () {
    expect(
      schema({'additionalProperties': false}).additionalPropertyPolicy,
      APISchemaAdditionalPropertyPolicy.disallowed,
    );
    expect(
      schema({'additionalProperties': true}).additionalPropertyPolicy,
      APISchemaAdditionalPropertyPolicy.freeForm,
    );
    expect(
      schema({
        'additionalProperties': <String, dynamic>{},
      }).additionalPropertyPolicy,
      APISchemaAdditionalPropertyPolicy.freeForm,
    );
    final restricted = schema({
      'additionalProperties': {'type': 'string'},
    });
    expect(
      restricted.additionalPropertyPolicy,
      APISchemaAdditionalPropertyPolicy.restricted,
    );
    expect(restricted.additionalPropertySchema!.type, APIType.string);
  });

  test('map() sets the policy, and null encodes nothing', () {
    expect(
      APISchemaObject.map(ofType: APIType.string).additionalPropertyPolicy,
      APISchemaAdditionalPropertyPolicy.restricted,
    );
    final any = APISchemaObject.map(any: true);
    expect(
      any.additionalPropertyPolicy,
      APISchemaAdditionalPropertyPolicy.freeForm,
    );
    final doc = APIDocument()
      ..info = APIInfo('x', '1')
      ..components = (APIComponents()
        ..schemas = {'Any': any, 'Plain': APISchemaObject.object({})});
    final schemas = doc.asMap()['components']['schemas'] as Map;
    expect(schemas['Any']['additionalProperties'], isTrue);
    expect(
      (schemas['Plain'] as Map).containsKey('additionalProperties'),
      isFalse,
    );
  });
}
