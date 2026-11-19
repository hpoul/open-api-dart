import 'package:open_api_forked/src/codec/keyed_archive.dart';
import 'package:open_api_forked/v3.dart';
import 'package:test/test.dart';

void main() {
  APIServerDescription decode(Map<String, dynamic> server) =>
      APIDocument.fromMap({
        'openapi': '3.0.0',
        'info': {'title': 'x', 'version': '1'},
        'paths': <String, dynamic>{},
        'servers': [server],
      }).servers!.single;

  test('server url templates are kept verbatim', () {
    final server = decode({
      'url': '{scheme}://{region}.example.com:{port}/v1',
      'variables': {
        'scheme': {'default': 'https'},
        'region': {
          'default': 'eu',
          'enum': ['eu', 'us'],
        },
        'port': {'default': '443'},
      },
    });
    expect(server.url, '{scheme}://{region}.example.com:{port}/v1');
    expect(
      KeyedArchive.archive(server)['url'],
      '{scheme}://{region}.example.com:{port}/v1',
    );
  });

  test('resolve substitutes values, then defaults', () {
    final server = decode({
      'url': '{scheme}://{region}.example.com/v1',
      'variables': {
        'scheme': {'default': 'https'},
        'region': {'default': 'eu'},
      },
    });
    expect(server.resolve(), Uri.parse('https://eu.example.com/v1'));
    expect(
      server.resolve({'region': 'us'}),
      Uri.parse('https://us.example.com/v1'),
    );
  });

  test('resolve throws for a variable without value or default', () {
    final server = decode({'url': 'https://{host}/v1'});
    expect(server.resolve, throwsArgumentError);
    expect(
      server.resolve({'host': 'example.com'}),
      Uri.parse('https://example.com/v1'),
    );
  });

  test('relative urls stay relative', () {
    expect(decode({'url': '/api'}).resolve(), Uri.parse('/api'));
  });
}
