/// The `type` of an [APISchemaObject](https://spec.openapis.org/oas/v3.0.3#schema-object).
enum APIType {
  string('string'),
  number('number'),
  integer('integer'),
  boolean('boolean'),
  array('array'),
  object('object');

  const APIType(this.jsonValue);

  /// The value used in OpenAPI documents.
  final String jsonValue;

  static final Map<String, APIType> _byJsonValue = {
    for (final value in values) value.jsonValue: value,
  };

  /// Returns the type for [jsonValue], or `null` if it is `null` or unknown.
  static APIType? fromJson(String? jsonValue) => _byJsonValue[jsonValue];

  String toJson() => jsonValue;
}

@Deprecated('Use APIType.fromJson and APIType.jsonValue.')
class APITypeCodec {
  static APIType? decode(String? type) => APIType.fromJson(type);

  static String? encode(APIType? type) => type?.jsonValue;
}
