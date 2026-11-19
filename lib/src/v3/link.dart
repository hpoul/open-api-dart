import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/src/object.dart';
import 'package:open_api_forked/src/v3/server.dart';

/// A [Link Object](https://spec.openapis.org/oas/v3.0.3#link-object): a
/// design-time link from a response to another operation.
final class APILink extends APIObject {
  APILink({
    this.operationRef,
    this.operationId,
    Map<String, Object?>? parameters,
    this.requestBody,
    this.description,
    this.server,
  }) : parameters = parameters ?? {};

  APILink.empty();

  @override
  Map<String, Object?> get toStringFields => {
    'operationId': operationId,
    'operationRef': operationRef,
  };

  /// A reference to the target operation, such as
  /// `#/paths/~12.0~1repositories~1{username}/get`. Kept as a string: it
  /// is a JSON pointer, not resolved. Mutually exclusive with
  /// [operationId].
  String? operationRef;

  /// The `operationId` of the target operation. Mutually exclusive with
  /// [operationRef].
  String? operationId;

  /// Values to pass to the target operation's parameters, by name
  /// (optionally qualified as `path.id`). Each is a constant or a runtime
  /// expression such as `$response.body#/id`, kept as decoded.
  Map<String, Object?> parameters = {};

  /// A constant or runtime expression to use as the target's request body,
  /// kept as decoded.
  Object? requestBody;

  /// A description of the link.
  ///
  /// CommonMark syntax MAY be used for rich text representation.
  String? description;

  /// A server to use for the target operation instead of its own.
  APIServerDescription? server;

  @override
  void decode(KeyedArchive object) {
    super.decode(object);

    operationRef = object.decode('operationRef');
    operationId = object.decode('operationId');
    parameters = object.decode<Map<String, Object?>>('parameters') ?? {};
    requestBody = object.decode<Object?>('requestBody');
    description = object.decode('description');
    server = object.decodeObject('server', () => APIServerDescription.empty());
  }

  @override
  void encode(KeyedArchive object) {
    super.encode(object);

    object.encode('operationRef', operationRef);
    object.encode('operationId', operationId);
    object.encode('parameters', parameters, omitEmpty: true);
    object.encode('requestBody', requestBody);
    object.encode('description', description);
    object.encodeObject('server', server);
  }
}
