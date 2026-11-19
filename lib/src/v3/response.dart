import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/header.dart';
import 'package:open_api_forked/src/v3/media_type.dart';
import 'package:open_api_forked/src/v3/schema.dart';

/// Describes a single response from an API Operation, including design-time, static links to operations based on the response.
final class APIResponse extends APIObject {
  APIResponse.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'description': description,
    'content': content,
  };
  APIResponse(
    this.description, {
    Map<String, APIMediaType>? content,
    Map<String, APIHeader>? headers,
  }) : content = content ?? {},
       headers = headers ?? {};
  APIResponse.schema(
    this.description,
    APISchemaObject schema, {
    Iterable<String> contentTypes = const ['application/json'],
    Map<String, APIHeader>? headers,
  }) : headers = headers ?? {} {
    content = contentTypes.fold<Map<String, APIMediaType>>({}, (prev, elem) {
      prev[elem] = APIMediaType(schema: schema);
      return prev;
    });
  }

  /// A short description of the response.
  ///
  /// REQUIRED. CommonMark syntax MAY be used for rich text representation.
  String? description;

  /// Maps a header name to its definition.
  ///
  /// RFC7230 states header names are case insensitive. If a response header is defined with the name "Content-Type", it SHALL be ignored.
  Map<String, APIHeader> headers = {};

  /// A map containing descriptions of potential response payloads.
  ///
  /// The key is a media type or media type range and the value describes it. For responses that match multiple keys, only the most specific key is applicable. e.g. text/plain overrides text/*
  Map<String, APIMediaType> content = {};

  // Currently missing:
  // links

  /// Adds a [header] to [headers] for [name].
  ///
  /// If the key does not exist in [headers], [header] is added for the key.
  /// If the key exists, [header] is not added. (To replace a header, access [headers] directly.)
  void addHeader(String name, APIHeader header) {
    if (!headers.containsKey(name)) {
      headers[name] = header;
    }
  }

  /// Adds a [bodyObject] to [content] for a content-type.
  ///
  /// [contentType] must take the form 'primaryType/subType', e.g. 'application/json'. Do not include charsets.
  ///
  /// If [contentType] does not exist in [content], [bodyObject] is added for [contentType].
  /// If [contentType] exists, the [bodyObject] is added the list of possible schemas that were previously added.
  void addContent(String contentType, APISchemaObject? bodyObject) {
    final key = contentType;
    final existingContent = content[key];
    if (existingContent == null) {
      content[key] = APIMediaType(schema: bodyObject);
      return;
    }

    if (bodyObject == null) {
      return;
    }
    final schema = existingContent.schema;
    if (schema == null) {
      existingContent.schema = bodyObject;
    } else if (schema.oneOf.isNotEmpty) {
      schema.oneOf.add(bodyObject);
    } else {
      existingContent.schema = APISchemaObject()..oneOf = [schema, bodyObject];
    }
  }

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    description = object.decode('description');
    content = object.decodeObjectMap('content', () => APIMediaType()) ?? {};
    headers = object.decodeObjectMap('headers', () => APIHeader()) ?? {};
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    if (description == null) {
      throw ArgumentError(
        "APIResponse must have non-null values for: 'description'.",
      );
    }

    object.encode('description', description);
    object.encodeObjectMap('headers', headers, omitEmpty: true);
    object.encodeObjectMap('content', content, omitEmpty: true);
  }
}
