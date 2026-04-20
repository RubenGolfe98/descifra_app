import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP que imprime en consola todas las peticiones y respuestas.
/// Solo activo en modo debug — en release no hace nada extra.
class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;

  LoggingHttpClient() : _inner = http.Client();

  /// Constructor para tests — permite inyectar un cliente fake
  @visibleForTesting
  LoggingHttpClient.withInner(http.Client inner) : _inner = inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('┌─── REQUEST ────────────────────────────────');
      debugPrint('│ ${request.method} ${request.url}');
      if (request is http.Request && request.body.isNotEmpty) {
        final sanitized = request.body.replaceAll(
            RegExp(r'password=[^&]+'), 'password=***');
        debugPrint('│ Body: $sanitized');
      }
      debugPrint('└────────────────────────────────────────────');
    }

    final stopwatch = Stopwatch()..start();
    final response = await _inner.send(request);
    stopwatch.stop();

    if (kDebugMode) {
      // Leer bytes para poder loggear Y reconstruir el stream
      final bytes = await response.stream.toBytes();
      final elapsed = stopwatch.elapsedMilliseconds;

      // Log en microtask para no bloquear el procesamiento de la respuesta
      Future.microtask(() {
        final bodyString = String.fromCharCodes(bytes);
        final isHtml = bodyString.trimLeft().startsWith('<!DOCTYPE') ||
            bodyString.trimLeft().startsWith('<html');
        final displayBody = isHtml
            ? '[HTML ${bytes.length} bytes — omitido]'
            : (bodyString.length > 300
                ? '${bodyString.substring(0, 300)}…'
                : bodyString);

        debugPrint('');
        debugPrint('┌─── RESPONSE ───────────────────────────────');
        debugPrint('│ ${response.statusCode} ${request.url}');
        debugPrint('│ Tiempo: ${elapsed}ms');
        debugPrint('│ Body: $displayBody');
        debugPrint('└────────────────────────────────────────────');
      });

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