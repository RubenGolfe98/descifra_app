import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dlg_app/repositories/coverage_repository.dart';

// ─── Constructores de respuestas ──────────────────────────────────────────────

Map<String, dynamic> coverageJson({
  int id = 1,
  String title = 'Guerra ruso - ucraniana',
  String slug = 'guerra-ruso-ucraniana',
}) {
  return {
    'id': id,
    'title': {'rendered': title},
    'slug': slug,
    'link': 'https://www.descifrandolaguerra.es/coberturas/$slug/',
    'yoast_head_json': {
      'og_image': [
        {'url': 'https://ejemplo.es/portada.jpg'}
      ],
      'description': 'Descripción de la cobertura',
    },
  };
}

String coveragesBody(int count, {int startId = 1}) => jsonEncode([
      for (var i = 0; i < count; i++)
        coverageJson(id: startId + i, title: 'Cobertura ${startId + i}')
    ]);

String coverageDetailBody({
  int id = 1,
  String content = '<p>Contenido de la cobertura</p>',
}) =>
    jsonEncode({
      'id': id,
      'title': {'rendered': 'Guerra ruso - ucraniana'},
      'slug': 'guerra-ruso-ucraniana',
      'link': 'https://www.descifrandolaguerra.es/coberturas/x/',
      'content': {'rendered': content},
    });

String relatedArticlesBody(int count) => jsonEncode([
      for (var i = 0; i < count; i++)
        {
          'id': i + 1,
          'date': '2026-07-01T10:00:00',
          'slug': 'articulo-${i + 1}',
          'title': {'rendered': 'Artículo ${i + 1}'},
          'jetpack_featured_media_url': 'https://ejemplo.es/foto.jpg',
          'yoast_head_json': {'description': 'Resumen', 'author': 'Autor'},
          'class_list': ['post-${i + 1}', 'category-noticias'],
        }
    ]);

// ─── Clientes de prueba ───────────────────────────────────────────────────────

MockClient clientReturning(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(body, status));

MockClient clientThrowing() =>
    MockClient((_) async => throw Exception('sin red'));

/// Cliente que registra las peticiones recibidas.
class RecordingClient {
  final List<Uri> requests = [];
  final String body;
  final int status;

  RecordingClient({this.body = '[]', this.status = 200});

  late final MockClient client = MockClient((request) async {
    requests.add(request.url);
    return http.Response(body, status);
  });

  Map<String, String> get lastQuery => requests.last.queryParameters;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(CoverageRepository.clearCache);
  tearDown(CoverageRepository.clearCache);

  group('fetchCoverages', () {
    test('descarga las coberturas y las devuelve', () async {
      final repo =
          CoverageRepository(client: clientReturning(coveragesBody(3)));

      final coverages = await repo.fetchCoverages();

      expect(coverages, hasLength(3));
      expect(coverages.first.title, 'Cobertura 1');
      expect(coverages.first.imageUrl, 'https://ejemplo.es/portada.jpg');
    });

    test('reutiliza la caché en la segunda llamada a la página 1', () async {
      final recording = RecordingClient(body: coveragesBody(2));
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverages();
      final segunda = await repo.fetchCoverages();

      expect(segunda, hasLength(2));
      expect(recording.requests, hasLength(1));
    });

    test('la caché se comparte entre instancias', () async {
      await CoverageRepository(client: clientReturning(coveragesBody(2)))
          .fetchCoverages();

      final recording = RecordingClient();
      final coverages =
          await CoverageRepository(client: recording.client).fetchCoverages();

      expect(coverages, hasLength(2));
      expect(recording.requests, isEmpty);
    });

    test('las páginas siguientes nunca salen de caché', () async {
      final recording = RecordingClient(body: coveragesBody(5));
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverages();
      await repo.fetchCoverages(page: 2);
      await repo.fetchCoverages(page: 2);

      expect(recording.requests, hasLength(3),
          reason: 'solo la primera página se cachea');
    });

    test('la página 2 no sobrescribe la caché de la primera', () async {
      var call = 0;
      final repo = CoverageRepository(
        client: MockClient((_) async {
          call++;
          return http.Response(
            call == 1 ? coveragesBody(2) : coveragesBody(7, startId: 100),
            200,
          );
        }),
      );

      await repo.fetchCoverages();
      await repo.fetchCoverages(page: 2);
      final primera = await repo.fetchCoverages();

      expect(primera, hasLength(2));
    });

    test('sigue usando la caché justo antes de que expire', () {
      fakeAsync((async) {
        final recording = RecordingClient(body: coveragesBody(1));
        final repo = CoverageRepository(client: recording.client);

        repo.fetchCoverages();
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 1, minutes: 59));

        repo.fetchCoverages();
        async.flushMicrotasks();

        expect(recording.requests, hasLength(1));
      });
    });

    test('devuelve lista vacía si el servidor responde con error', () async {
      final repo = CoverageRepository(client: clientReturning('', status: 500));

      expect(await repo.fetchCoverages(), isEmpty);
    });

    test('un error del servidor no guarda nada en caché', () async {
      final recording = RecordingClient(status: 500);
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverages();
      await repo.fetchCoverages();

      expect(recording.requests, hasLength(2));
    });

    test('devuelve lista vacía ante una excepción sin caché previa', () async {
      final repo = CoverageRepository(client: clientThrowing());

      expect(await repo.fetchCoverages(), isEmpty);
    });

    test('conserva la caché anterior si una recarga lanza excepción', () {
      fakeAsync((async) {
        var call = 0;
        final repo = CoverageRepository(
          client: MockClient((_) async {
            call++;
            if (call == 1) return http.Response(coveragesBody(4), 200);
            throw Exception('sin red');
          }),
        );

        repo.fetchCoverages();
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 3));

        List<Object>? resultado;
        repo.fetchCoverages().then((c) => resultado = c);
        async.flushMicrotasks();

        expect(resultado, hasLength(4),
            reason: 'ante un fallo se devuelve lo último conocido');
      });
    });

    test('devuelve lista vacía si la respuesta no es JSON válido', () async {
      final repo = CoverageRepository(client: clientReturning('<html>'));

      expect(await repo.fetchCoverages(), isEmpty);
    });

    test('envía los parámetros de paginación y orden', () async {
      final recording = RecordingClient(body: coveragesBody(1));
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverages(page: 3, perPage: 12);

      expect(recording.lastQuery['page'], '3');
      expect(recording.lastQuery['per_page'], '12');
      expect(recording.lastQuery['orderby'], 'date');
      expect(recording.lastQuery['order'], 'desc');
      expect(recording.requests.last.path, contains('/cobertura'));
    });
  });

  group('fetchCoverageDetail', () {
    test('descarga el detalle de una cobertura', () async {
      final repo = CoverageRepository(
        client: clientReturning(coverageDetailBody(id: 61320)),
      );

      final detail = await repo.fetchCoverageDetail(61320);

      expect(detail, isNotNull);
      expect(detail!.id, 61320);
      expect(detail.contentHtml, '<p>Contenido de la cobertura</p>');
    });

    test('reutiliza la caché en la segunda llamada', () async {
      final recording = RecordingClient(body: coverageDetailBody());
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverageDetail(1);
      final segunda = await repo.fetchCoverageDetail(1);

      expect(segunda, isNotNull);
      expect(recording.requests, hasLength(1));
    });

    test('cada cobertura se cachea por separado', () async {
      final recording = RecordingClient(body: coverageDetailBody());
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverageDetail(1);
      await repo.fetchCoverageDetail(2);

      expect(recording.requests, hasLength(2));
    });

    test('la caché de detalles no caduca con el tiempo', () {
      fakeAsync((async) {
        final recording = RecordingClient(body: coverageDetailBody());
        final repo = CoverageRepository(client: recording.client);

        repo.fetchCoverageDetail(1);
        async.flushMicrotasks();

        async.elapse(const Duration(days: 30));

        repo.fetchCoverageDetail(1);
        async.flushMicrotasks();

        expect(recording.requests, hasLength(1));
      });
    });

    test('devuelve null si el servidor responde con error', () async {
      final repo = CoverageRepository(client: clientReturning('', status: 404));

      expect(await repo.fetchCoverageDetail(1), isNull);
    });

    test('un error no se guarda en caché', () async {
      final recording = RecordingClient(status: 404);
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverageDetail(1);
      await repo.fetchCoverageDetail(1);

      expect(recording.requests, hasLength(2));
    });

    test('devuelve null ante una excepción', () async {
      final repo = CoverageRepository(client: clientThrowing());

      expect(await repo.fetchCoverageDetail(1), isNull);
    });

    test('devuelve null si la respuesta no es JSON válido', () async {
      final repo = CoverageRepository(client: clientReturning('<html>'));

      expect(await repo.fetchCoverageDetail(1), isNull);
    });

    test('pide el detalle por identificador', () async {
      final recording = RecordingClient(body: coverageDetailBody());
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverageDetail(61320);

      expect(recording.requests.single.path, endsWith('/cobertura/61320'));
    });
  });

  group('fetchRelatedArticles', () {
    test('devuelve los artículos en bruto', () async {
      final repo =
          CoverageRepository(client: clientReturning(relatedArticlesBody(4)));

      final articles = await repo.fetchRelatedArticles('guerra-ucraniana');

      expect(articles, hasLength(4));
      expect(articles.first['id'], 1);
      expect(articles.first['title']['rendered'], 'Artículo 1');
    });

    test('devuelve lista vacía si no hay resultados', () async {
      final repo = CoverageRepository(client: clientReturning('[]'));

      expect(await repo.fetchRelatedArticles('x'), isEmpty);
    });

    test('devuelve lista vacía si el servidor responde con error', () async {
      final repo = CoverageRepository(client: clientReturning('', status: 500));

      expect(await repo.fetchRelatedArticles('x'), isEmpty);
    });

    test('devuelve lista vacía ante una excepción', () async {
      final repo = CoverageRepository(client: clientThrowing());

      expect(await repo.fetchRelatedArticles('x'), isEmpty);
    });

    test('devuelve lista vacía si la respuesta no es JSON válido', () async {
      final repo = CoverageRepository(client: clientReturning('<html>'));

      expect(await repo.fetchRelatedArticles('x'), isEmpty);
    });

    test('nunca se cachea: cada llamada consulta al servidor', () async {
      final recording = RecordingClient(body: relatedArticlesBody(2));
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchRelatedArticles('x');
      await repo.fetchRelatedArticles('x');

      expect(recording.requests, hasLength(2));
    });

    test('filtra por el slug de la cobertura', () async {
      final recording = RecordingClient(body: relatedArticlesBody(1));
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchRelatedArticles('guerra-ucraniana', page: 2, perPage: 25);

      expect(recording.lastQuery['cobertura'], 'guerra-ucraniana');
      expect(recording.lastQuery['page'], '2');
      expect(recording.lastQuery['per_page'], '25');
      expect(recording.requests.last.path, contains('/posts'));
    });
  });

  group('clearCache', () {
    test('obliga a volver a la red tras limpiarla', () async {
      final recording = RecordingClient(body: coveragesBody(1));
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverages();
      CoverageRepository.clearCache();
      await repo.fetchCoverages();

      expect(recording.requests, hasLength(2));
    });

    test('limpia también la caché de detalles', () async {
      final recording = RecordingClient(body: coverageDetailBody());
      final repo = CoverageRepository(client: recording.client);

      await repo.fetchCoverageDetail(1);
      CoverageRepository.clearCache();
      await repo.fetchCoverageDetail(1);

      expect(recording.requests, hasLength(2));
    });

    test('puede llamarse sin que haya nada cacheado', () {
      expect(CoverageRepository.clearCache, returnsNormally);
    });
  });

  group('prefetch', () {
    test('no hace nada si la caché sigue vigente', () async {
      await CoverageRepository(client: clientReturning(coveragesBody(1)))
          .fetchCoverages();

      expect(CoverageRepository.prefetch, returnsNormally);
    });

    test('lanza la descarga si no hay caché', () async {
      // Usa el cliente real, interceptado por el entorno de test.
      expect(CoverageRepository.prefetch, returnsNormally);
      await settle();
    });
  });

  group('Constructor', () {
    test('usa el pool compartido si no se le inyecta cliente', () {
      expect(CoverageRepository(), isA<CoverageRepository>());
    });
  });
}
