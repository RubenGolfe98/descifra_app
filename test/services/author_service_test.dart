import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:dlg_app/services/author_service.dart';

const _prefsKey = 'dlg_authors_map';
const _prefsKeyTimestamp = 'dlg_authors_ts';

/// Almacén de preferencias en memoria que puede simular fallos de lectura
/// o de escritura.
class FakePrefsStore extends SharedPreferencesStorePlatform {
  FakePrefsStore([Map<String, Object>? initial])
      : values = {...?initial};

  final Map<String, Object> values;

  bool failOnRead = false;
  bool failOnWrite = false;

  @override
  bool get isMock => true;

  @override
  Future<Map<String, Object>> getAll() async {
    if (failOnRead) throw Exception('lectura no disponible');
    return Map<String, Object>.from(values);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failOnWrite) throw Exception('escritura no disponible');
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}

/// Instala un almacén de preferencias y descarta la instancia cacheada de
/// SharedPreferences para que la siguiente lectura use el nuevo almacén.
FakePrefsStore installStore([Map<String, Object>? initial]) {
  final store = FakePrefsStore(initial);
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  return store;
}

/// Cliente que devuelve una página distinta según el parámetro `page`.
MockClient paginatedClient(List<String> pages) {
  return MockClient((request) async {
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    if (page > pages.length) return http.Response('[]', 200);
    return http.Response(pages[page - 1], 200);
  });
}

MockClient clientReturning(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(body, status));

MockClient clientThrowing() =>
    MockClient((_) async => throw Exception('sin red'));

/// Cliente que registra si llegó a recibir alguna petición.
class SpyClient {
  bool called = false;
  late final MockClient client = MockClient((_) async {
    called = true;
    return http.Response('[]', 200);
  });
}

/// Genera un cuerpo con `count` autores, numerados desde `startId`.
String authorsBody(int count, {int startId = 1}) {
  return jsonEncode([
    for (var i = 0; i < count; i++)
      {'id': startId + i, 'name': 'Autor ${startId + i}'}
  ]);
}

/// Marca de tiempo anterior al TTL de 7 días.
int staleTimestamp() =>
    DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch;

/// Espera a que terminen los refrescos lanzados sin await.
Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // refresh() limpia el mapa y la bandera de cargado antes de intentar la
    // descarga; si esta falla, el servicio queda como recién arrancado.
    installStore();
    await AuthorService.refresh(client: clientThrowing());
  });

  group('getAuthorId', () {
    test('devuelve null cuando no hay autores cargados', () {
      expect(AuthorService.getAuthorId('Cualquiera'), isNull);
    });

    test('devuelve el id del autor tras cargarlos', () async {
      installStore();
      await AuthorService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 2903, 'name': 'Albert Junyent Cebrián'}
        ])),
      );

      expect(AuthorService.getAuthorId('Albert Junyent Cebrián'), 2903);
    });

    test('devuelve null para un nombre que no existe', () async {
      installStore();
      await AuthorService.initialize(client: clientReturning(authorsBody(3)));

      expect(AuthorService.getAuthorId('Nombre Inventado'), isNull);
    });
  });

  group('initialize sin caché previa', () {
    test('descarga los autores y los persiste', () async {
      final store = installStore();

      await AuthorService.initialize(client: clientReturning(authorsBody(5)));

      expect(AuthorService.getAuthorId('Autor 1'), 1);
      expect(AuthorService.getAuthorId('Autor 5'), 5);
      expect(store.values.containsKey('flutter.$_prefsKey'), isTrue);
      expect(store.values.containsKey('flutter.$_prefsKeyTimestamp'), isTrue);
    });

    test('pagina mientras la página venga llena', () async {
      installStore();

      await AuthorService.initialize(
        client: paginatedClient([
          authorsBody(100, startId: 1),
          authorsBody(20, startId: 101),
        ]),
      );

      expect(AuthorService.getAuthorId('Autor 1'), 1);
      expect(AuthorService.getAuthorId('Autor 120'), 120);
    });

    test('deja de paginar cuando una página responde con error', () async {
      installStore();

      await AuthorService.initialize(
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          if (page == 1) return http.Response(authorsBody(100), 200);
          return http.Response('', 500);
        }),
      );

      expect(AuthorService.getAuthorId('Autor 100'), 100);
    });

    test('no guarda nada si la primera página falla', () async {
      final store = installStore();

      await AuthorService.initialize(client: clientReturning('', status: 503));

      expect(AuthorService.getAuthorId('Autor 1'), isNull);
      expect(store.values.containsKey('flutter.$_prefsKey'), isFalse);
    });

    test('no guarda nada si la respuesta viene vacía', () async {
      final store = installStore();

      await AuthorService.initialize(client: clientReturning('[]'));

      expect(store.values.containsKey('flutter.$_prefsKey'), isFalse);
    });

    test('no falla si la petición lanza una excepción', () async {
      installStore();

      await expectLater(
        AuthorService.initialize(client: clientThrowing()),
        completes,
      );
      expect(AuthorService.getAuthorId('Autor 1'), isNull);
    });

    test('no falla si la respuesta no es JSON válido', () async {
      installStore();

      await expectLater(
        AuthorService.initialize(client: clientReturning('<html>')),
        completes,
      );
    });

    test('no falla si no se puede persistir la caché', () async {
      final store = installStore();
      store.failOnWrite = true;

      await expectLater(
        AuthorService.initialize(client: clientReturning(authorsBody(3))),
        completes,
      );

      // Los autores quedan disponibles en memoria aunque el disco falle.
      expect(AuthorService.getAuthorId('Autor 1'), 1);
    });
  });

  group('initialize con caché previa', () {
    test('carga los autores desde la caché sin pedir nada a la red', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Autor Cacheado': 77}),
        'flutter.$_prefsKeyTimestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final spy = SpyClient();

      await AuthorService.initialize(client: spy.client);

      expect(AuthorService.getAuthorId('Autor Cacheado'), 77);
      expect(spy.called, isFalse);
    });

    test('no vuelve a hacer nada si ya está cargado', () async {
      installStore();
      await AuthorService.initialize(client: clientReturning(authorsBody(2)));
      final spy = SpyClient();

      await AuthorService.initialize(client: spy.client);

      expect(spy.called, isFalse);
    });

    test('descarga de red si la caché tiene un JSON corrupto', () async {
      installStore({'flutter.$_prefsKey': 'esto no es json'});

      await AuthorService.initialize(client: clientReturning(authorsBody(2)));

      expect(AuthorService.getAuthorId('Autor 1'), 1);
    });

    test('descarga de red si no se puede leer la caché', () async {
      final store = installStore();
      store.failOnRead = true;

      await AuthorService.initialize(client: clientReturning(authorsBody(2)));

      expect(AuthorService.getAuthorId('Autor 1'), 1);
    });

    test('usa la caché aunque falte la marca de tiempo', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Sin Marca': 88}),
      });
      final spy = SpyClient();

      await AuthorService.initialize(client: spy.client);

      expect(AuthorService.getAuthorId('Sin Marca'), 88);
      expect(spy.called, isFalse);
    });
  });

  group('Refresco silencioso', () {
    test('actualiza en segundo plano cuando la caché está caducada', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 99, 'name': 'Nuevo'}
        ])),
      );

      // La caché se sirve de inmediato...
      expect(AuthorService.getAuthorId('Antiguo'), 1);

      // ...y el refresco silencioso la sustituye poco después.
      await settle();
      expect(AuthorService.getAuthorId('Nuevo'), 99);
      expect(AuthorService.getAuthorId('Antiguo'), isNull);
    });

    test('no refresca si la caché sigue vigente', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Vigente': 5}),
        'flutter.$_prefsKeyTimestamp': DateTime.now()
            .subtract(const Duration(days: 6))
            .millisecondsSinceEpoch,
      });
      final spy = SpyClient();

      await AuthorService.initialize(client: spy.client);
      await settle();

      expect(spy.called, isFalse);
      expect(AuthorService.getAuthorId('Vigente'), 5);
    });

    test('pagina también en el refresco silencioso', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(
        client: paginatedClient([
          authorsBody(100, startId: 1),
          authorsBody(10, startId: 101),
        ]),
      );
      await settle();

      expect(AuthorService.getAuthorId('Autor 110'), 110);
    });

    test('deja de paginar si una página del refresco falla', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          if (page == 1) return http.Response(authorsBody(100), 200);
          return http.Response('', 500);
        }),
      );
      await settle();

      expect(AuthorService.getAuthorId('Autor 100'), 100);
    });

    test('conserva la caché si el refresco silencioso falla', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(client: clientThrowing());
      await settle();

      expect(AuthorService.getAuthorId('Antiguo'), 1);
    });

    test('conserva la caché si el refresco responde con error', () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(client: clientReturning('', status: 500));
      await settle();

      expect(AuthorService.getAuthorId('Antiguo'), 1);
    });

    test('conserva la caché si el refresco devuelve una lista vacía',
        () async {
      installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(client: clientReturning('[]'));
      await settle();

      expect(AuthorService.getAuthorId('Antiguo'), 1);
    });

    test('no falla si el refresco no puede persistir', () async {
      final store = installStore({
        'flutter.$_prefsKey': jsonEncode({'Antiguo': 1}),
        'flutter.$_prefsKeyTimestamp': staleTimestamp(),
      });

      await AuthorService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 42, 'name': 'Nuevo'}
        ])),
      );
      store.failOnWrite = true;
      await settle();

      expect(AuthorService.getAuthorId('Nuevo'), 42);
    });
  });

  group('refresh', () {
    test('vuelve a descargar aunque ya estuviera cargado', () async {
      installStore();
      await AuthorService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 1, 'name': 'Primero'}
        ])),
      );
      expect(AuthorService.getAuthorId('Primero'), 1);

      await AuthorService.refresh(
        client: clientReturning(jsonEncode([
          {'id': 2, 'name': 'Segundo'}
        ])),
      );

      expect(AuthorService.getAuthorId('Segundo'), 2);
      expect(AuthorService.getAuthorId('Primero'), isNull);
    });

    test('deja el servicio vacío si la descarga falla', () async {
      installStore();
      await AuthorService.initialize(client: clientReturning(authorsBody(2)));

      await AuthorService.refresh(client: clientThrowing());

      expect(AuthorService.getAuthorId('Autor 1'), isNull);
    });
  });
}
