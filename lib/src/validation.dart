import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/v3.dart';

/// Checks [document] for missing REQUIRED fields and broken MUST rules that
/// decoding tolerates, and returns one [OpenApiFormatException] per
/// problem, in document order.
List<OpenApiFormatException> validateDocument(APIDocument document) {
  final v = _Validator();
  v.document(document);
  return v.issues;
}

final RegExp _componentKey = RegExp(r'^[a-zA-Z0-9.\-_]+$');
final RegExp _responseKey = RegExp(r'^(default|[1-5]([0-9]{2}|XX))$');
final RegExp _templateParameter = RegExp(r'\{([^{}]+)\}');
const _flowNames = {
  'implicit',
  'password',
  'clientCredentials',
  'authorizationCode',
};

final class _Validator {
  final issues = <OpenApiFormatException>[];

  /// Security schemes declared in components, by name, for checking
  /// requirements. Null if the document has no components.
  Map<String, APISecuritySchemeType?>? _schemes;

  /// Pointer of the first operation with each operationId.
  final _operationIds = <String, String>{};

  void _issue(String pointer, String message) =>
      issues.add(OpenApiFormatException(message, pointer: pointer));

  void _required(String pointer, String key, Object? value) {
    if (value == null) {
      _issue(appendPointer(pointer, key), "Missing required field '$key'.");
    }
  }

  /// Like [_required], for a field decoded from a fixed set of values, where
  /// null also means the value was not one of them.
  void _requiredEnum(String pointer, String key, Object? value) {
    if (value == null) {
      _issue(
        appendPointer(pointer, key),
        "Missing or invalid required field '$key'.",
      );
    }
  }

  /// Whether [object] is a `$ref`. A reference is checked at its target.
  bool _isRef(APIObject object) => object.referenceURI != null;

  void document(APIDocument d) {
    const p = '#';
    _required(p, 'openapi', d.version);
    _required(p, 'info', d.info);
    final info = d.info;
    if (info != null) {
      _info(appendPointer(p, 'info'), info);
    }
    _schemes = d.components?.securitySchemes.map(
      (name, scheme) => MapEntry(name, scheme.type),
    );
    _servers(p, d.servers);
    final paths = appendPointer(p, 'paths');
    d.paths.forEach((key, path) {
      if (key.startsWith('x-')) {
        return;
      }
      final pp = appendPointer(paths, key);
      if (!key.startsWith('/')) {
        _issue(pp, "Path '$key' must begin with '/'.");
      }
      if (!_isRef(path)) {
        _path(pp, path, template: key);
      }
    });
    final components = d.components;
    if (components != null) {
      _components(appendPointer(p, 'components'), components);
    }
    _security(p, d.security);
    _externalDocs(p, d.externalDocs);
    final tagNames = <String>{};
    for (final (i, tag) in d.tags.indexed) {
      final tp = appendPointer(appendPointer(p, 'tags'), i);
      _required(tp, 'name', tag.name);
      _externalDocs(tp, tag.externalDocs);
      final name = tag.name;
      if (name != null && !tagNames.add(name)) {
        _issue(appendPointer(tp, 'name'), "Duplicate tag name '$name'.");
      }
    }
  }

  void _info(String p, APIInfo info) {
    _required(p, 'title', info.title);
    _required(p, 'version', info.version);
    final license = info.license;
    if (license != null) {
      _required(appendPointer(p, 'license'), 'name', license.name);
    }
  }

  void _each<T extends APIObject>(
    String p,
    Map<String, T> map,
    void Function(String, T) check, {
    bool skipExtensions = false,
  }) {
    map.forEach((key, value) {
      if (!_isRef(value) && !(skipExtensions && key.startsWith('x-'))) {
        check(appendPointer(p, key), value);
      }
    });
  }

  void _eachIndexed<T extends APIObject>(
    String p,
    List<T> list,
    void Function(String, T) check,
  ) {
    for (final (i, value) in list.indexed) {
      if (!_isRef(value)) {
        check(appendPointer(p, i), value);
      }
    }
  }

  void _servers(String p, List<APIServerDescription>? servers) {
    if (servers == null) {
      return;
    }
    _eachIndexed(appendPointer(p, 'servers'), servers, _server);
  }

  void _server(String p, APIServerDescription server) {
    _required(p, 'url', server.url);
    _each(appendPointer(p, 'variables'), server.variables, (p, variable) {
      _required(p, 'default', variable.defaultValue);
    });
  }

  void _security(String p, List<APISecurityRequirement>? security) {
    final schemes = _schemes;
    if (security == null) {
      return;
    }
    for (final (i, requirement) in security.indexed) {
      requirement.requirements.forEach((name, scopes) {
        final rp = appendPointer(
          appendPointer(appendPointer(p, 'security'), i),
          name,
        );
        if (schemes == null || !schemes.containsKey(name)) {
          _issue(
            rp,
            "Security requirement '$name' names no security scheme in "
            'components.',
          );
          return;
        }
        final type = schemes[name];
        if (scopes.isNotEmpty &&
            type != APISecuritySchemeType.oauth2 &&
            type != APISecuritySchemeType.openIdConnect) {
          _issue(
            rp,
            "Security requirement '$name' must have no scopes, because "
            'its scheme is not oauth2 or openIdConnect.',
          );
        }
      });
    }
  }

  /// Checks a path item. [template] is its key in `paths`, whose
  /// `{parameters}` must be declared; callback path items have runtime
  /// expressions instead and pass null.
  void _path(String p, APIPath path, {String? template}) {
    _parameters(p, path.parameters);
    path.operations.forEach((method, operation) {
      if (_isRef(operation)) {
        return;
      }
      final op = appendPointer(p, method);
      _operation(op, operation);
      if (template != null) {
        _template(op, template, [...path.parameters, ...operation.parameters]);
      }
    });
  }

  /// Checks that the `{names}` in [template] and the path parameters in
  /// [parameters] match one to one.
  void _template(String p, String template, List<APIParameter> parameters) {
    final names = {
      for (final m in _templateParameter.allMatches(template)) m[1]!,
    };
    final declared = {
      for (final APIParameter(:location, :name) in parameters)
        if (location == APIParameterLocation.path && name != null) name,
    };
    for (final name in names.difference(declared)) {
      _issue(
        appendPointer(p, 'parameters'),
        "Path parameter '$name' in '$template' is not declared.",
      );
    }
    for (final name in declared.difference(names)) {
      _issue(
        appendPointer(p, 'parameters'),
        "Path parameter '$name' does not appear in '$template'.",
      );
    }
  }

  void _parameters(String p, List<APIParameter> parameters) {
    final lp = appendPointer(p, 'parameters');
    _eachIndexed(lp, parameters, _parameter);
    final seen = <(String?, APIParameterLocation?)>{};
    for (final (i, parameter) in parameters.indexed) {
      final key = (parameter.name, parameter.location);
      if (parameter.name != null &&
          parameter.location != null &&
          !seen.add(key)) {
        _issue(
          appendPointer(lp, i),
          "Duplicate parameter '${parameter.name}' in "
          "'${parameter.location!.jsonValue}'.",
        );
      }
    }
  }

  void _parameter(String p, APIParameter parameter) {
    _required(p, 'name', parameter.name);
    _requiredEnum(p, 'in', parameter.location);
    final hasSchema = parameter.schema != null;
    final hasContent = parameter.content.isNotEmpty;
    if (hasSchema == hasContent) {
      _issue(p, "A parameter must have exactly one of 'schema' and 'content'.");
    }
    if (parameter.content.length > 1) {
      _issue(
        appendPointer(p, 'content'),
        "A parameter's 'content' must have exactly one entry.",
      );
    }
    _content(p, parameter.content);
    _examples(p, parameter.example, parameter.examples);
  }

  void _operation(String p, APIOperation operation) {
    final id = operation.id;
    if (id != null) {
      final first = _operationIds[id];
      if (first == null) {
        _operationIds[id] = p;
      } else {
        _issue(
          appendPointer(p, 'operationId'),
          "Duplicate operationId '$id', also used at $first.",
        );
      }
    }
    _parameters(p, operation.parameters);
    final body = operation.requestBody;
    if (body != null && !_isRef(body)) {
      _requestBody(appendPointer(p, 'requestBody'), body);
    }
    final rp = appendPointer(p, 'responses');
    if (operation.responses.keys.every((key) => key.startsWith('x-'))) {
      _issue(rp, 'An operation must have at least one response.');
    }
    for (final key in operation.responses.keys) {
      if (!key.startsWith('x-') && !_responseKey.hasMatch(key)) {
        _issue(
          appendPointer(rp, key),
          "Response key '$key' must be 'default', a status code or a range "
          "like '2XX'.",
        );
      }
    }
    _each(rp, operation.responses, _response, skipExtensions: true);
    _each(appendPointer(p, 'callbacks'), operation.callbacks, _callback);
    _security(p, operation.security);
    _servers(p, operation.servers);
    _externalDocs(p, operation.externalDocs);
  }

  void _externalDocs(String p, APIExternalDocumentation? docs) {
    if (docs != null && !_isRef(docs)) {
      _required(appendPointer(p, 'externalDocs'), 'url', docs.url);
    }
  }

  /// Checks `example`/`examples` of a parameter, header or media type.
  void _examples(String p, Object? example, Map<String, APIExample> examples) {
    if (example != null && examples.isNotEmpty) {
      _issue(p, "'example' and 'examples' are mutually exclusive.");
    }
    _each(appendPointer(p, 'examples'), examples, _example);
  }

  void _example(String p, APIExample example) {
    if (example.value != null && example.externalValue != null) {
      _issue(p, "'value' and 'externalValue' are mutually exclusive.");
    }
  }

  void _link(String p, APILink link) {
    if ((link.operationRef == null) == (link.operationId == null)) {
      _issue(
        p,
        "A link must have exactly one of 'operationRef' and 'operationId'.",
      );
    }
    final server = link.server;
    if (server != null && !_isRef(server)) {
      _server(appendPointer(p, 'server'), server);
    }
  }

  void _requestBody(String p, APIRequestBody body) {
    if (body.content.isEmpty) {
      _issue(appendPointer(p, 'content'), "Missing required field 'content'.");
    }
    _content(p, body.content);
  }

  void _response(String p, APIResponse response) {
    _required(p, 'description', response.description);
    _each(appendPointer(p, 'headers'), response.headers, _header);
    _content(p, response.content);
    _each(appendPointer(p, 'links'), response.links, _link);
  }

  void _header(String p, APIHeader header) {
    _content(p, header.content);
    _examples(p, header.example, header.examples);
  }

  void _content(String p, Map<String, APIMediaType> content) {
    _each(appendPointer(p, 'content'), content, (p, mediaType) {
      _examples(p, mediaType.example, mediaType.examples);
      _each(appendPointer(p, 'encoding'), mediaType.encoding, (p, encoding) {
        _each(appendPointer(p, 'headers'), encoding.headers, _header);
      });
    });
  }

  void _callback(String p, APICallback callback) =>
      _each(p, callback.paths, _path, skipExtensions: true);

  void _components(String p, APIComponents c) {
    void keys(String type, Map<String, APIObject> map) {
      for (final key in map.keys) {
        if (!_componentKey.hasMatch(key)) {
          _issue(
            appendPointer(appendPointer(p, type), key),
            "Component name '$key' must match ^[a-zA-Z0-9.\\-_]+\$.",
          );
        }
      }
    }

    keys('schemas', c.schemas);
    keys('responses', c.responses);
    keys('parameters', c.parameters);
    keys('requestBodies', c.requestBodies);
    keys('headers', c.headers);
    keys('securitySchemes', c.securitySchemes);
    keys('callbacks', c.callbacks);
    keys('examples', c.examples);
    keys('links', c.links);

    _each(appendPointer(p, 'responses'), c.responses, _response);
    _each(appendPointer(p, 'parameters'), c.parameters, _parameter);
    _each(appendPointer(p, 'requestBodies'), c.requestBodies, _requestBody);
    _each(appendPointer(p, 'headers'), c.headers, _header);
    _each(appendPointer(p, 'securitySchemes'), c.securitySchemes, _scheme);
    _each(appendPointer(p, 'callbacks'), c.callbacks, _callback);
    _each(appendPointer(p, 'examples'), c.examples, _example);
    _each(appendPointer(p, 'links'), c.links, _link);
  }

  void _scheme(String p, APISecurityScheme scheme) {
    switch (scheme.type) {
      case null:
        _requiredEnum(p, 'type', null);
      case APISecuritySchemeType.apiKey:
        _required(p, 'name', scheme.name);
        _requiredEnum(p, 'in', scheme.location);
        if (scheme.location == APIParameterLocation.path) {
          _issue(
            appendPointer(p, 'in'),
            "An apiKey must be in 'query', 'header' or 'cookie'.",
          );
        }
      case APISecuritySchemeType.http:
        _required(p, 'scheme', scheme.scheme);
      case APISecuritySchemeType.oauth2:
        final fp = appendPointer(p, 'flows');
        if (scheme.flows.keys.every((name) => name.startsWith('x-'))) {
          _issue(fp, "Missing required field 'flows'.");
        }
        scheme.flows.forEach((name, flow) {
          if (name.startsWith('x-')) {
            return;
          }
          final p = appendPointer(fp, name);
          if (!_flowNames.contains(name)) {
            _issue(
              p,
              "Unknown OAuth2 flow '$name'; expected one of "
              '${_flowNames.join(', ')}.',
            );
            return;
          }
          if (name == 'implicit' || name == 'authorizationCode') {
            _required(p, 'authorizationUrl', flow.authorizationURL);
          }
          if (name != 'implicit') {
            _required(p, 'tokenUrl', flow.tokenURL);
          }
        });
      case APISecuritySchemeType.openIdConnect:
        _required(p, 'openIdConnectUrl', scheme.connectURL);
    }
  }
}
