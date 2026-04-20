import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlg_app/services/favorites_service.dart';

// Respuesta del servidor con favoritos
final _favoritesWithPosts = jsonEncode({
  'status': 'success',
  'favorites': [
    {
      'groups': [{'group_id': 1, 'group_name': 'Lista por defecto'}],
      'posts': [
        {
          'post_id': 42,
          'title': 'Artículo guardado',
          'permalink': 'https://www.descifrandolaguerra.es/articulo-guardado/',
          'thumbnails': {'medium': '<img src="https://example.com/img.jpg" />'},
        }
      ],
      'site_id': 1,
    }
  ],
});

// Respuesta vacía
final _favoritesEmpty = jsonEncode({
  'status': 'success',
  'favorites': [
    {'groups': [], 'posts': [], 'site_id': 1}
  ],
});

// Respuesta como List directa (formato alternativo del servidor)
final _favoritesAsList = jsonEncode([
  {
    'posts': [
      {
        'post_id': 99,
        'title': 'Artículo lista',
        'permalink': 'https://www.descifrandolaguerra.es/lista/',
        'thumbnails': {},
      }
    ],
  }
]);

http.Client _mock(String body, {int statusCode = 200}) =>
    MockClient((_) async => http.Response(body, statusCode));

void main() {
  group('FavoritesService - loadFavorites', () {
    test('carga favoritos correctamente desde respuesta Map', () async {
      final service = FavoritesService(client: _mock(_favoritesWithPosts));
      await service.loadFavorites('cookies=test');
      expect(service.loaded, true);
      expect(service.savedIds.contains(42), true);
      expect(service.savedArticles.length, 1);
      expect(service.savedArticles.first.title, 'Artículo guardado');
    });

    test('no falla con posts vacíos', () async {
      final service = FavoritesService(client: _mock(_favoritesEmpty));
      await service.loadFavorites('cookies=test');
      expect(service.loaded, true);
      expect(service.savedIds, isEmpty);
    });

    test('maneja respuesta como List directa', () async {
      final service = FavoritesService(client: _mock(_favoritesAsList));
      await service.loadFavorites('cookies=test');
      expect(service.loaded, true);
      expect(service.savedIds.contains(99), true);
    });

    test('no falla en error de red', () async {
      final service = FavoritesService(
        client: MockClient((_) async => throw Exception('error')),
      );
      await service.loadFavorites('cookies=test');
      expect(service.loaded, true);
      expect(service.savedIds, isEmpty);
    });

    test('no falla en respuesta no-200', () async {
      final service = FavoritesService(client: _mock('error', statusCode: 500));
      await service.loadFavorites('cookies=test');
      expect(service.loaded, true);
    });
  });

  group('FavoritesService - isSaved', () {
    test('devuelve false para IDs no guardados', () async {
      final service = FavoritesService(client: _mock(_favoritesEmpty));
      await service.loadFavorites('cookies=test');
      expect(service.isSaved(1), false);
    });

    test('devuelve true para IDs guardados', () async {
      final service = FavoritesService(client: _mock(_favoritesWithPosts));
      await service.loadFavorites('cookies=test');
      expect(service.isSaved(42), true);
    });
  });

  group('FavoritesService - toggleFavorite', () {
    test('optimistic update añade ID inmediatamente', () async {
      bool toggleDone = false;
      final service = FavoritesService(
        client: MockClient((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          toggleDone = true;
          return http.Response(jsonEncode({'status': 'success', 'favorites': [{'posts': [], 'groups': []}]}), 200);
        }),
      );
      final future = service.toggleFavorite(10, 'cookies=test');
      // Antes de que termine, el ID ya está en el set (optimistic)
      expect(service.savedIds.contains(10), true);
      await future;
      expect(toggleDone, true);
    });

    test('revierte si falla la petición', () async {
      final service = FavoritesService(
        client: MockClient((_) async => throw Exception('error')),
      );
      final result = await service.toggleFavorite(10, 'cookies=test');
      expect(result, false);
      expect(service.savedIds.contains(10), false); // revertido
    });
  });

  group('FavoritesService - clear', () {
    test('limpia todos los datos', () async {
      final service = FavoritesService(client: _mock(_favoritesWithPosts));
      await service.loadFavorites('cookies=test');
      expect(service.savedIds, isNotEmpty);
      service.clear();
      expect(service.savedIds, isEmpty);
      expect(service.savedArticles, isEmpty);
      expect(service.loaded, false);
    });
  });

  group('FavoritesService - slug desde permalink', () {
    test('extrae slug correctamente', () async {
      final service = FavoritesService(client: _mock(_favoritesWithPosts));
      await service.loadFavorites('cookies=test');
      expect(service.savedArticles.first.slug, 'articulo-guardado');
    });
  });
}
