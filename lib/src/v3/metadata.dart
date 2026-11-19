import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';

/// The object provides metadata about the API.
///
/// The metadata MAY be used by the clients if needed, and MAY be presented in editing or documentation generation tools for convenience.
final class APIInfo extends APIObject {
  APIInfo.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'title': title,
    'version': version,
  };

  /// Creates empty metadata for specification.
  APIInfo(
    this.title,
    this.version, {
    this.description,
    this.termsOfServiceURL,
    this.license,
    this.contact,
  });

  /// The title of the application.
  ///
  /// REQUIRED.
  String? title;

  /// A short description of the application.
  ///
  /// CommonMark syntax MAY be used for rich text representation.
  String? description;

  /// The version of the OpenAPI document (which is distinct from the OpenAPI Specification version or the API implementation version).
  ///
  /// REQUIRED.
  String? version;

  /// A URL to the Terms of Service for the API.
  ///
  /// MUST be in the format of a URL.
  Uri? termsOfServiceURL;

  /// The contact information for the exposed API.
  APIContact? contact;

  /// The license information for the exposed API.
  APILicense? license;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    title = object.decode('title');
    description = object.decode('description');
    final termsOfService = object.decode<String>('termsOfService');
    termsOfServiceURL = termsOfService != null
        ? Uri.tryParse(termsOfService)
        : null;
    contact = object.decodeObject('contact', () => APIContact());
    license = object.decodeObject('license', () => APILicense.empty());
    version = object.decode('version');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    if (title == null || version == null) {
      throw ArgumentError(
        "APIInfo must have non-null values for: 'title', 'version'.",
      );
    }

    object.encode('title', title);
    object.encode('description', description);
    object.encode('version', version);
    object.encode('termsOfService', termsOfServiceURL);
    object.encodeObject('contact', contact);
    object.encodeObject('license', license);
  }
}

/// Contact information for the exposed API.
final class APIContact extends APIObject {
  APIContact({this.name, this.url, this.email});
  APIContact.empty();

  @override
  Map<String, Object?> get toStringFields => {'name': name};

  /// The identifying name of the contact person/organization.
  String? name;

  /// The URL pointing to the contact information.
  ///
  /// MUST be in the format of a URL.
  Uri? url;

  /// The email address of the contact person/organization.
  ///
  /// MUST be in the format of an email address.
  String? email;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    name = object.decode('name');
    final url = object.decode<String>('url');
    this.url = url != null ? Uri.tryParse(url) : null;
    email = object.decode('email');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('name', name);
    object.encode('url', url);
    object.encode('email', email);
  }
}

/// License information for the exposed API.
final class APILicense extends APIObject {
  APILicense.empty();
  APILicense(this.name, {this.url});

  @override
  Map<String, Object?> get toStringFields => {'name': name};

  /// The license name used for the API.
  ///
  /// REQUIRED.
  String? name;

  /// A URL to the license used for the API.
  ///
  /// MUST be in the format of a URL.
  Uri? url;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    name = object.decode('name');
    url = object.decode('url');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    if (name == null) {
      throw ArgumentError("APILicense must have non-null values for: 'name'.");
    }

    object.encode('name', name);
    object.encode('url', url);
  }
}

/// Adds metadata to a single tag that is used by the [APIOperation].
///
/// It is not mandatory to have a [APITag] per tag defined in the [APIOperation] instances.
final class APITag extends APIObject {
  APITag.empty();

  @override
  Map<String, Object?> get toStringFields => {'name': name};

  APITag(this.name, {this.description});

  /// The name of the tag.
  ///
  /// REQUIRED.
  String? name;

  /// A short description for the tag.
  ///
  /// CommonMark syntax MAY be used for rich text representation.
  String? description;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    name = object.decode('name');
    description = object.decode('description');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    if (name == null) {
      throw ArgumentError("APITag must have non-null values for: 'name'.");
    }
    object.encode('name', name);
    object.encode('description', description);
  }
}
