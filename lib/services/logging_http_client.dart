import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP que imprime en consola todas las peticiones y respuestas.
/// Solo activo en modo debug — en release no hace nada extra.
class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;

  LoggingHttpClient() : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('┌─── REQUEST ────────────────────────────────');
      debugPrint('│ ${request.method} ${request.url}');
      if (request is http.Request && request.body.isNotEmpty) {
        // Oculta la contraseña en los logs
        final sanitized = request.body.replaceAll(
            RegExp(r'"password"\s*:\s*"[^"]*"'), '"password":"***"');
        debugPrint('│ Body: $sanitized');
      }
      debugPrint('│ Headers: ${request.headers}');
      debugPrint('└────────────────────────────────────────────');
    }

    final stopwatch = Stopwatch()..start();
    final response = await _inner.send(request);
    stopwatch.stop();

    if (kDebugMode) {
      // Leemos el body sin consumir el stream original
      final bytes = await response.stream.toBytes();
      final bodyString = String.fromCharCodes(bytes);

      debugPrint('');
      debugPrint('┌─── RESPONSE ───────────────────────────────');
      debugPrint('│ ${response.statusCode} ${request.url}');
      debugPrint('│ Tiempo: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('│ Body: $bodyString');
      debugPrint('└────────────────────────────────────────────');

      // Devolvemos una nueva respuesta con el body ya leído
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        contentLength: bytes.length,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        request: response.request,
      );
    }

    return response;
  }

  @override
  void close() => _inner.close();
}
