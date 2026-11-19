import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  group("Components and resolution", () {
    test("Can resolve object against registry", () {
      final components = APIComponents();
      components.schemas!["foo"] = APISchemaObject.string();

      final ref = APISchemaObject()
        ..referenceURI = Uri.parse("/components/schemas/foo");
      final orig = components.resolve(ref);
      expect(orig!.type, APIType.string);
      expect(ref.type, isNull);

      final APISchemaObject constructed = components
          .resolveUri(Uri(path: "/components/schemas/foo")) as APISchemaObject;
      expect(constructed.type, APIType.string);
    });

    test("Invalid ref uri format throws error", () {
      final components = APIComponents();
      try {
        components.resolve(APISchemaObject()
          ..referenceURI = Uri.parse("#/components/schemas/foo"));
        expect(true, false);
      } on ArgumentError catch (e) {
        expect(e.message, contains("Invalid reference URI"));
      }

      try {
        components.resolve(APISchemaObject()
          ..referenceURI = Uri.parse("#/components/schemas"));
        expect(true, false);
      } on ArgumentError catch (e) {
        expect(e.message, contains("Invalid reference URI"));
      }

      try {
        components.resolve(APISchemaObject()
          ..referenceURI = Uri.parse("/components/foobar/foo"));
        expect(true, false);
      } on ArgumentError catch (e) {
        expect(e.message, contains("Invalid reference URI"));
      }
    });

    test("Nonexisting component returns null", () {
      APIComponents? components = APIComponents();
      expect(
          components.resolve(APISchemaObject()
            ..referenceURI = Uri.parse("/components/schemas/foo")),
          isNull);
    });

    test("URIs are paths internally, but fragments when serialized", () {
      final doc = APIDocument.fromMap({
        "openapi": "3.0.0",
        "info": {"title": "x", "version": "1"},
        "paths": <String, dynamic>{},
        "components": {
          "schemas": {
            "string": {
              "type": "string",
            },
            "container": {"\$ref": "#/components/schemas/string"}
          }
        }
      });

      expect(doc.components!.schemas!["container"]!.referenceURI!.path,
          "/components/schemas/string");

      doc.components!.schemas!["other"] = APISchemaObject()
        ..referenceURI = Uri(path: "/components/schemas/container");

      final out = doc.asMap();
      expect(out["components"]["schemas"]["container"][r"$ref"],
          "#/components/schemas/string");
      expect(out["components"]["schemas"]["other"][r"$ref"],
          "#/components/schemas/container");
    });
  });

  group("Stripe spec", () {
    APIDocument? doc;
    Map<String, dynamic>? original;

    setUpAll(() {
      // Spec file is too large for pub, and no other way to remove from pub publish
      // than putting in .gitignore. Therefore, this file must be downloaded locally
      // to this path, from this path: https://raw.githubusercontent.com/stripe/openapi/master/openapi/spec3.json
      var file = File("test/specs/stripe.json");
      var contents = file.readAsStringSync();
      original = json.decode(contents);
      doc = APIDocument.fromMap(original!);
    });

    test("Emits same document in asMap()", () {
      expect(doc!.asMap(), original);
    });

    test("Has openapi version", () {
      expect(doc!.version, "3.0.0");
    });

    test("Has info", () {
      expect(doc!.info!.title, "Stripe API");
      expect(doc!.info!.version, isNotNull);
      expect(doc!.info!.description,
          "The Stripe REST API. Please see https://stripe.com/docs/api for more details.");
      expect(doc!.info!.termsOfServiceURL.toString(),
          "https://stripe.com/us/terms/");
      expect(doc!.info!.contact!.email, "dev-platform@stripe.com");
      expect(doc!.info!.contact!.name, "Stripe Dev Platform Team");
      expect(doc!.info!.contact!.url.toString(), "https://stripe.com");
      expect(doc!.info!.license, isNull);
    });

    test("Has servers", () {
      expect(doc!.servers!.length, 1);
      expect(doc!.servers!.first!.url.toString(), "https://api.stripe.com/");
      expect(doc!.servers!.first!.description, isNull);
      expect(doc!.servers!.first!.variables, isNull);
    });

    test("Tags", () {
      expect(doc!.tags, isNull);
    });

    group("Paths", () {
      test("Sample path 1", () {
        final p = doc!.paths!["/v1/transfers/{transfer}/reversals/{id}"];
        expect(p, isNotNull);
        expect(p!.description, isNull);

        expect(p.operations.length, 2);

        final getOp = p.operations["get"];
        final getParams = getOp!.parameters;
        final getResponses = getOp.responses;
        expect(getOp.description, contains("10 most recent reversals"));
        expect(getOp.id, "TransferReversalRetrieve");
        expect(getParams!.length, 3);
        expect(getParams[0]!.location, APIParameterLocation.query);
        expect(getParams[0]!.description,
            "Specifies which fields in the response should be expanded.");
        expect(getParams[0]!.name, "expand");
        expect(getParams[0]!.isRequired, false);
        expect(getParams[0]!.schema!.type, APIType.array);
        expect(getParams[0]!.schema!.items!.type, APIType.string);

        expect(getParams[1]!.location, APIParameterLocation.path);
        expect(getParams[1]!.name, "id");
        expect(getParams[1]!.isRequired, true);
        expect(getParams[1]!.schema!.type, APIType.string);

        expect(getParams[2]!.location, APIParameterLocation.path);
        expect(getParams[2]!.name, "transfer");
        expect(getParams[2]!.isRequired, true);
        expect(getParams[2]!.schema!.type, APIType.string);

        expect(getResponses!.length, 2);
        expect(getResponses["200"]!.content!.length, 1);
        expect(
            getResponses["200"]!
                .content!["application/json"]!
                .schema!
                .referenceURI,
            Uri.parse(
                Uri.parse("#/components/schemas/transfer_reversal").fragment));

        final resolvedElement = getResponses["200"]!
            .content!["application/json"]!
            .schema!
            .properties!["balance_transaction"]!
            .anyOf;
        expect(resolvedElement!.last!.properties!["amount"]!.type,
            APIType.integer);
      });
    });

    group("Components", () {});

    test("Security requirement", () {
      expect(doc!.security, isNull);
    });
  });

  group("Security", () {
    test("Can parse security requirements", () {
      final doc = new APIDocument.fromMap({
        "openapi": "3.0.0",
        "info": {"title": "x", "version": "1"},
        "paths": <String, dynamic>{
          "/foo": {
            "get": {
              "summary": "Lorem Ipsum",
              "security": [
                {
                  "test": [],
                }
              ],
            },
          },
        },
      });
      expect(doc.paths!.values.first!.operations.values.first?.security,
          hasLength(1));
    });
  });

  group("Schema", () {
    test("Can read/emit schema object with additionalProperties=true", () {
      final doc = APIDocument.fromMap({
        "openapi": "3.0.0",
        "info": {"title": "x", "version": "1"},
        "paths": <String, dynamic>{},
        "components": {
          "schemas": {
            "freeform": {"type": "object", "additionalProperties": true}
          }
        }
      });

      expect(doc.components!.schemas!["freeform"]!.additionalPropertyPolicy,
          APISchemaAdditionalPropertyPolicy.freeForm);

      expect(
          doc.asMap()["components"]["schemas"]["freeform"]["type"], "object");
      expect(
          doc.asMap()["components"]["schemas"]["freeform"]
              ["additionalProperties"],
          true);
    });

    test("Can read/emit schema object with additionalProperties={}", () {
      final doc = APIDocument.fromMap({
        "openapi": "3.0.0",
        "info": {"title": "x", "version": "1"},
        "paths": <String, dynamic>{},
        "components": {
          "schemas": {
            "freeform": {
              "type": "object",
              "additionalProperties": <String, dynamic>{}
            }
          }
        }
      });
      expect(doc.components!.schemas!["freeform"]!.additionalPropertyPolicy,
          APISchemaAdditionalPropertyPolicy.freeForm);
      expect(
          doc.asMap()["components"]["schemas"]["freeform"]["type"], "object");
      expect(
          doc.asMap()["components"]["schemas"]["freeform"]
              ["additionalProperties"],
          true);
    });
  });

  group("Callbacks", () {
    final spec = {
      "openapi": "3.0.0",
      "info": {"title": "x", "version": "1"},
      "paths": {
        "/subscribe": {
          "post": {
            "responses": {
              "201": {"description": "ok"}
            },
            "callbacks": {
              "onEvent": {
                "x-note": "extension",
                r"{$request.body#/callbackUrl}": {
                  "post": {
                    "responses": {
                      "200": {"description": "ok"}
                    }
                  }
                }
              }
            }
          }
        }
      }
    };

    test("Can decode operation callbacks", () {
      final doc = APIDocument.fromMap(spec);
      final callback =
          doc.paths!["/subscribe"]!.operations["post"]!.callbacks!["onEvent"]!;
      expect(callback.paths.keys, [r"{$request.body#/callbackUrl}"]);
      expect(callback.paths.values.single.operations["post"]!.responses!["200"],
          isNotNull);
      expect(callback.extensions, {"x-note": "extension"});
    });

    test("Callbacks survive an encode/decode round trip", () {
      final encoded = APIDocument.fromMap(spec).asMap();
      final callback = encoded["paths"]["/subscribe"]["post"]["callbacks"]
          ["onEvent"] as Map;
      expect(callback["x-note"], "extension");
      expect(
          callback[r"{$request.body#/callbackUrl}"]["post"]["responses"]["200"]
              ["description"],
          "ok");
      expect(APIDocument.fromMap(encoded).asMap(), encoded);
    });
  });

  test("Callback given as \$ref resolves through components", () {
    // Like other referenced objects, a referenced callback only carries its
    // referenceURI; its paths come from `components.resolve`.
    final doc = APIDocument.fromMap({
      "openapi": "3.0.0",
      "info": {"title": "x", "version": "1"},
      "paths": {
        "/subscribe": {
          "post": {
            "responses": {
              "201": {"description": "ok"}
            },
            "callbacks": {
              "onEvent": {r"$ref": "#/components/callbacks/Event"}
            }
          }
        }
      },
      "components": {
        "callbacks": {
          "Event": {
            "{\$request.body#/url}": {
              "post": {
                "responses": {
                  "200": {"description": "ok"}
                }
              }
            }
          }
        }
      }
    });
    final ref =
        doc.paths!["/subscribe"]!.operations["post"]!.callbacks!["onEvent"]!;
    expect(ref.referenceURI, Uri(path: "/components/callbacks/Event"));
    final resolved = doc.components!.resolve(ref)!;
    expect(resolved.paths.keys, [r"{$request.body#/url}"]);
    final encoded = doc.asMap();
    expect(encoded["paths"]["/subscribe"]["post"]["callbacks"]["onEvent"],
        {r"$ref": "#/components/callbacks/Event"});
  });

  group("More crash regressions", () {
    // Round trip through JSON so collections are typed like a parsed file.
    Map<String, dynamic> minimal([Map<String, dynamic> extra = const {}]) =>
        json.decode(json.encode({
          "openapi": "3.0.0",
          "info": {"title": "x", "version": "1"},
          "paths": <String, dynamic>{},
          ...extra,
        })) as Map<String, dynamic>;

    test("Document-level security encodes to JSON", () {
      final doc = APIDocument.fromMap(minimal({
        "security": [
          {"bearer": <String>[]},
          {
            "oauth": ["read", "write"]
          }
        ],
        "components": {
          "securitySchemes": {
            "bearer": {"type": "http", "scheme": "bearer"}
          }
        }
      }));
      final encoded = json.decode(json.encode(doc.asMap())) as Map;
      expect(encoded["security"], [
        {"bearer": []},
        {
          "oauth": ["read", "write"]
        }
      ]);
    });

    test("Empty document-level security stays distinct from absent", () {
      expect(APIDocument.fromMap(minimal({"security": []})).security, isEmpty);
      expect(APIDocument.fromMap(minimal()).security, isNull);
      expect(
          APIDocument.fromMap(minimal({"security": []})).asMap()["security"],
          isEmpty);
    });

    test("OAuth2 flow without scopes decodes to empty scopes", () {
      final doc = APIDocument.fromMap(minimal({
        "components": {
          "securitySchemes": {
            "oauth": {
              "type": "oauth2",
              "flows": {
                "clientCredentials": {"tokenUrl": "https://example.com/token"}
              }
            }
          }
        }
      }));
      final flow = doc.components!.securitySchemes!["oauth"]!
          .flows!["clientCredentials"]!;
      expect(flow.scopes, isEmpty);
      expect(flow.tokenURL, Uri.parse("https://example.com/token"));
      expect(json.encode(doc.asMap()), contains('"scopes":{}'));
    });

    Map<String, dynamic> withRef(String ref) => minimal({
          "components": {
            "schemas": {
              "B": {
                "type": "object",
                "properties": {
                  "x": {"type": "string"}
                }
              },
              "A": {r"$ref": ref}
            }
          }
        });

    for (final ref in [
      "#/components/schemas/Missing",
      "#/info/title",
      "#/nope/x/y",
      "#/components/schemas/B/type",
    ]) {
      test("Unresolvable reference '$ref' throws ArgumentError", () {
        expect(
            () => APIDocument.fromMap(withRef(ref)),
            throwsA(isA<ArgumentError>().having((e) => e.message, "message",
                contains("Reference '$ref'"))));
      });
    }

    test("Reference into a nested object still resolves", () {
      final doc =
          APIDocument.fromMap(withRef("#/components/schemas/B/properties/x"));
      expect(doc.components!.schemas!["A"]!.type, APIType.string);
    });

    test("Reference to another file throws instead of resolving locally", () {
      expect(
          () => APIDocument.fromMap(
              withRef("other.yaml#/components/schemas/B")),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, "message", contains("another document"))));
    });
  });

  group("Phase 0 crash regressions", () {
    Map<String, dynamic> minimal([Map<String, dynamic> extra = const {}]) => {
          "openapi": "3.0.0",
          "info": {"title": "x", "version": "1"},
          "paths": <String, dynamic>{},
          ...extra,
        };

    test("Components without schemas decode to an empty schema map", () {
      final doc = APIDocument.fromMap(minimal({
        "components": {
          "responses": {
            "NotFound": {"description": "not found"}
          }
        }
      }));
      expect(doc.components!.schemas, isEmpty);
      expect(doc.components!.responses!["NotFound"], isNotNull);
    });

    test("Server variable without enum", () {
      final doc = APIDocument.fromMap(minimal({
        "servers": [
          {
            "url": "https://{host}/v1",
            "variables": {
              "host": {"default": "example.com"}
            }
          }
        ]
      }));
      final variable = doc.servers!.single!.variables!["host"]!;
      expect(variable.availableValues, isNull);
      expect(variable.defaultValue, "example.com");
      final encoded = doc.asMap()["servers"][0]["variables"]["host"] as Map;
      expect(encoded.containsKey("enum"), isFalse);
      expect(encoded["default"], "example.com");
    });

    test("Server variable with enum still decodes", () {
      final doc = APIDocument.fromMap(minimal({
        "servers": [
          {
            "url": "https://{host}/v1",
            "variables": {
              "host": {
                "default": "a.example.com",
                "enum": ["a.example.com", "b.example.com"]
              }
            }
          }
        ]
      }));
      expect(doc.servers!.single!.variables!["host"]!.availableValues,
          ["a.example.com", "b.example.com"]);
    });

    test("openIdConnect security scheme round trips", () {
      final doc = APIDocument.fromMap(minimal({
        "components": {
          "securitySchemes": {
            "oidc": {
              "type": "openIdConnect",
              "openIdConnectUrl":
                  "https://example.com/.well-known/openid-configuration"
            }
          }
        }
      }));
      final scheme = doc.components!.securitySchemes!["oidc"]!;
      expect(scheme.type, APISecuritySchemeType.openIdConnect);
      expect(scheme.connectURL,
          Uri.parse("https://example.com/.well-known/openid-configuration"));

      final encoded =
          doc.asMap()["components"]["securitySchemes"]["oidc"] as Map;
      expect(encoded, {
        "type": "openIdConnect",
        "openIdConnectUrl":
            "https://example.com/.well-known/openid-configuration",
      });
    });
  });

  group("'add' methods", () {
    test("'addHeader'", () {
      var resp = APIResponse("Response");

      // when null
      resp.addHeader(
          "x", APIHeader(schema: APISchemaObject.string(format: "initial")));
      expect(resp.headers!["x"]!.schema!.format, "initial");

      // add more than one
      resp.addHeader(
          "y", APIHeader(schema: APISchemaObject.string(format: "second")));
      expect(resp.headers!["x"]!.schema!.format, "initial");
      expect(resp.headers!["y"]!.schema!.format, "second");

      // cannot replace
      resp.addHeader(
          "y", APIHeader(schema: APISchemaObject.string(format: "third")));
      expect(resp.headers!["x"]!.schema!.format, "initial");
      expect(resp.headers!["y"]!.schema!.format, "second");
    });

    test("'addContent'", () {
      var resp = APIResponse("Response");

      // when null
      resp.addContent("x/a", APISchemaObject.string(format: "initial"));
      expect(resp.content!["x/a"]!.schema!.format, "initial");

      // add more than one
      resp.addContent("y/a", APISchemaObject.string(format: "second"));
      expect(resp.content!["x/a"]!.schema!.format, "initial");
      expect(resp.content!["y/a"]!.schema!.format, "second");

      // joins schema in oneOf if key exists
      resp.addContent("y/a", APISchemaObject.string(format: "third"));
      expect(resp.content!["x/a"]!.schema!.format, "initial");

      expect(resp.content!["y/a"]!.schema!.oneOf!.first!.format, "second");
      expect(resp.content!["y/a"]!.schema!.oneOf!.last!.format, "third");
    });

    test("'addResponse'", () {
      var op = APIOperation("op", null);

      // when null
      op.addResponse(200,
          APIResponse.schema("OK", APISchemaObject.string(format: "initial")));
      expect(op.responses!["200"]!.content!["application/json"]!.schema!.format,
          "initial");

      // add more than one
      op.addResponse(
          400,
          APIResponse.schema(
              "KINDABAD", APISchemaObject.string(format: "second"), headers: {
            "initial":
                APIHeader(schema: APISchemaObject.string(format: "initial"))
          }));
      expect(op.responses!["200"]!.content!["application/json"]!.schema!.format,
          "initial");
      expect(op.responses!["400"]!.content!["application/json"]!.schema!.format,
          "second");

      // join responses when key exists
      op.addResponse(
          400,
          APIResponse.schema("REALBAD", APISchemaObject.string(format: "third"),
              headers: {
                "second":
                    APIHeader(schema: APISchemaObject.string(format: "initial"))
              }));
      expect(op.responses!["200"]!.content!["application/json"]!.schema!.format,
          "initial");

      final r400 = op.responses!["400"]!;
      expect(r400.description, contains("KINDABAD"));
      expect(r400.description, contains("REALBAD"));
      expect(r400.content!["application/json"]!.schema!.oneOf, isNotNull);
      expect(r400.headers!["initial"], isNotNull);
      expect(r400.headers!["second"], isNotNull);
    });

    test("'addResponse' guards against null value", () {
      var op = APIOperation("op", null);

      op.addResponse(
          400,
          APIResponse.schema(
              "KINDABAD", APISchemaObject.string(format: "second")));
      expect(op.responses!["400"]!.content!["application/json"]!.schema!.format,
          "second");

      op.addResponse(
          400,
          APIResponse.schema(
              "REALBAD", APISchemaObject.string(format: "third")));
      expect(
          op.responses!["400"]!.content!["application/json"]!.schema!.oneOf!
              .length,
          2);
    });
  });
}
