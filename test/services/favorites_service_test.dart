import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dlg_app/services/favorites_service.dart';

/// Cliente falso que siempre devuelve la misma respuesta.
MockClient clientReturning(String body, {int status = 200}) {
  return MockClient((request) async => http.Response(body, status));
}

/// Cliente falso que lanza una excepción al hacer la petición.
MockClient clientThrowing() {
  return MockClient((request) async => throw Exception('sin red'));
}

/// Respuesta con la forma habitual del plugin: Map con status y favorites.
String favoritesMapBody(dynamic posts) => jsonEncode({
      'status': 'success',
      'favorites': [
        {
          'groups': [
            {'group_id': 1, 'site_id': 1, 'group_name': 'Lista por defecto'}
          ],
          'posts': posts,
          'site_id': 1,
        }
      ],
    });

/// Entrada de post tal y como la devuelve el servidor.
Map<String, dynamic> postEntry({
  int? id = 100,
  String title = 'Titular de prueba',
  String permalink = 'https://www.descifrandolaguerra.es/un-articulo/',
  String? thumbnail =
      '<img src="https://www.descifrandolaguerra.es/imagen-300x200.jpg" />',
}) {
  return {
    if (id != null) 'post_id': id,
    'post_type': 'post',
    'title': title,
    'permalink': permalink,
    if (thumbnail != null) 'thumbnails': {'medium': thumbnail},
  };
}

void main() {
  // Necesario para que las peticiones HTTP reales de toggleFavorite queden
  // interceptadas por el entorno de test en lugar de salir a la red.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Estado inicial', () {
    test('arranca vacío y sin marcar como cargado', () {
      final service = FavoritesService(client: clientReturning('[]'));

      expect(service.savedIds, isEmpty);
      expect(service.savedArticles, isEmpty);
      expect(service.loaded, isFalse);
      expect(service.isSaved(1), isFalse);
    });

    test('savedIds y savedArticles son colecciones inmutables', () {
      final service = FavoritesService(client: clientReturning('[]'));

      expect(() => service.savedIds.add(1), throwsUnsupportedError);
      expect(() => service.savedArticles.clear(), throwsUnsupportedError);
    });
  });

  group('loadFavorites', () {
    test('parsea la respuesta con posts como lista', () async {
      final service = FavoritesService(
        client: clientReturning(favoritesMapBody([postEntry(id: 501)])),
      );

      await service.loadFavorites('cookie=valor');

      expect(service.loaded, isTrue);
      expect(service.savedIds, {501});
      expect(service.savedArticles.single.id, 501);
    });

    test('parsea la respuesta con posts como objeto indexado', () async {
      final service = FavoritesService(
        client: clientReturning(favoritesMapBody({
          '502': postEntry(id: 502),
          '503': postEntry(id: 503),
        })),
      );

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, {502, 503});
      expect(service.savedArticles, hasLength(2));
    });

    test('parsea una respuesta que llega como lista directa', () async {
      final body = jsonEncode([
        {
          'posts': [postEntry(id: 504)],
          'site_id': 1,
        }
      ]);
      final service = FavoritesService(client: clientReturning(body));

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, {504});
    });

    test('lista directa con posts como objeto indexado', () async {
      final body = jsonEncode([
        {
          'posts': {'505': postEntry(id: 505)},
        }
      ]);
      final service = FavoritesService(client: clientReturning(body));

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, {505});
    });

    test('ignora la respuesta si el status no es success', () async {
      final body = jsonEncode({
        'status': 'error',
        'favorites': [
          {
            'posts': [postEntry(id: 506)]
          }
        ],
      });
      final service = FavoritesService(client: clientReturning(body));

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, isEmpty);
      expect(service.loaded, isTrue);
    });

    test('no falla cuando el servidor responde con un código de error',
        () async {
      final service =
          FavoritesService(client: clientReturning('', status: 500));

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, isEmpty);
      expect(service.loaded, isTrue);
    });

    test('no falla cuando la petición lanza una excepción', () async {
      final service = FavoritesService(client: clientThrowing());

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, isEmpty);
      expect(service.loaded, isTrue);
    });

    test('no falla con un cuerpo que no es JSON válido', () async {
      final service = FavoritesService(client: clientReturning('<html>'));

      await service.loadFavorites('cookie=valor');

      expect(service.loaded, isTrue);
    });

    test('maneja respuestas largas al recortar el log', () async {
      final longTitle = 'x' * 500;
      final service = FavoritesService(
        client: clientReturning(
          favoritesMapBody([postEntry(id: 507, title: longTitle)]),
        ),
      );

      await service.loadFavorites('cookie=valor');

      expect(service.savedIds, {507});
    });

    test('notifica a los oyentes al terminar', () async {
      final service = FavoritesService(client: clientReturning('[]'));
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.loadFavorites('cookie=valor');

      expect(notifications, greaterThan(0));
    });

    test('envía las cookies y el action correctos', () async {
      String? sentCookie;
      String? sentBody;
      final service = FavoritesService(
        client: MockClient((request) async {
          sentCookie = request.headers['Cookie'];
          sentBody = request.body;
          return http.Response(favoritesMapBody(<dynamic>[]), 200);
        }),
      );

      await service.loadFavorites('wordpress_logged_in=abc');

      expect(sentCookie, 'wordpress_logged_in=abc');
      expect(sentBody, 'action=favorites_array');
    });
  });

  group('Parseo de favoritos', () {
    Future<FavoritesService> loadWith(String body) async {
      final service = FavoritesService(client: clientReturning(body));
      await service.loadFavorites('cookie=valor');
      return service;
    }

    test('favorites nulo deja la lista vacía', () async {
      final service = await loadWith(
        jsonEncode({'status': 'success', 'favorites': null}),
      );

      expect(service.savedIds, isEmpty);
    });

    test('favorites vacío deja la lista vacía', () async {
      final service = await loadWith(favoritesMapBody(<dynamic>[]));

      expect(service.savedIds, isEmpty);
    });

    test('lista de favoritos vacía deja la lista vacía', () async {
      final service = await loadWith(
        jsonEncode({'status': 'success', 'favorites': <dynamic>[]}),
      );

      expect(service.savedIds, isEmpty);
    });

    test('primer elemento nulo deja la lista vacía', () async {
      final service = await loadWith(
        jsonEncode({
          'status': 'success',
          'favorites': [null]
        }),
      );

      expect(service.savedIds, isEmpty);
    });

    test('posts nulo deja la lista vacía', () async {
      final service = await loadWith(
        jsonEncode({
          'status': 'success',
          'favorites': [
            {'site_id': 1}
          ],
        }),
      );

      expect(service.savedIds, isEmpty);
    });

    test('ignora entradas de posts que no son objetos', () async {
      final service = await loadWith(
        favoritesMapBody(['texto suelto', 42, postEntry(id: 508)]),
      );

      expect(service.savedIds, {508});
    });

    test('ignora valores no objeto en posts indexado', () async {
      final service = await loadWith(
        favoritesMapBody({'a': 'texto', 'b': postEntry(id: 509)}),
      );

      expect(service.savedIds, {509});
    });

    test('lista directa vacía deja la lista vacía', () async {
      final service = await loadWith(jsonEncode(<dynamic>[]));

      expect(service.savedIds, isEmpty);
    });

    test('lista directa cuyo primer elemento no es un mapa', () async {
      final service = await loadWith(jsonEncode(['texto']));

      expect(service.savedIds, isEmpty);
    });

    test('lista directa sin campo posts', () async {
      final service = await loadWith(
        jsonEncode([
          {'site_id': 1}
        ]),
      );

      expect(service.savedIds, isEmpty);
    });

    test('lista directa con entradas no objeto en posts', () async {
      final service = await loadWith(
        jsonEncode([
          {
            'posts': ['texto', postEntry(id: 510)]
          }
        ]),
      );

      expect(service.savedIds, {510});
    });

    test('lista directa con valores no objeto en posts indexado', () async {
      final service = await loadWith(
        jsonEncode([
          {
            'posts': {'a': 'texto', 'b': postEntry(id: 511)}
          }
        ]),
      );

      expect(service.savedIds, {511});
    });
  });

  group('Parseo de cada artículo', () {
    Future<FavoritesService> loadWithPost(Map<String, dynamic> entry) async {
      final service =
          FavoritesService(client: clientReturning(favoritesMapBody([entry])));
      await service.loadFavorites('cookie=valor');
      return service;
    }

    test('descarta entradas sin post_id', () async {
      final service = await loadWithPost(postEntry(id: null));

      expect(service.savedIds, isEmpty);
      expect(service.savedArticles, isEmpty);
    });

    test('extrae la imagen del HTML de la miniatura', () async {
      final service = await loadWithPost(postEntry(
        id: 601,
        thumbnail: '<img width="300" src="https://ejemplo.es/foto.jpg" />',
      ));

      expect(
          service.savedArticles.single.imageUrl, 'https://ejemplo.es/foto.jpg');
    });

    test('deja la imagen vacía si no hay miniatura', () async {
      final service = await loadWithPost(postEntry(id: 602, thumbnail: null));

      expect(service.savedArticles.single.imageUrl, '');
    });

    test('deja la imagen vacía si el HTML no contiene src', () async {
      final service =
          await loadWithPost(postEntry(id: 603, thumbnail: '<img alt="x" />'));

      expect(service.savedArticles.single.imageUrl, '');
    });

    test('decodifica los puntos suspensivos y el apóstrofo', () async {
      final service = await loadWithPost(postEntry(
        id: 604,
        title: 'Rusia&#8217;s frontera&#8230;',
      ));

      expect(service.savedArticles.single.title, 'Rusia\u2019s frontera…');
    });

    test('elimina el resto de entidades numéricas del título', () async {
      final service =
          await loadWithPost(postEntry(id: 605, title: 'Guerra&#8211;paz'));

      expect(service.savedArticles.single.title, 'Guerrapaz');
    });

    test('extrae el slug del último segmento del permalink', () async {
      final service = await loadWithPost(postEntry(
        id: 606,
        permalink: 'https://www.descifrandolaguerra.es/analisis/mi-articulo/',
      ));

      expect(service.savedArticles.single.slug, 'mi-articulo');
    });

    test('deja el slug vacío si el permalink no tiene segmentos', () async {
      final service = await loadWithPost(
        postEntry(id: 607, permalink: 'https://www.descifrandolaguerra.es/'),
      );

      expect(service.savedArticles.single.slug, '');
    });

    test('deja el slug vacío si no hay permalink', () async {
      final entry = postEntry(id: 608)..remove('permalink');
      final service = await loadWithPost(entry);

      expect(service.savedArticles.single.slug, '');
    });

    test('deja el título vacío si no viene en la respuesta', () async {
      final entry = postEntry(id: 609)..remove('title');
      final service = await loadWithPost(entry);

      expect(service.savedArticles.single.title, '');
    });

    test('los artículos guardados no se marcan como premium', () async {
      final service = await loadWithPost(postEntry(id: 610));

      expect(service.savedArticles.single.isPremium, isFalse);
      expect(service.savedArticles.single.author, '');
      expect(service.savedArticles.single.description, '');
    });
  });

  // ─── toggleFavorite ─────────────────────────────────────────────────────────
  // Este método usa SharedHttp.userClient directamente, así que no admite un
  // cliente falso. En el entorno de test las peticiones HTTP reales se
  // interceptan y devuelven 400, lo que permite cubrir la actualización
  // optimista y las rutas de reversión, pero no los caminos de éxito.
  group('toggleFavorite', () {
    test('marca el artículo antes de recibir respuesta y revierte al fallar',
        () async {
      final service = FavoritesService(client: clientReturning('[]'));

      var sawOptimisticSave = false;
      service.addListener(() {
        if (service.isSaved(701)) sawOptimisticSave = true;
      });

      final result = await service.toggleFavorite(701, 'cookie=valor');

      expect(sawOptimisticSave, isTrue,
          reason: 'debe marcarse como guardado antes de la respuesta');
      expect(result, isFalse);
      expect(service.isSaved(701), isFalse,
          reason: 'debe revertirse al fallar la petición');
    });

    test('quita el artículo de inmediato y lo restaura al fallar', () async {
      final service = FavoritesService(
        client: clientReturning(favoritesMapBody([postEntry(id: 702)])),
      );
      await service.loadFavorites('cookie=valor');
      expect(service.isSaved(702), isTrue);

      var sawOptimisticRemove = false;
      service.addListener(() {
        if (!service.isSaved(702)) sawOptimisticRemove = true;
      });

      final result = await service.toggleFavorite(702, 'cookie=valor');

      expect(sawOptimisticRemove, isTrue,
          reason: 'debe desmarcarse antes de la respuesta');
      expect(result, isFalse);
      expect(service.isSaved(702), isTrue,
          reason: 'debe restaurarse al fallar la petición');
    });

    test('la baja optimista también retira el artículo de la lista', () async {
      final service = FavoritesService(
        client: clientReturning(favoritesMapBody([postEntry(id: 703)])),
      );
      await service.loadFavorites('cookie=valor');
      expect(service.savedArticles, hasLength(1));

      await service.toggleFavorite(703, 'cookie=valor');

      // El id se restaura al fallar, pero el artículo completo ya no está:
      // se recuperará en la siguiente carga desde el servidor.
      expect(service.isSaved(703), isTrue);
      expect(service.savedArticles, isEmpty);
    });

    test('notifica al menos dos veces: optimista y reversión', () async {
      final service = FavoritesService(client: clientReturning('[]'));
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.toggleFavorite(704, 'cookie=valor');

      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('no deja el estado a medias tras varios intentos fallidos', () async {
      final service = FavoritesService(client: clientReturning('[]'));

      await service.toggleFavorite(705, 'cookie=valor');
      await service.toggleFavorite(705, 'cookie=valor');
      await service.toggleFavorite(706, 'cookie=valor');

      expect(service.savedIds, isEmpty);
    });
  });

  group('clear', () {
    test('vacía el estado y lo marca como no cargado', () async {
      final service = FavoritesService(
        client: clientReturning(favoritesMapBody([postEntry(id: 801)])),
      );
      await service.loadFavorites('cookie=valor');
      expect(service.savedIds, isNotEmpty);

      service.clear();

      expect(service.savedIds, isEmpty);
      expect(service.savedArticles, isEmpty);
      expect(service.loaded, isFalse);
    });

    test('notifica a los oyentes', () {
      final service = FavoritesService(client: clientReturning('[]'));
      var notified = false;
      service.addListener(() => notified = true);

      service.clear();

      expect(notified, isTrue);
    });
  });
}
