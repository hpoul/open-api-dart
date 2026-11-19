import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/discriminator.dart';
import 'package:open_api_forked/src/v3/external_docs.dart';
import 'package:open_api_forked/src/v3/types.dart';
import 'package:open_api_forked/src/v3/xml.dart';

enum APISchemaAdditionalPropertyPolicy {
  /// When [APISchemaObject] prevents properties other than those defined by [APISchemaObject.properties] from being included
  disallowed,

  /// When [APISchemaObject] allows any additional properties
  freeForm,

  /// When [APISchemaObject.additionalPropertySchema] contains a schema object
  restricted,
}

/// Represents a schema object in the OpenAPI specification.
final class APISchemaObject extends APIObject {
  APISchemaObject();
  APISchemaObject.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'type': types.length > 1
        ? types.map((t) => t.jsonValue).join('|')
        : type?.jsonValue,
    'format': format,
    'nullable': (isNullable ?? false) ? true : null,
    'enum': enumerated?.length,
    'properties': properties,
    'additionalProperties': additionalPropertyPolicy,
    'items': items,
    'allOf': allOf,
    'oneOf': oneOf,
    'anyOf': anyOf,
  };

  APISchemaObject.string({this.format}) : _type = APIType.string;
  APISchemaObject.number() : _type = APIType.number;
  APISchemaObject.integer() : _type = APIType.integer;
  APISchemaObject.boolean() : _type = APIType.boolean;
  APISchemaObject.map({
    APIType? ofType,
    APISchemaObject? ofSchema,
    bool any = false,
  }) : _type = APIType.object {
    if (ofType != null) {
      additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.restricted;
      additionalPropertySchema = APISchemaObject()..type = ofType;
    } else if (ofSchema != null) {
      additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.restricted;
      additionalPropertySchema = ofSchema;
    } else if (any) {
      additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.freeForm;
    } else {
      throw ArgumentError(
        "Invalid 'APISchemaObject.map' with neither 'ofType', 'any' or 'ofSchema' specified.",
      );
    }
  }
  APISchemaObject.array({APIType? ofType, APISchemaObject? ofSchema})
    : _type = APIType.array {
    if (ofType != null) {
      items = APISchemaObject()..type = ofType;
    } else if (ofSchema != null) {
      items = ofSchema;
    } else {
      throw ArgumentError(
        "Invalid 'APISchemaObject.array' with neither 'ofType' or 'ofSchema' specified.",
      );
    }
  }
  APISchemaObject.object(this.properties) : _type = APIType.object;
  APISchemaObject.file({bool isBase64Encoded = false})
    : _type = APIType.string,
      format = isBase64Encoded ? 'byte' : 'binary';

  APISchemaObject.freeForm()
    : _type = APIType.object,
      additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.freeForm;

  /// A title for the object.
  String? title;

  /// The value of "maximum" MUST be a number, representing an upper limit
  /// for a numeric instance.
  ///
  /// If the instance is a number, then this keyword validates if
  /// "exclusiveMaximum" is true and instance is less than the provided
  /// value, or else if the instance is less than or exactly equal to the
  /// provided value.
  num? maximum;

  ///  The value of "exclusiveMaximum" MUST be a boolean, representing
  ///  whether the limit in "maximum" is exclusive or not.
  ///
  ///  An undefined value is the same as false.
  ///
  ///  If "exclusiveMaximum" is true, then a numeric instance SHOULD NOT be
  ///  equal to the value specified in "maximum".  If "exclusiveMaximum" is
  ///  false (or not specified), then a numeric instance MAY be equal to the
  ///  value of "maximum".
  bool? exclusiveMaximum;

  /// The exclusive upper limit, as OpenAPI 3.1 writes `exclusiveMaximum`:
  /// a number instead of a flag for [maximum].
  ///
  /// [effectiveExclusiveMaximum] gives the limit for either form.
  num? exclusiveMaximumValue;

  /// The exclusive upper limit: [exclusiveMaximumValue], or [maximum] when
  /// [exclusiveMaximum] is true. `null` when there is none.
  num? get effectiveExclusiveMaximum =>
      exclusiveMaximumValue ?? (exclusiveMaximum == true ? maximum : null);

  /// The value of "minimum" MUST be a number, representing a lower limit
  /// for a numeric instance.

  /// If the instance is a number, then this keyword validates if
  /// "exclusiveMinimum" is true and instance is greater than the provided
  /// value, or else if the instance is greater than or exactly equal to
  /// the provided value.
  num? minimum;

  /// The value of "exclusiveMinimum" MUST be a boolean, representing
  /// whether the limit in "minimum" is exclusive or not.  An undefined
  /// value is the same as false.

  /// If "exclusiveMinimum" is true, then a numeric instance SHOULD NOT be
  /// equal to the value specified in "minimum".  If "exclusiveMinimum" is
  /// false (or not specified), then a numeric instance MAY be equal to the
  /// value of "minimum".
  bool? exclusiveMinimum;

  /// The exclusive lower limit, as OpenAPI 3.1 writes `exclusiveMinimum`:
  /// a number instead of a flag for [minimum].
  ///
  /// [effectiveExclusiveMinimum] gives the limit for either form.
  num? exclusiveMinimumValue;

  /// The exclusive lower limit: [exclusiveMinimumValue], or [minimum] when
  /// [exclusiveMinimum] is true. `null` when there is none.
  num? get effectiveExclusiveMinimum =>
      exclusiveMinimumValue ?? (exclusiveMinimum == true ? minimum : null);

  /// The value of this keyword MUST be a non-negative integer.
  ///
  /// The value of this keyword MUST be an integer.  This integer MUST be
  /// greater than, or equal to, 0.
  ///
  /// A string instance is valid against this keyword if its length is less
  /// than, or equal to, the value of this keyword.
  ///
  /// The length of a string instance is defined as the number of its
  /// characters as defined by RFC 7159 [RFC7159].
  int? maxLength;

  /// A string instance is valid against this keyword if its length is
  /// greater than, or equal to, the value of this keyword.
  ///
  /// The length of a string instance is defined as the number of its
  /// characters as defined by RFC 7159 [RFC7159].
  ///
  /// The value of this keyword MUST be an integer.  This integer MUST be
  /// greater than, or equal to, 0.
  ///
  /// "minLength", if absent, may be considered as being present with
  /// integer value 0.
  int? minLength;

  /// The value of this keyword MUST be a string.  This string SHOULD be a
  /// valid regular expression, according to the ECMA 262 regular
  /// expression dialect.
  ///
  /// A string instance is considered valid if the regular expression
  /// matches the instance successfully.  Recall: regular expressions are
  /// not implicitly anchored.
  String? pattern;

  /// The value of this keyword MUST be an integer.  This integer MUST be
  /// greater than, or equal to, 0.
  ///
  /// An array instance is valid against "maxItems" if its size is less
  /// than, or equal to, the value of this keyword.
  int? maxItems;

  /// The value of this keyword MUST be an integer.  This integer MUST be
  /// greater than, or equal to, 0.
  ///
  /// An array instance is valid against "minItems" if its size is greater
  /// than, or equal to, the value of this keyword.
  ///
  /// If this keyword is not present, it may be considered present with a
  /// value of 0.
  int? minItems;

  /// The value of this keyword MUST be a boolean.
  ///
  /// If this keyword has boolean value false, the instance validates
  /// successfully.  If it has boolean value true, the instance validates
  /// successfully if all of its elements are unique.

  /// If not present, this keyword may be considered present with boolean
  /// value false.
  bool? uniqueItems;

  /// The value of "multipleOf" MUST be a number, strictly greater than 0.

  /// A numeric instance is only valid if division by this keyword's value
  /// results in an integer.
  num? multipleOf;

  /// The value of this keyword MUST be an integer.  This integer MUST be
  /// greater than, or equal to, 0.
  ///
  /// An object instance is valid against "maxProperties" if its number of
  /// properties is less than, or equal to, the value of this keyword.
  int? maxProperties;

  /// The value of this keyword MUST be an integer.  This integer MUST be
  /// greater than, or equal to, 0.
  ///
  /// An object instance is valid against "minProperties" if its number of
  /// properties is greater than, or equal to, the value of this keyword.
  ///
  /// If this keyword is not present, it may be considered present with a
  /// value of 0.
  int? minProperties;

  /// The value of this keyword MUST be an array.  This array MUST have at
  /// least one element.  Elements of this array MUST be strings, and MUST
  /// be unique.
  ///
  /// An object instance is valid against this keyword if its property set
  /// contains all elements in this keyword's array value.
  List<String> required = [];

  /// The value of this keyword MUST be an array.  This array SHOULD have
  /// at least one element.  Elements in the array SHOULD be unique.
  ///
  /// Elements in the array MAY be of any type, including null.
  ///
  /// An instance validates successfully against this keyword if its value
  /// is equal to one of the elements in this keyword's array value.
  List<dynamic>? enumerated;

  /// The single value an instance must equal (`const`, OpenAPI 3.1), kept
  /// as decoded. `null` when absent, and also for `const: null`.
  Object? constValue;

  /// Examples of instances of this schema (`examples`, OpenAPI 3.1), kept
  /// as decoded. See also [example].
  List<Object?>? examples;

  /// The media type of the contents of a string (`contentMediaType`,
  /// OpenAPI 3.1), such as `image/png`.
  String? contentMediaType;

  /// How a string encodes binary contents (`contentEncoding`, OpenAPI 3.1),
  /// such as `base64`.
  String? contentEncoding;

  /* Modified JSON Schema for OpenAPI */

  /// The type of instances, when there is exactly one besides `null`.
  ///
  /// OpenAPI 3.1 may give several types, as in `type: [string, integer]`;
  /// then this is `null` and [types] has them. A `"null"` type makes
  /// [isNullable] true instead of appearing here. Setting this replaces
  /// [types] with just this type.
  APIType? get type => _type;

  set type(APIType? value) {
    _type = value;
    _types = null;
    _typeIsList = false;
  }

  /// All types besides `null`, in document order: empty when there are
  /// none, `[type]` for a single one.
  ///
  /// Setting this writes `type` as an array, as OpenAPI 3.1 does. Types
  /// this package does not know are left out.
  List<APIType> get types => _types ?? List.unmodifiable([?_type]);

  set types(List<APIType> value) {
    _types = List.unmodifiable(value);
    _type = value.length == 1 ? value.single : null;
    _typeIsList = true;
  }

  APIType? _type;
  List<APIType>? _types;

  /// Whether `type` was an array, so it is written as one again.
  bool _typeIsList = false;

  /// Whether `type` had `"null"` (OpenAPI 3.1).
  bool _nullType = false;
  List<APISchemaObject> allOf = [];
  List<APISchemaObject> anyOf = [];
  List<APISchemaObject> oneOf = [];
  APISchemaObject? not;

  APISchemaObject? items;
  Map<String, APISchemaObject> properties = {};

  /// The schema of additional properties, when [additionalPropertyPolicy]
  /// is [APISchemaAdditionalPropertyPolicy.restricted].
  APISchemaObject? additionalPropertySchema;

  /// How `additionalProperties` was given: `false`, `true` or `{}`, or a
  /// schema. `null` when it was not given; JSON Schema then allows any
  /// additional properties, but many generators treat that as disallowed,
  /// so the choice is left to the consumer.
  APISchemaAdditionalPropertyPolicy? additionalPropertyPolicy;

  String? description;
  String? format;
  dynamic defaultValue;

  /// Whether `null` is allowed: `nullable: true` (OpenAPI 3.0), or a
  /// `"null"` type (3.1).
  ///
  /// Setting it keeps the form the schema was decoded in: a schema whose
  /// `type` had `"null"` or was an array adds or removes `"null"` there,
  /// any other schema writes `nullable`, which OpenAPI 3.1 does not have:
  /// set [types] first to make a 3.1 schema nullable.
  bool? get isNullable => (_nullable ?? false) || _nullType;

  set isNullable(bool? n) {
    if (_typeIsList || _nullType) {
      _nullType = n ?? false;
      if (_nullable != null) {
        _nullable = n;
      }
    } else {
      _nullable = n;
    }
  }

  bool? get isReadOnly => _readOnly ?? false;

  set isReadOnly(bool? n) {
    _readOnly = n;
  }

  bool? get isWriteOnly => _writeOnly ?? false;

  set isWriteOnly(bool? n) {
    _writeOnly = n;
  }

  bool? get isDeprecated => _deprecated ?? false;

  set isDeprecated(bool? n) {
    _deprecated = n;
  }

  bool? _nullable;
  bool? _readOnly;
  bool? _writeOnly;
  bool? _deprecated;

  /// Additional external documentation.
  APIExternalDocumentation? externalDocs;

  /// Tells which schema in `oneOf`/`anyOf` (or which `allOf` subtype) a
  /// payload matches.
  APIDiscriminator? discriminator;

  /// How the property is represented in XML.
  APIXml? xml;

  /// An example of an instance of this schema, kept as decoded.
  Object? example;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    title = object.decode('title');
    maximum = object.decode('maximum');
    final (exclusiveMax, exclusiveMaxValue) = _exclusiveLimit(
      object,
      'exclusiveMaximum',
    );
    exclusiveMaximum = exclusiveMax;
    exclusiveMaximumValue = exclusiveMaxValue;
    minimum = object.decode('minimum');
    final (exclusiveMin, exclusiveMinValue) = _exclusiveLimit(
      object,
      'exclusiveMinimum',
    );
    exclusiveMinimum = exclusiveMin;
    exclusiveMinimumValue = exclusiveMinValue;
    maxLength = object.decode('maxLength');
    minLength = object.decode('minLength');
    pattern = object.decode('pattern');
    maxItems = object.decode('maxItems');
    minItems = object.decode('minItems');
    uniqueItems = object.decode('uniqueItems');
    multipleOf = object.decode('multipleOf');
    enumerated = object.decode('enum');
    minProperties = object.decode('minProperties');
    maxProperties = object.decode('maxProperties');
    required = object.decodeList<String>('required') ?? [];

    //

    _decodeType(object);
    constValue = object.decode<Object?>('const');
    final examples = object.decode<Object?>('examples');
    this.examples = examples is List ? List<Object?>.of(examples) : null;
    contentMediaType = object.decode('contentMediaType');
    contentEncoding = object.decode('contentEncoding');
    allOf = object.decodeObjects('allOf', () => APISchemaObject()) ?? [];
    anyOf = object.decodeObjects('anyOf', () => APISchemaObject()) ?? [];
    oneOf = object.decodeObjects('oneOf', () => APISchemaObject()) ?? [];
    not = object.decodeObject('not', () => APISchemaObject());

    items = object.decodeObject('items', () => APISchemaObject());
    properties =
        object.decodeObjectMap('properties', () => APISchemaObject()) ?? {};

    final addlProps = object['additionalProperties'];
    if (addlProps == null) {
      additionalPropertyPolicy = null;
      additionalPropertySchema = null;
    } else if (addlProps is bool) {
      if (addlProps) {
        additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.freeForm;
      } else {
        additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.disallowed;
      }
    } else if (addlProps is KeyedArchive && addlProps.isEmpty) {
      additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.freeForm;
    } else {
      additionalPropertyPolicy = APISchemaAdditionalPropertyPolicy.restricted;
      additionalPropertySchema = object.decodeObject(
        'additionalProperties',
        () => APISchemaObject(),
      );
    }

    description = object.decode('description');
    format = object.decode('format');
    defaultValue = object.decode<Object?>('default');

    _nullable = object.decode('nullable');
    _readOnly = object.decode('readOnly');
    _writeOnly = object.decode('writeOnly');
    _deprecated = object.decode('deprecated');
    externalDocs = object.decodeObject(
      'externalDocs',
      () => APIExternalDocumentation.empty(),
    );
    discriminator = object.decodeObject(
      'discriminator',
      () => APIDiscriminator.empty(),
    );
    xml = object.decodeObject('xml', () => APIXml.empty());
    example = object.decode<Object?>('example');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('title', title);
    object.encode('maximum', maximum);
    object.encode(
      'exclusiveMaximum',
      exclusiveMaximumValue ?? exclusiveMaximum,
    );
    object.encode('minimum', minimum);
    object.encode(
      'exclusiveMinimum',
      exclusiveMinimumValue ?? exclusiveMinimum,
    );
    object.encode('maxLength', maxLength);
    object.encode('minLength', minLength);
    object.encode('pattern', pattern);
    object.encode('maxItems', maxItems);
    object.encode('minItems', minItems);
    object.encode('uniqueItems', uniqueItems);
    object.encode('multipleOf', multipleOf);
    object.encode('enum', enumerated);
    object.encode('minProperties', minProperties);
    object.encode('maxProperties', maxProperties);
    object.encode('required', required, omitEmpty: true);

    //

    final typeNames = [
      for (final type in types) type.jsonValue,
      if (_nullType) 'null',
    ];
    if (typeNames.length == 1 && !_typeIsList) {
      object.encode('type', typeNames.single);
    } else if (typeNames.isNotEmpty) {
      // An empty array is not a valid `type`, so none is written then.
      object.encode('type', typeNames);
    }
    object.encode('const', constValue);
    object.encode('examples', examples);
    object.encode('contentMediaType', contentMediaType);
    object.encode('contentEncoding', contentEncoding);
    object.encodeObjects('allOf', allOf, omitEmpty: true);
    object.encodeObjects('anyOf', anyOf, omitEmpty: true);
    object.encodeObjects('oneOf', oneOf, omitEmpty: true);
    object.encodeObject('not', not);

    object.encodeObject('items', items);
    if (additionalPropertyPolicy != null || additionalPropertySchema != null) {
      if (additionalPropertyPolicy ==
          APISchemaAdditionalPropertyPolicy.disallowed) {
        object.encode('additionalProperties', false);
      } else if (additionalPropertyPolicy ==
          APISchemaAdditionalPropertyPolicy.freeForm) {
        object.encode('additionalProperties', true);
      } else {
        object.encodeObject('additionalProperties', additionalPropertySchema);
      }
    }
    object.encodeObjectMap('properties', properties, omitEmpty: true);

    object.encode('description', description);
    object.encode('format', format);
    object.encode('default', defaultValue);

    object.encode('nullable', _nullable);
    object.encode('readOnly', _readOnly);
    object.encode('writeOnly', _writeOnly);
    object.encode('deprecated', _deprecated);
    object.encodeObject('externalDocs', externalDocs);
    object.encodeObject('discriminator', discriminator);
    object.encodeObject('xml', xml);
    object.encode('example', example);
  }

  void _decodeType(KeyedArchive object) {
    _type = null;
    _types = null;
    _typeIsList = false;
    _nullType = false;
    switch (object.decode<Object?>('type')) {
      case null:
        break;
      case 'null':
        _nullType = true;
      case final String name:
        _type = APIType.fromJson(name);
      case final List<Object?> names:
        _typeIsList = true;
        final types = <APIType>[];
        for (final name in names) {
          if (name == 'null') {
            _nullType = true;
          } else if (name is String) {
            final type = APIType.fromJson(name);
            if (type != null) {
              types.add(type);
            }
          } else {
            throw OpenApiFormatException(
              'Schema type must be a string or an array of strings.',
              pointer: object.pointerTo('type'),
              source: names,
            );
          }
        }
        _types = List.unmodifiable(types);
        _type = types.length == 1 ? types.single : null;
      case final other:
        throw OpenApiFormatException(
          'Schema type must be a string or an array of strings.',
          pointer: object.pointerTo('type'),
          source: other,
        );
    }
  }

  /// Reads `exclusiveMaximum`/`exclusiveMinimum`, a flag in OpenAPI 3.0 and
  /// a number in 3.1.
  static (bool?, num?) _exclusiveLimit(KeyedArchive object, String key) =>
      switch (object.decode<Object?>(key)) {
        null => (null, null),
        final bool flag => (flag, null),
        final num limit => (null, limit),
        final other => throw OpenApiFormatException(
          '$key must be a boolean (OpenAPI 3.0) or a number (3.1).',
          pointer: object.pointerTo(key),
          source: other,
        ),
      };
}
