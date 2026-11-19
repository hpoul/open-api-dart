import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/media_type.dart';
import 'package:open_api_forked/src/v3/schema.dart';

/// A [Header Object](https://spec.openapis.org/oas/v3.0.3#header-object).
///
/// It follows the structure of a parameter, except that `name` is the key in
/// the headers map that holds it, and `in` is implicitly `header`.
class APIHeader extends APIObject {
  APIHeader({
    this.description,
    this.schema,
    this.content,
    this.style,
    this.explode,
    bool? isRequired,
    bool? isDeprecated,
  }) : _required = isRequired,
       _deprecated = isDeprecated;

  APIHeader.empty();

  /// A brief description of the header.
  ///
  /// CommonMark syntax MAY be used for rich text representation.
  String? description;

  /// Whether the header is mandatory. Defaults to false.
  bool get isRequired => _required ?? false;
  set isRequired(bool? value) => _required = value;
  bool? _required;

  /// Whether the header is deprecated. Defaults to false.
  bool get isDeprecated => _deprecated ?? false;
  set isDeprecated(bool? value) => _deprecated = value;
  bool? _deprecated;

  /// How the header value is serialized. The default for headers is
  /// `simple`.
  String? style;

  bool? explode;

  /// The schema defining the type of the header.
  APISchemaObject? schema;

  /// A map with a single media type describing the header, as an
  /// alternative to [schema].
  Map<String, APIMediaType?>? content;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    description = object.decode('description');
    _required = object.decode('required');
    _deprecated = object.decode('deprecated');
    style = object.decode('style');
    explode = object.decode('explode');
    schema = object.decodeObject('schema', () => APISchemaObject());
    content = object.decodeObjectMap('content', () => APIMediaType());
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('description', description);
    object.encode('required', _required);
    object.encode('deprecated', _deprecated);
    object.encode('style', style);
    object.encode('explode', explode);
    object.encodeObject('schema', schema);
    object.encodeObjectMap('content', content);
  }
}
