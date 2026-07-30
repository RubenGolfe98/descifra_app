import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dlg_app/models/article.dart';
import 'package:dlg_app/repositories/article_repository.dart';
import 'package:dlg_app/services/article_cache.dart';

/// Caché en memoria que sustituye a ArticleCache y evita tocar el disco.
class FakeArticleCache implements ArticleCache {
  final Map<String, String> lists = {};
  final Map<int, String> details = {};

  /// Claves cuyo contenido debe considerarse obsoleto.
  final Set<String> staleLists = {};
  final Set<int> staleDetails = {};

  final List<String> savedListKeys = [];
  final List<int> savedDetailIds = [];

  @override
  Future<String?> getList({String? key}) async => lists[key ?? 'articles_list'];

  @override
  Future<void> saveList(String json, {String? key}) async {
    final k = key ?? 'articles_list';
    lists[k] = json;
    savedListKeys.add(k);
  }

  @override
  Future<bool> isListStale({String? key}) async =>
      staleLists.contains(key ?? 'articles_list');

  @override
  Future<String?> getDetail(int id) async => details[id];

  @override
  Future<void> saveDetail(int id, String json, {bool isPremium = false}) async {
    details[id] = json;
    savedDetailIds.add(id);
  }

  @override
  Future<bool> isDetailStale(int id) async => staleDetails.contains(id);

  @override
  Future<String?> getSearch(String query) async => null;

  @override
  Future<void> saveSearch(String query, String json) async {}

  @override
  Future<void> clearExclusiveContent() async {}
}

// ─── Constructores de respuestas ──────────────────────────────────────────────

Map<String, dynamic> articleJson({
  int id = 1,
  String title = 'Titular',
  String date = '2026-07-01T10:00:00',
  String slug = 'un-articulo',
  List<String> classList = const ['post-1', 'category-noticias'],
}) {
  return {
    'id': id,
    'date': date,
    'slug': slug,
    'title': {'rendered': title},
    'jetpack_featured_media_url': 'https://ejemplo.es/foto.jpg',
    'yoast_head_json': {'description': 'Resumen', 'author': 'Autor'},
    'class_list': classList,
  };
}

String articlesBody(int count, {int startId = 1}) => jsonEncode([
      for (var i = 0; i < count; i++)
        articleJson(id: startId + i, title: 'Titular ${startId + i}')
    ]);

String detailBody({
  int id = 1,
  String content = '<p>Contenido</p>',
  List<String> classList = const ['post-1'],
}) =>
    jsonEncode({
      'id': id,
      'date': '2026-07-01T10:00:00',
      'title': {'rendered': 'Titular'},
      'content': {'rendered': content},
      'jetpack_featured_media_url': 'https://ejemplo.es/foto.jpg',
      'yoast_head_json': {'author': 'Autor'},
      'class_list': classList,
    });

// ─── Clientes de prueba ───────────────────────────────────────────────────────

MockClient clientReturning(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(body, status));

MockClient clientThrowing() =>
    MockClient((_) async => throw Exception('sin red'));

/// Cliente que registra las URLs solicitadas.
class RecordingClient {
  final List<Uri> requests = [];
  final List<Map<String, String>> headers = [];
  final String body;
  final int status;

  RecordingClient({this.body = '[]', this.status = 200});

  late final MockClient client = MockClient((request) async {
    requests.add(request.url);
    headers.add(request.headers);
    return http.Response(body, status);
  });

  Map<String, String> get lastQuery => requests.last.queryParameters;
}

/// Espera a que se resuelvan los refrescos lanzados sin await.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeArticleCache cache;

  setUp(() {
    cache = FakeArticleCache();
  });

  group('SharedHttp', () {
    tearDown(SharedHttp.dispose);

    test('el repositorio usa los pools por defecto si no se le inyecta nada',
        () {
      final repo = ArticleRepository();

      expect(repo, isA<ArticleRepository>());
    });

    test('devuelve siempre el mismo cliente principal', () {
      expect(identical(SharedHttp.client, SharedHttp.client), isTrue);
    });

    test('userClient es un alias del cliente principal', () {
      expect(identical(SharedHttp.userClient, SharedHttp.client), isTrue);
    });

    test('el cliente de background es distinto del principal', () {
      expect(identical(SharedHttp.bgClient, SharedHttp.client), isFalse);
    });

    test('devuelve siempre el mismo cliente de background', () {
      expect(identical(SharedHttp.bgClient, SharedHttp.bgClient), isTrue);
    });

    test('dispose libera ambos pools y se recrean al pedirlos', () {
      final antesUser = SharedHttp.client;
      final antesBg = SharedHttp.bgClient;

      SharedHttp.dispose();

      expect(identical(SharedHttp.client, antesUser), isFalse);
      expect(identical(SharedHttp.bgClient, antesBg), isFalse);
    });

    test('dispose puede llamarse sin que existan clientes', () {
      SharedHttp.dispose();

      expect(SharedHttp.dispose, returnsNormally);
    });
  });

  group('fetchLatestArticles', () {
    test('descarga de red cuando no hay caché', () async {
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(3)),
        cache: cache,
      );

      final articles = await repo.fetchLatestArticles();

      expect(articles, hasLength(3));
      expect(articles.first.title, 'Titular 1');
      expect(cache.savedListKeys, contains('articles_latest'));
    });

    test('devuelve lista vacía si la red falla y no hay caché', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchLatestArticles(), isEmpty);
    });

    test('devuelve lista vacía si el servidor responde con error', () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 500),
        cache: cache,
      );

      expect(await repo.fetchLatestArticles(), isEmpty);
    });

    test('sirve la caché al instante y refresca en segundo plano', () async {
      cache.lists['articles_latest'] = articlesBody(2);
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(5)),
        cache: cache,
      );

      List<Article>? refrescados;
      final articles = await repo.fetchLatestArticles(
        onRefreshed: (fresh) => refrescados = fresh,
      );

      expect(articles, hasLength(2), reason: 'la caché se sirve de inmediato');

      await settle();
      expect(refrescados, hasLength(5));
    });

    test('avisa de que arranca el refresco en segundo plano', () async {
      cache.lists['articles_latest'] = articlesBody(2);
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(2)),
        cache: cache,
      );

      var iniciado = false;
      await repo.fetchLatestArticles(
        onBackgroundRefreshStarted: () => iniciado = true,
      );

      expect(iniciado, isTrue);
    });

    test('avisa si el refresco en segundo plano falla', () async {
      cache.lists['articles_latest'] = articlesBody(2);
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      var fallido = false;
      await repo.fetchLatestArticles(
        onBackgroundRefreshFailed: () => fallido = true,
      );
      await settle();

      expect(fallido, isTrue);
    });

    test('refresca siempre aunque la caché sea reciente', () async {
      cache.lists['articles_latest'] = articlesBody(1);
      final recording = RecordingClient(body: articlesBody(1));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchLatestArticles();
      await settle();

      expect(recording.requests, isNotEmpty);
    });

    test('funciona sin ninguna devolución de llamada', () async {
      cache.lists['articles_latest'] = articlesBody(1);
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      await expectLater(repo.fetchLatestArticles(), completes);
      await settle();
    });

    test('envía los parámetros de paginación indicados', () async {
      final recording = RecordingClient(body: articlesBody(1));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchLatestArticles(perPage: 25, page: 3);

      expect(recording.lastQuery['per_page'], '25');
      expect(recording.lastQuery['page'], '3');
    });
  });

  group('fetchArticlesByRegion', () {
    test('descarga de red cuando no hay caché', () async {
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(4)),
        cache: cache,
      );

      final articles = await repo.fetchArticlesByRegion(101);

      expect(articles, hasLength(4));
      expect(cache.savedListKeys, contains('articles_region_101'));
    });

    test('sirve la caché sin refrescar si sigue vigente', () async {
      cache.lists['articles_region_101'] = articlesBody(2);
      final recording = RecordingClient(body: articlesBody(9));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final articles = await repo.fetchArticlesByRegion(101);
      await settle();

      expect(articles, hasLength(2));
      expect(recording.requests, isEmpty);
    });

    test('refresca en segundo plano si la caché está obsoleta', () async {
      cache.lists['articles_region_101'] = articlesBody(2);
      cache.staleLists.add('articles_region_101');
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(7)),
        cache: cache,
      );

      List<Article>? refrescados;
      final articles = await repo.fetchArticlesByRegion(
        101,
        onRefreshed: (fresh) => refrescados = fresh,
      );

      expect(articles, hasLength(2));
      await settle();
      expect(refrescados, hasLength(7));
    });

    test('no avisa si el refresco de región falla', () async {
      cache.lists['articles_region_101'] = articlesBody(2);
      cache.staleLists.add('articles_region_101');
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      var avisado = false;
      await repo.fetchArticlesByRegion(101, onRefreshed: (_) => avisado = true);
      await settle();

      expect(avisado, isFalse);
    });

    test('devuelve lista vacía si la red falla sin caché', () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 502),
        cache: cache,
      );

      expect(await repo.fetchArticlesByRegion(101), isEmpty);
    });

    test('devuelve lista vacía ante una excepción de red', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchArticlesByRegion(101), isEmpty);
    });

    test('filtra por el identificador de región', () async {
      final recording = RecordingClient(body: articlesBody(1));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchArticlesByRegion(103, perPage: 5, page: 2);

      expect(recording.lastQuery['region'], '103');
      expect(recording.lastQuery['per_page'], '5');
      expect(recording.lastQuery['page'], '2');
    });
  });

  group('fetchAnalysisArticles', () {
    test('descarga de red cuando no hay caché', () async {
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(3)),
        cache: cache,
      );

      final articles = await repo.fetchAnalysisArticles();

      expect(articles, hasLength(3));
      expect(cache.savedListKeys, contains('articles_analysis'));
    });

    test('sirve la caché sin refrescar si sigue vigente', () async {
      cache.lists['articles_analysis'] = articlesBody(2);
      final recording = RecordingClient(body: articlesBody(6));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final articles = await repo.fetchAnalysisArticles();
      await settle();

      expect(articles, hasLength(2));
      expect(recording.requests, isEmpty);
    });

    test('refresca en segundo plano si la caché está obsoleta', () async {
      cache.lists['articles_analysis'] = articlesBody(2);
      cache.staleLists.add('articles_analysis');
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(6)),
        cache: cache,
      );

      List<Article>? refrescados;
      await repo.fetchAnalysisArticles(
          onRefreshed: (fresh) => refrescados = fresh);
      await settle();

      expect(refrescados, hasLength(6));
    });

    test('devuelve lista vacía si la red falla sin caché', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchAnalysisArticles(), isEmpty);
    });

    test('usa la categoría de análisis', () async {
      final recording = RecordingClient(body: articlesBody(1));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchAnalysisArticles();

      expect(recording.lastQuery['categories'], '255');
    });
  });

  group('fetchInterviewArticles', () {
    test('descarga de red cuando no hay caché', () async {
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(2)),
        cache: cache,
      );

      final articles = await repo.fetchInterviewArticles();

      expect(articles, hasLength(2));
      expect(cache.savedListKeys, contains('articles_interviews'));
    });

    test('sirve la caché sin refrescar si sigue vigente', () async {
      cache.lists['articles_interviews'] = articlesBody(3);
      final recording = RecordingClient(body: articlesBody(8));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final articles = await repo.fetchInterviewArticles();
      await settle();

      expect(articles, hasLength(3));
      expect(recording.requests, isEmpty);
    });

    test('refresca en segundo plano si la caché está obsoleta', () async {
      cache.lists['articles_interviews'] = articlesBody(3);
      cache.staleLists.add('articles_interviews');
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(8)),
        cache: cache,
      );

      List<Article>? refrescados;
      await repo.fetchInterviewArticles(
          onRefreshed: (fresh) => refrescados = fresh);
      await settle();

      expect(refrescados, hasLength(8));
    });

    test('devuelve lista vacía si la red falla sin caché', () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 500),
        cache: cache,
      );

      expect(await repo.fetchInterviewArticles(), isEmpty);
    });

    test('usa la categoría de entrevistas', () async {
      final recording = RecordingClient(body: articlesBody(1));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchInterviewArticles();

      expect(recording.lastQuery['categories'], '271');
    });
  });

  group('Paginación', () {
    test('fetchMoreArticles devuelve la página pedida', () async {
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(10, startId: 11)),
        cache: cache,
      );

      final more = await repo.fetchMoreArticles(page: 2);

      expect(more, hasLength(10));
      expect(more!.first.title, 'Titular 11');
    });

    test('fetchMoreArticles devuelve lista vacía en un 400 (fin real)',
        () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 400),
        cache: cache,
      );

      expect(await repo.fetchMoreArticles(page: 99), isEmpty);
    });

    test('fetchMoreArticles devuelve null ante otro error', () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 500),
        cache: cache,
      );

      expect(await repo.fetchMoreArticles(page: 2), isNull);
    });

    test('fetchMoreArticles devuelve null ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchMoreArticles(page: 2), isNull);
    });

    test('fetchMoreAnalysisArticles distingue fin real de error', () async {
      final finReal = ArticleRepository(
          client: clientReturning('', status: 400), cache: cache);
      final error = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);
      final excepcion =
          ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await finReal.fetchMoreAnalysisArticles(page: 9), isEmpty);
      expect(await error.fetchMoreAnalysisArticles(page: 2), isNull);
      expect(await excepcion.fetchMoreAnalysisArticles(page: 2), isNull);
    });

    test('fetchMoreAnalysisArticles devuelve los artículos', () async {
      final repo = ArticleRepository(
          client: clientReturning(articlesBody(4)), cache: cache);

      expect(await repo.fetchMoreAnalysisArticles(page: 2), hasLength(4));
    });

    test('fetchMoreInterviewArticles distingue fin real de error', () async {
      final finReal = ArticleRepository(
          client: clientReturning('', status: 400), cache: cache);
      final error = ArticleRepository(
          client: clientReturning('', status: 503), cache: cache);
      final excepcion =
          ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await finReal.fetchMoreInterviewArticles(page: 9), isEmpty);
      expect(await error.fetchMoreInterviewArticles(page: 2), isNull);
      expect(await excepcion.fetchMoreInterviewArticles(page: 2), isNull);
    });

    test('fetchMoreInterviewArticles devuelve los artículos', () async {
      final repo = ArticleRepository(
          client: clientReturning(articlesBody(4)), cache: cache);

      expect(await repo.fetchMoreInterviewArticles(page: 2), hasLength(4));
    });

    test('fetchMoreArticlesByRegion distingue fin real de error', () async {
      final finReal = ArticleRepository(
          client: clientReturning('', status: 400), cache: cache);
      final error = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);
      final excepcion =
          ArticleRepository(client: clientThrowing(), cache: cache);

      expect(
        await finReal.fetchMoreArticlesByRegion(regionId: 101, page: 9),
        isEmpty,
      );
      expect(
        await error.fetchMoreArticlesByRegion(regionId: 101, page: 2),
        isNull,
      );
      expect(
        await excepcion.fetchMoreArticlesByRegion(regionId: 101, page: 2),
        isNull,
      );
    });

    test('fetchMoreArticlesByRegion devuelve los artículos', () async {
      final repo = ArticleRepository(
          client: clientReturning(articlesBody(6)), cache: cache);

      expect(
        await repo.fetchMoreArticlesByRegion(regionId: 101, page: 2),
        hasLength(6),
      );
    });
  });

  group('fetchArticleBySlug', () {
    test('devuelve el artículo encontrado', () async {
      final repo = ArticleRepository(
        client: clientReturning(jsonEncode([articleJson(id: 42)])),
        cache: cache,
      );

      final article = await repo.fetchArticleBySlug('un-articulo');

      expect(article?.id, 42);
    });

    test('devuelve null si no hay resultados', () async {
      final repo =
          ArticleRepository(client: clientReturning('[]'), cache: cache);

      expect(await repo.fetchArticleBySlug('inexistente'), isNull);
    });

    test('devuelve null si el servidor responde con error', () async {
      final repo = ArticleRepository(
          client: clientReturning('', status: 404), cache: cache);

      expect(await repo.fetchArticleBySlug('x'), isNull);
    });

    test('devuelve null ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchArticleBySlug('x'), isNull);
    });

    test('envía las cookies cuando se le pasan', () async {
      final recording = RecordingClient(body: jsonEncode([articleJson()]));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchArticleBySlug('x', cookies: 'wordpress=abc');

      expect(recording.headers.last['Cookie'], 'wordpress=abc');
    });

    test('no envía cookies si la cadena está vacía', () async {
      final recording = RecordingClient(body: jsonEncode([articleJson()]));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchArticleBySlug('x', cookies: '');

      expect(recording.headers.last.containsKey('Cookie'), isFalse);
    });
  });

  group('fetchArticleDetail', () {
    test('descarga de red cuando no hay caché', () async {
      final repo = ArticleRepository(
        client: clientReturning(detailBody(id: 7)),
        cache: cache,
      );

      final detail = await repo.fetchArticleDetail(7);

      expect(detail.id, 7);
      expect(detail.content, '<p>Contenido</p>');
      expect(cache.savedDetailIds, contains(7));
    });

    test('lanza una excepción si la red falla sin caché', () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 404),
        cache: cache,
      );

      expect(() => repo.fetchArticleDetail(7), throwsException);
    });

    test('sirve la caché sin refrescar si está vigente y con contenido',
        () async {
      cache.details[7] = detailBody(id: 7);
      final recording = RecordingClient(body: detailBody(id: 7));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final detail = await repo.fetchArticleDetail(7);
      await settle();

      expect(detail.id, 7);
      expect(recording.requests, isEmpty);
    });

    test('refresca en segundo plano si el detalle está obsoleto', () async {
      cache.details[7] = detailBody(id: 7, content: '<p>Antiguo</p>');
      cache.staleDetails.add(7);
      final repo = ArticleRepository(
        client: clientReturning(detailBody(id: 7, content: '<p>Nuevo</p>')),
        cache: cache,
      );

      String? refrescado;
      final detail = await repo.fetchArticleDetail(
        7,
        onRefreshed: (fresh) => refrescado = fresh.content,
      );

      expect(detail.content, '<p>Antiguo</p>');
      await settle();
      expect(refrescado, '<p>Nuevo</p>');
    });

    test('refresca si el contenido cacheado está vacío', () async {
      cache.details[7] = detailBody(id: 7, content: '');
      final repo = ArticleRepository(
        client: clientReturning(detailBody(id: 7, content: '<p>Ya sí</p>')),
        cache: cache,
      );

      String? refrescado;
      await repo.fetchArticleDetail(
        7,
        onRefreshed: (fresh) => refrescado = fresh.content,
      );
      await settle();

      expect(refrescado, '<p>Ya sí</p>');
    });

    test('trata el contenido en blanco como vacío', () async {
      cache.details[7] = detailBody(id: 7, content: '   \n  ');
      final recording = RecordingClient(body: detailBody(id: 7));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchArticleDetail(7);
      await settle();

      expect(recording.requests, isNotEmpty);
    });

    test('forceRefresh ignora la caché y va a la red', () async {
      cache.details[7] = detailBody(id: 7, content: '<p>Antiguo</p>');
      final repo = ArticleRepository(
        client: clientReturning(detailBody(id: 7, content: '<p>Fresco</p>')),
        cache: cache,
      );

      final detail = await repo.fetchArticleDetail(7, forceRefresh: true);

      expect(detail.content, '<p>Fresco</p>');
    });

    test('no falla si el refresco en segundo plano no devuelve nada', () async {
      cache.details[7] = detailBody(id: 7);
      cache.staleDetails.add(7);
      final repo = ArticleRepository(
        client: clientReturning('', status: 404),
        cache: cache,
      );

      var refrescado = false;
      await repo.fetchArticleDetail(7, onRefreshed: (_) => refrescado = true);
      await settle();

      expect(refrescado, isFalse);
    });

    test('envía cookies y nonce cuando se le pasan', () async {
      final recording = RecordingClient(body: detailBody(id: 7));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchArticleDetail(7,
          cookies: 'wordpress=abc', restNonce: 'nonce123');

      expect(recording.headers.last['Cookie'], 'wordpress=abc');
      expect(recording.headers.last['X-WP-Nonce'], 'nonce123');
    });

    test('omite las cabeceras si vienen vacías', () async {
      final recording = RecordingClient(body: detailBody(id: 7));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.fetchArticleDetail(7, cookies: '', restNonce: '');

      expect(recording.headers.last.containsKey('Cookie'), isFalse);
      expect(recording.headers.last.containsKey('X-WP-Nonce'), isFalse);
    });

    test('renueva el nonce y reintenta ante un 401', () async {
      var call = 0;
      final headersEnviadas = <Map<String, String>>[];
      final repo = ArticleRepository(
        client: MockClient((request) async {
          headersEnviadas.add(request.headers);
          call++;
          if (call == 1) return http.Response('', 401);
          return http.Response(detailBody(id: 7), 200);
        }),
        cache: cache,
      );

      final detail = await repo.fetchArticleDetail(
        7,
        restNonce: 'viejo',
        onNonceExpired: () async => 'nuevo',
      );

      expect(detail.id, 7);
      expect(headersEnviadas.first['X-WP-Nonce'], 'viejo');
      expect(headersEnviadas.last['X-WP-Nonce'], 'nuevo');
    });

    test('no reintenta si la renovación del nonce devuelve null', () async {
      var calls = 0;
      final repo = ArticleRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 401);
        }),
        cache: cache,
      );

      expect(
        () => repo.fetchArticleDetail(7, onNonceExpired: () async => null),
        throwsException,
      );
      await settle();
      expect(calls, 1);
    });

    test('un 401 sin renovador de nonce falla directamente', () async {
      final repo = ArticleRepository(
        client: clientReturning('', status: 401),
        cache: cache,
      );

      expect(() => repo.fetchArticleDetail(7), throwsException);
    });
  });

  group('Reintentos del detalle', () {
    test('reintenta hasta tres veces ante un 503 y acaba devolviendo el dato',
        () {
      fakeAsync((async) {
        var calls = 0;
        final repo = ArticleRepository(
          client: MockClient((_) async {
            calls++;
            if (calls < 4) return http.Response('', 503);
            return http.Response(detailBody(id: 7), 200);
          }),
          cache: cache,
        );

        Object? resultado;
        repo.fetchArticleDetail(7).then((d) => resultado = d);

        // 5s + 10s + 15s de espera acumulada entre reintentos.
        async.elapse(const Duration(seconds: 40));

        expect(calls, 4);
        expect(resultado, isNotNull);
      });
    });

    test('deja de reintentar el 503 tras el cuarto intento', () {
      fakeAsync((async) {
        var calls = 0;
        final repo = ArticleRepository(
          client: MockClient((_) async {
            calls++;
            return http.Response('', 503);
          }),
          cache: cache,
        );

        Object? error;
        repo.fetchArticleDetail(7).catchError((Object e) {
          error = e;
          throw e;
        }).ignore();

        async.elapse(const Duration(seconds: 60));

        expect(calls, 4, reason: 'un intento inicial y tres reintentos');
        expect(error, isNotNull);
      });
    });

    test('reintenta dos veces ante errores de red', () {
      fakeAsync((async) {
        var calls = 0;
        final repo = ArticleRepository(
          client: MockClient((_) async {
            calls++;
            if (calls < 3) throw Exception('sin red');
            return http.Response(detailBody(id: 7), 200);
          }),
          cache: cache,
        );

        Object? resultado;
        repo.fetchArticleDetail(7).then((d) => resultado = d);

        // 2s + 4s de espera acumulada.
        async.elapse(const Duration(seconds: 10));

        expect(calls, 3);
        expect(resultado, isNotNull);
      });
    });

    test('se rinde tras tres intentos fallidos por red', () {
      fakeAsync((async) {
        var calls = 0;
        final repo = ArticleRepository(
          client: MockClient((_) async {
            calls++;
            throw Exception('sin red');
          }),
          cache: cache,
        );

        Object? error;
        repo.fetchArticleDetail(7).catchError((Object e) {
          error = e;
          throw e;
        }).ignore();

        async.elapse(const Duration(seconds: 20));

        expect(calls, 3);
        expect(error, isNotNull);
      });
    });
  });

  group('searchArticles', () {
    test('devuelve los resultados de la búsqueda', () async {
      final repo = ArticleRepository(
        client: clientReturning(articlesBody(3)),
        cache: cache,
      );

      expect(await repo.searchArticles('ucrania'), hasLength(3));
    });

    test('no consulta si la búsqueda está vacía', () async {
      final recording = RecordingClient();
      final repo = ArticleRepository(client: recording.client, cache: cache);

      expect(await repo.searchArticles(''), isEmpty);
      expect(recording.requests, isEmpty);
    });

    test('no consulta si la búsqueda es solo espacios', () async {
      final recording = RecordingClient();
      final repo = ArticleRepository(client: recording.client, cache: cache);

      expect(await repo.searchArticles('   '), isEmpty);
      expect(recording.requests, isEmpty);
    });

    test('recorta los espacios de la consulta', () async {
      final recording = RecordingClient(body: articlesBody(1));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      await repo.searchArticles('  ucrania  ');

      expect(recording.lastQuery['search'], 'ucrania');
      expect(recording.lastQuery['search_columns'], 'post_title');
    });

    test('devuelve lista vacía si el servidor responde con error', () async {
      final repo = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);

      expect(await repo.searchArticles('x'), isEmpty);
    });

    test('devuelve lista vacía ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.searchArticles('x'), isEmpty);
    });
  });

  group('Autores', () {
    test('fetchAuthorId devuelve el identificador', () async {
      final repo = ArticleRepository(
        client: clientReturning(jsonEncode([
          {'id': 2903, 'name': 'Albert Junyent Cebrián'}
        ])),
        cache: cache,
      );

      expect(await repo.fetchAuthorId('Albert Junyent Cebrián'), 2903);
    });

    test('fetchAuthorId devuelve null si no hay coincidencias', () async {
      final repo =
          ArticleRepository(client: clientReturning('[]'), cache: cache);

      expect(await repo.fetchAuthorId('Nadie'), isNull);
    });

    test('fetchAuthorId devuelve null ante un error del servidor', () async {
      final repo = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);

      expect(await repo.fetchAuthorId('x'), isNull);
    });

    test('fetchAuthorId devuelve null ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchAuthorId('x'), isNull);
    });

    test('fetchArticlesByAuthor devuelve los artículos ordenados', () async {
      final recording = RecordingClient(body: articlesBody(5));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final articles = await repo.fetchArticlesByAuthor(authorId: 2903);

      expect(articles, hasLength(5));
      expect(recording.lastQuery['author'], '2903');
      expect(recording.lastQuery['orderby'], 'date');
      expect(recording.lastQuery['order'], 'desc');
    });

    test('fetchArticlesByAuthor devuelve vacío ante un error', () async {
      final repo = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);

      expect(await repo.fetchArticlesByAuthor(authorId: 1), isEmpty);
    });

    test('fetchArticlesByAuthor devuelve vacío ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchArticlesByAuthor(authorId: 1), isEmpty);
    });

    test('fetchMoreArticlesByAuthor distingue fin real de error', () async {
      final finReal = ArticleRepository(
          client: clientReturning('', status: 400), cache: cache);
      final error = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);
      final excepcion =
          ArticleRepository(client: clientThrowing(), cache: cache);

      expect(
        await finReal.fetchMoreArticlesByAuthor(authorId: 1, page: 9),
        isEmpty,
      );
      expect(
        await error.fetchMoreArticlesByAuthor(authorId: 1, page: 2),
        isNull,
      );
      expect(
        await excepcion.fetchMoreArticlesByAuthor(authorId: 1, page: 2),
        isNull,
      );
    });

    test('fetchMoreArticlesByAuthor devuelve la página pedida', () async {
      final recording = RecordingClient(body: articlesBody(3));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final more =
          await repo.fetchMoreArticlesByAuthor(authorId: 2903, page: 2);

      expect(more, hasLength(3));
      expect(recording.lastQuery['page'], '2');
    });
  });

  group('Etiquetas', () {
    test('fetchTagId devuelve el identificador', () async {
      final repo = ArticleRepository(
        client: clientReturning(jsonEncode([
          {'id': 149, 'name': 'España'}
        ])),
        cache: cache,
      );

      expect(await repo.fetchTagId('espana'), 149);
    });

    test('fetchTagId devuelve null si no hay coincidencias', () async {
      final repo =
          ArticleRepository(client: clientReturning('[]'), cache: cache);

      expect(await repo.fetchTagId('narnia'), isNull);
    });

    test('fetchTagId devuelve null ante un error del servidor', () async {
      final repo = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);

      expect(await repo.fetchTagId('x'), isNull);
    });

    test('fetchTagId devuelve null ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchTagId('x'), isNull);
    });

    test('fetchArticlesByTag devuelve los artículos ordenados', () async {
      final recording = RecordingClient(body: articlesBody(4));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final articles = await repo.fetchArticlesByTag(tagId: 149);

      expect(articles, hasLength(4));
      expect(recording.lastQuery['tags'], '149');
      expect(recording.lastQuery['orderby'], 'date');
    });

    test('fetchArticlesByTag devuelve vacío ante un error', () async {
      final repo = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);

      expect(await repo.fetchArticlesByTag(tagId: 1), isEmpty);
    });

    test('fetchArticlesByTag devuelve vacío ante una excepción', () async {
      final repo = ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await repo.fetchArticlesByTag(tagId: 1), isEmpty);
    });

    test('fetchMoreArticlesByTag distingue fin real de error', () async {
      final finReal = ArticleRepository(
          client: clientReturning('', status: 400), cache: cache);
      final error = ArticleRepository(
          client: clientReturning('', status: 500), cache: cache);
      final excepcion =
          ArticleRepository(client: clientThrowing(), cache: cache);

      expect(await finReal.fetchMoreArticlesByTag(tagId: 1, page: 9), isEmpty);
      expect(await error.fetchMoreArticlesByTag(tagId: 1, page: 2), isNull);
      expect(await excepcion.fetchMoreArticlesByTag(tagId: 1, page: 2), isNull);
    });

    test('fetchMoreArticlesByTag devuelve la página pedida', () async {
      final recording = RecordingClient(body: articlesBody(3));
      final repo = ArticleRepository(client: recording.client, cache: cache);

      final more = await repo.fetchMoreArticlesByTag(tagId: 149, page: 3);

      expect(more, hasLength(3));
      expect(recording.lastQuery['page'], '3');
    });
  });
}
