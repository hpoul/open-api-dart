import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';

/// An [XML Object](https://spec.openapis.org/oas/v3.0.3#xml-object): how a
/// schema property is represented in XML.
final class APIXml extends APIObject {
  APIXml({
    this.name,
    this.namespace,
    this.prefix,
    this.attribute,
    this.wrapped,
  });

  APIXml.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'name': name,
    'attribute': (attribute ?? false) ? true : null,
    'wrapped': (wrapped ?? false) ? true : null,
  };

  /// The element or attribute name, replacing the property name.
  String? name;

  /// The absolute URI of the namespace.
  Uri? namespace;

  /// The prefix used for [name].
  String? prefix;

  /// Whether the property is an attribute instead of an element. `null`
  /// means not given (false).
  bool? attribute;

  /// For arrays, whether the items are wrapped in an element named after
  /// the property. `null` means not given (false).
  bool? wrapped;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    name = object.decode('name');
    namespace = object.decode('namespace');
    prefix = object.decode('prefix');
    attribute = object.decode('attribute');
    wrapped = object.decode('wrapped');
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('name', name);
    object.encode('namespace', namespace);
    object.encode('prefix', prefix);
    object.encode('attribute', attribute);
    object.encode('wrapped', wrapped);
  }
}
