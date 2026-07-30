import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:dlg_app/services/tag_service.dart';

const _keyNames = 'flutter.dlg_tags_map';
const _keyIds = 'flutter.dlg_tags_ids';
const _keyTimestamp = 'flutter.dlg_tags_ts';

/// Almacén de preferencias en memoria que puede simular fallos de lectura
/// o de escritura.
class FakePrefsStore extends SharedPreferencesStorePlatform {
  FakePrefsStore([Map<String, Object>? initial]) : values = {...?initial};

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

MockClient clientReturning(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(body, status));

MockClient clientThrowing() =>
    MockClient((_) async => throw Exception('sin red'));

/// Cliente que devuelve una página distinta según el parámetro `page`.
MockClient paginatedClient(List<String> pages) {
  return MockClient((request) async {
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    if (page > pages.length) return http.Response('[]', 200);
    return http.Response(pages[page - 1], 200);
  });
}

/// Cliente que registra si llegó a recibir alguna petición.
class SpyClient {
  bool called = false;
  late final MockClient client = MockClient((_) async {
    called = true;
    return http.Response('[]', 200);
  });
}

/// Genera un cuerpo con `count` tags, numerados desde `startId`.
String tagsBody(int count, {int startId = 1}) {
  return jsonEncode([
    for (var i = 0; i < count; i++)
      {
        'id': startId + i,
        'slug': 'tag-slug-${startId + i}',
        'name': 'Tag ${startId + i}',
      }
  ]);
}

/// Caché ya poblada, tal y como quedaría tras una descarga previa.
Map<String, Object> cachedTags({
  Map<String, String> names = const {'espana': 'España'},
  Map<String, int> ids = const {'espana': 149},
  int? timestamp,
}) {
  return {
    _keyNames: jsonEncode(names),
    _keyIds: jsonEncode(ids),
    if (timestamp != null) _keyTimestamp: timestamp,
  };
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
    // refresh() limpia los mapas y la bandera de cargado antes de intentar la
    // descarga; si esta falla, el servicio queda como recién arrancado.
    installStore();
    await TagService.refresh(client: clientThrowing());
  });

  group('getTagName', () {
    test('devuelve null si la entrada no empieza por "tag-"', () {
      expect(TagService.getTagName('category-analisis'), isNull);
    });

    test('devuelve null si el slug no está cargado', () {
      expect(TagService.getTagName('tag-espana'), isNull);
    });

    test('devuelve el nombre bonito del slug', () async {
      installStore(cachedTags());
      await TagService.initialize(client: clientThrowing());

      expect(TagService.getTagName('tag-espana'), 'España');
    });

    test('devuelve null para un slug desconocido aunque haya tags', () async {
      installStore(cachedTags());
      await TagService.initialize(client: clientThrowing());

      expect(TagService.getTagName('tag-narnia'), isNull);
    });

    test('acepta un slug vacío tras el prefijo', () {
      expect(TagService.getTagName('tag-'), isNull);
    });
  });

  group('getTagId', () {
    test('devuelve null cuando no hay nada cargado', () {
      expect(TagService.getTagId('espana'), isNull);
    });

    test('devuelve el id de WordPress del slug', () async {
      installStore(cachedTags());
      await TagService.initialize(client: clientThrowing());

      expect(TagService.getTagId('espana'), 149);
    });

    test('devuelve null para un slug desconocido', () async {
      installStore(cachedTags());
      await TagService.initialize(client: clientThrowing());

      expect(TagService.getTagId('narnia'), isNull);
    });
  });

  group('getTagNames', () {
    test('devuelve una lista vacía para un class_list vacío', () {
      expect(TagService.getTagNames([]), isEmpty);
    });

    test('extrae solo los tags conocidos del class_list', () async {
      installStore(cachedTags(
        names: {'espana': 'España', 'iran': 'Irán'},
        ids: {'espana': 149, 'iran': 200},
      ));
      await TagService.initialize(client: clientThrowing());

      final names = TagService.getTagNames([
        'post-63684',
        'category-entrevistas',
        'tag-espana',
        'tag-iran',
        'region-europa',
      ]);

      expect(names, ['España', 'Irán']);
    });

    test('descarta los tags que no están en la caché', () async {
      installStore(cachedTags());
      await TagService.initialize(client: clientThrowing());

      final names = TagService.getTagNames(['tag-espana', 'tag-desconocido']);

      expect(names, ['España']);
    });

    test('devuelve vacío si ninguna entrada es un tag', () async {
      installStore(cachedTags());
      await TagService.initialize(client: clientThrowing());

      expect(
        TagService.getTagNames(['post-1', 'category-noticias', 'hentry']),
        isEmpty,
      );
    });
  });

  group('initialize sin caché previa', () {
    test('descarga los tags y los persiste', () async {
      final store = installStore();

      await TagService.initialize(client: clientReturning(tagsBody(5)));

      expect(TagService.getTagName('tag-tag-slug-1'), 'Tag 1');
      expect(TagService.getTagId('tag-slug-5'), 5);
      expect(store.values.containsKey(_keyNames), isTrue);
      expect(store.values.containsKey(_keyIds), isTrue);
      expect(store.values.containsKey(_keyTimestamp), isTrue);
    });

    test('pagina mientras la página venga llena', () async {
      installStore();

      await TagService.initialize(
        client: paginatedClient([
          tagsBody(100, startId: 1),
          tagsBody(22, startId: 101),
        ]),
      );

      expect(TagService.getTagId('tag-slug-1'), 1);
      expect(TagService.getTagId('tag-slug-122'), 122);
    });

    test('deja de paginar cuando una página responde con error', () async {
      installStore();

      await TagService.initialize(
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          if (page == 1) return http.Response(tagsBody(100), 200);
          return http.Response('', 500);
        }),
      );

      expect(TagService.getTagId('tag-slug-100'), 100);
    });

    test('no guarda nada si la primera página falla', () async {
      final store = installStore();

      await TagService.initialize(client: clientReturning('', status: 503));

      expect(TagService.getTagId('tag-slug-1'), isNull);
      expect(store.values.containsKey(_keyNames), isFalse);
    });

    test('no guarda nada si la respuesta viene vacía', () async {
      final store = installStore();

      await TagService.initialize(client: clientReturning('[]'));

      expect(store.values.containsKey(_keyNames), isFalse);
    });

    test('no falla si la petición lanza una excepción', () async {
      installStore();

      await expectLater(
        TagService.initialize(client: clientThrowing()),
        completes,
      );
      expect(TagService.getTagId('tag-slug-1'), isNull);
    });

    test('no falla si la respuesta no es JSON válido', () async {
      installStore();

      await expectLater(
        TagService.initialize(client: clientReturning('<html>')),
        completes,
      );
    });

    test('no falla si no se puede persistir la caché', () async {
      final store = installStore();
      store.failOnWrite = true;

      await expectLater(
        TagService.initialize(client: clientReturning(tagsBody(3))),
        completes,
      );

      // Los tags quedan disponibles en memoria aunque el disco falle.
      expect(TagService.getTagId('tag-slug-1'), 1);
    });
  });

  group('initialize con caché previa', () {
    test('carga los tags desde la caché sin pedir nada a la red', () async {
      installStore(cachedTags(
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      final spy = SpyClient();

      await TagService.initialize(client: spy.client);

      expect(TagService.getTagName('tag-espana'), 'España');
      expect(TagService.getTagId('espana'), 149);
      expect(spy.called, isFalse);
    });

    test('no vuelve a hacer nada si ya está cargado', () async {
      installStore();
      await TagService.initialize(client: clientReturning(tagsBody(2)));
      final spy = SpyClient();

      await TagService.initialize(client: spy.client);

      expect(spy.called, isFalse);
    });

    test('descarga de red si falta el mapa de nombres', () async {
      installStore({_keyIds: jsonEncode({'espana': 149})});

      await TagService.initialize(client: clientReturning(tagsBody(2)));

      expect(TagService.getTagId('tag-slug-1'), 1);
    });

    test('descarga de red si falta el mapa de ids', () async {
      installStore({_keyNames: jsonEncode({'espana': 'España'})});

      await TagService.initialize(client: clientReturning(tagsBody(2)));

      expect(TagService.getTagId('tag-slug-1'), 1);
    });

    test('descarga de red si la caché tiene un JSON corrupto', () async {
      installStore({
        _keyNames: 'esto no es json',
        _keyIds: jsonEncode({'espana': 149}),
      });

      await TagService.initialize(client: clientReturning(tagsBody(2)));

      expect(TagService.getTagId('tag-slug-1'), 1);
    });

    test('descarga de red si no se puede leer la caché', () async {
      final store = installStore();
      store.failOnRead = true;

      await TagService.initialize(client: clientReturning(tagsBody(2)));

      expect(TagService.getTagId('tag-slug-1'), 1);
    });

    test('usa la caché aunque falte la marca de tiempo', () async {
      installStore(cachedTags());
      final spy = SpyClient();

      await TagService.initialize(client: spy.client);

      expect(TagService.getTagName('tag-espana'), 'España');
      expect(spy.called, isFalse);
    });
  });

  group('Refresco silencioso', () {
    test('actualiza en segundo plano cuando la caché está caducada', () async {
      installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 99, 'slug': 'nuevo', 'name': 'Nuevo'}
        ])),
      );

      // La caché se sirve de inmediato...
      expect(TagService.getTagName('tag-espana'), 'España');

      // ...y el refresco silencioso la sustituye poco después.
      await settle();
      expect(TagService.getTagName('tag-nuevo'), 'Nuevo');
      expect(TagService.getTagId('nuevo'), 99);
      expect(TagService.getTagName('tag-espana'), isNull);
    });

    test('no refresca si la caché sigue vigente', () async {
      installStore(cachedTags(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 6))
            .millisecondsSinceEpoch,
      ));
      final spy = SpyClient();

      await TagService.initialize(client: spy.client);
      await settle();

      expect(spy.called, isFalse);
      expect(TagService.getTagName('tag-espana'), 'España');
    });

    test('pagina también en el refresco silencioso', () async {
      installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(
        client: paginatedClient([
          tagsBody(100, startId: 1),
          tagsBody(10, startId: 101),
        ]),
      );
      await settle();

      expect(TagService.getTagId('tag-slug-110'), 110);
    });

    test('deja de paginar si una página del refresco falla', () async {
      installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(
        client: MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          if (page == 1) return http.Response(tagsBody(100), 200);
          return http.Response('', 500);
        }),
      );
      await settle();

      expect(TagService.getTagId('tag-slug-100'), 100);
    });

    test('conserva la caché si el refresco silencioso falla', () async {
      installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(client: clientThrowing());
      await settle();

      expect(TagService.getTagName('tag-espana'), 'España');
    });

    test('conserva la caché si el refresco responde con error', () async {
      installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(client: clientReturning('', status: 500));
      await settle();

      expect(TagService.getTagName('tag-espana'), 'España');
    });

    test('conserva la caché si el refresco devuelve una lista vacía',
        () async {
      installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(client: clientReturning('[]'));
      await settle();

      expect(TagService.getTagName('tag-espana'), 'España');
    });

    test('no falla si el refresco no puede persistir', () async {
      final store = installStore(cachedTags(timestamp: staleTimestamp()));

      await TagService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 42, 'slug': 'nuevo', 'name': 'Nuevo'}
        ])),
      );
      store.failOnWrite = true;
      await settle();

      expect(TagService.getTagId('nuevo'), 42);
    });
  });

  group('refresh', () {
    test('vuelve a descargar aunque ya estuviera cargado', () async {
      installStore();
      await TagService.initialize(
        client: clientReturning(jsonEncode([
          {'id': 1, 'slug': 'primero', 'name': 'Primero'}
        ])),
      );
      expect(TagService.getTagId('primero'), 1);

      await TagService.refresh(
        client: clientReturning(jsonEncode([
          {'id': 2, 'slug': 'segundo', 'name': 'Segundo'}
        ])),
      );

      expect(TagService.getTagId('segundo'), 2);
      expect(TagService.getTagId('primero'), isNull);
      expect(TagService.getTagName('tag-primero'), isNull);
    });

    test('deja el servicio vacío si la descarga falla', () async {
      installStore();
      await TagService.initialize(client: clientReturning(tagsBody(2)));

      await TagService.refresh(client: clientThrowing());

      expect(TagService.getTagId('tag-slug-1'), isNull);
      expect(TagService.getTagName('tag-tag-slug-1'), isNull);
    });
  });
}
