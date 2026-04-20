import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dlg_app/services/logging_http_client.dart';

// Cliente inner fake para tests
class _FakeInner extends http.BaseClient {
  final http.StreamedResponse Function(http.BaseRequest) handler;
  _FakeInner(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      handler(request);
}

http.StreamedResponse _streamedResponse(String body, {int statusCode = 200}) {
  final bytes = body.codeUnits;
  return http.StreamedResponse(
    Stream.value(bytes),
    statusCode,
    contentLength: bytes.length,
  );
}

void main() {
  group('LoggingHttpClient', () {
    test('reenvía la respuesta correctamente', () async {
      final client = LoggingHttpClient.withInner(
        _FakeInner((_) => _streamedResponse('{"ok":true}')),
      );
      final req = http.Request('GET', Uri.parse('https://example.com/'));
      final response = await client.send(req);
      final body = await response.stream.bytesToString();
      expect(response.statusCode, 200);
      expect(body, '{"ok":true}');
    });

    test('reenvía correctamente respuestas HTML', () async {
      const html = '<!DOCTYPE html><html><body>Hello</body></html>';
      final client = LoggingHttpClient.withInner(
        _FakeInner((_) => _streamedResponse(html)),
      );
      final req = http.Request('GET', Uri.parse('https://example.com/'));
      final response = await client.send(req);
      final body = await response.stream.bytesToString();
      expect(body, html); // el body llega completo aunque el log lo omita
    });

    test('reenvía correctamente respuestas largas', () async {
      final longBody = 'x' * 500; // más de 300 chars
      final client = LoggingHttpClient.withInner(
        _FakeInner((_) => _streamedResponse(longBody)),
      );
      final req = http.Request('GET', Uri.parse('https://example.com/'));
      final response = await client.send(req);
      final body = await response.stream.bytesToString();
      expect(body.length, 500); // body completo, no truncado
    });

    test('reenvía el status code correctamente', () async {
      final client = LoggingHttpClient.withInner(
        _FakeInner((_) => _streamedResponse('Not found', statusCode: 404)),
      );
      final req = http.Request('GET', Uri.parse('https://example.com/'));
      final response = await client.send(req);
      expect(response.statusCode, 404);
    });

    test('propaga excepciones del cliente inner', () async {
      final client = LoggingHttpClient.withInner(
        _FakeInner((_) => throw Exception('Network error')),
      );
      final req = http.Request('GET', Uri.parse('https://example.com/'));
      expect(() => client.send(req), throwsException);
    });
  });
}
