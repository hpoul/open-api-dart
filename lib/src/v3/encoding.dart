import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/header.dart';
import 'package:open_api_forked/src/v3/parameter.dart';

/// A single encoding definition applied to a single schema property.
final class APIEncoding extends APIObject {
  APIEncoding({
    this.contentType,
    Map<String, APIHeader>? headers,
    this.style,
    this.allowReserved,
    this.explode,
  }) : headers = headers ?? {};

  APIEncoding.empty();

  /// The Content-Type for encoding a specific property.
  ///
  /// Default value depends on the property type: for string with format being binary – application/octet-stream; for other primitive types – text/plain; for object - application/json; for array – the default is defined based on the inner type. The value can be a specific media type (e.g. application/json), a wildcard media type (e.g. image/*), or a comma-separated list of the two types.
  String? contentType;

  /// A map allowing additional information to be provided as headers, for example Content-Disposition.
  ///
  /// Content-Type is described separately and SHALL be ignored in this section. This property SHALL be ignored if the request body media type is not a multipart.
  Map<String, APIHeader> headers = {};

  /// Determines whether the parameter value SHOULD allow reserved characters, as defined by RFC3986 :/?#[]@!$&'()*+,;= to be included without percent-encoding.
  ///
  /// The default value is false. This property SHALL be ignored if the request body media type is not application/x-www-form-urlencoded.
  ///
  /// `null` means not given; see [effectiveAllowReserved].
  bool? allowReserved;

  /// When this is true, property values of type array or object generate separate parameters for each value of the array, or key-value-pair of the map.
  ///
  /// For other types of properties this property has no effect. When style is form, the default value is true. For all other styles, the default value is false. This property SHALL be ignored if the request body media type is not application/x-www-form-urlencoded.
  ///
  /// `null` means not given; see [effectiveExplode].
  bool? explode;

  /// Describes how a specific property value will be serialized depending on its type.
  ///
  /// See [APIParameter] for details on the style property. The behavior follows the same values as query parameters, including default values. This property SHALL be ignored if the request body media type is not application/x-www-form-urlencoded.
  ///
  /// `null` means not given; see [effectiveStyle].
  String? style;

  /// [style], or its default, `form` (as for query parameters).
  ///
  /// Like [effectiveExplode] and [effectiveAllowReserved], this only applies
  /// when the request body is `application/x-www-form-urlencoded`;
  /// otherwise [contentType] governs.
  String get effectiveStyle => style ?? 'form';

  /// [explode], or its default: true when [effectiveStyle] is `form`.
  bool get effectiveExplode => explode ?? effectiveStyle == 'form';

  /// [allowReserved], or its default, false.
  bool get effectiveAllowReserved => allowReserved ?? false;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    contentType = object.decode('contentType');
    headers = object.decodeObjectMap('headers', () => APIHeader()) ?? {};
    allowReserved = object.decode('allowReserved');
    explode = object.decode('explode');
    style = object.decode('style');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('contentType', contentType);
    object.encodeObjectMap('headers', headers, omitEmpty: true);
    object.encode('allowReserved', allowReserved);
    object.encode('explode', explode);
    object.encode('style', style);
  }
}
