import 'package:open_api_forked/src/exception.dart';
import 'package:open_api_forked/v3.dart';

/// Checks [document] for missing REQUIRED fields and similar rule
/// violations that decoding tolerates, and returns one
/// [OpenApiFormatException] per problem, in document order.
List<OpenApiFormatException> validateDocument(APIDocument document) {
  final v = _Validator();
  v.document(document);
  return v.issues;
}

final RegExp _componentKey = RegExp(r'^[a-zA-Z0-9.\-_]+$');

final class _Validator {
  final issues = <OpenApiFormatException>[];

  /// Security scheme names declared in components, for checking
  /// requirements. Null if the document has no components.
  Set<String>? _schemes;

  void _issue(String pointer, String message) =>
      issues.add(OpenApiFormatException(message, pointer: pointer));

  void _required(String pointer, String key, Object? value) {
    if (value == null) {
      _issue(appendPointer(pointer, key), "Missing required field '$key'.");
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
    _schemes = d.components?.securitySchemes.keys.toSet();
    _servers(p, d.servers);
    _each(appendPointer(p, 'paths'), d.paths, _path);
    final components = d.components;
    if (components != null) {
      _components(appendPointer(p, 'components'), components);
    }
    _security(p, d.security);
    for (final (i, tag) in d.tags.indexed) {
      _required(appendPointer(appendPointer(p, 'tags'), i), 'name', tag.name);
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
    void Function(String, T) check,
  ) {
    map.forEach((key, value) {
      if (!_isRef(value)) {
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
    _eachIndexed(appendPointer(p, 'servers'), servers, (p, server) {
      _required(p, 'url', server.url);
      _each(appendPointer(p, 'variables'), server.variables, (p, variable) {
        _required(p, 'default', variable.defaultValue);
      });
    });
  }

  void _security(String p, List<APISecurityRequirement>? security) {
    final schemes = _schemes;
    if (security == null) {
      return;
    }
    for (final (i, requirement) in security.indexed) {
      for (final name in requirement.requirements.keys) {
        if (schemes == null || !schemes.contains(name)) {
          _issue(
            appendPointer(appendPointer(appendPointer(p, 'security'), i), name),
            "Security requirement '$name' names no security scheme in "
            'components.',
          );
        }
      }
    }
  }

  void _path(String p, APIPath path) {
    _parameters(p, path.parameters);
    _each(p, path.operations, _operation);
  }

  void _parameters(String p, List<APIParameter> parameters) {
    _eachIndexed(appendPointer(p, 'parameters'), parameters, _parameter);
  }

  void _parameter(String p, APIParameter parameter) {
    _required(p, 'name', parameter.name);
    _required(p, 'in', parameter.location);
    _content(p, parameter.content);
  }

  void _operation(String p, APIOperation operation) {
    _parameters(p, operation.parameters);
    final body = operation.requestBody;
    if (body != null && !_isRef(body)) {
      _requestBody(appendPointer(p, 'requestBody'), body);
    }
    if (operation.responses.isEmpty) {
      _issue(
        appendPointer(p, 'responses'),
        'An operation must have at least one response.',
      );
    }
    _each(appendPointer(p, 'responses'), operation.responses, _response);
    _each(appendPointer(p, 'callbacks'), operation.callbacks, _callback);
    _security(p, operation.security);
    _servers(p, operation.servers);
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
  }

  void _header(String p, APIHeader header) => _content(p, header.content);

  void _content(String p, Map<String, APIMediaType> content) {
    _each(appendPointer(p, 'content'), content, (p, mediaType) {
      _each(appendPointer(p, 'encoding'), mediaType.encoding, (p, encoding) {
        _each(appendPointer(p, 'headers'), encoding.headers, _header);
      });
    });
  }

  void _callback(String p, APICallback callback) =>
      _each(p, callback.paths, _path);

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

    _each(appendPointer(p, 'responses'), c.responses, _response);
    _each(appendPointer(p, 'parameters'), c.parameters, _parameter);
    _each(appendPointer(p, 'requestBodies'), c.requestBodies, _requestBody);
    _each(appendPointer(p, 'headers'), c.headers, _header);
    _each(appendPointer(p, 'securitySchemes'), c.securitySchemes, _scheme);
    _each(appendPointer(p, 'callbacks'), c.callbacks, _callback);
  }

  void _scheme(String p, APISecurityScheme scheme) {
    switch (scheme.type) {
      case null:
        _required(p, 'type', null);
      case APISecuritySchemeType.apiKey:
        _required(p, 'name', scheme.name);
        _required(p, 'in', scheme.location);
      case APISecuritySchemeType.http:
        _required(p, 'scheme', scheme.scheme);
      case APISecuritySchemeType.oauth2:
        if (scheme.flows.isEmpty) {
          _issue(appendPointer(p, 'flows'), "Missing required field 'flows'.");
        }
        _each(appendPointer(p, 'flows'), scheme.flows, (p, flow) {
          final name = p.substring(p.lastIndexOf('/') + 1);
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
