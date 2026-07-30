import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:dlg_app/services/article_cache.dart';

/// Implementación falsa de path_provider que devuelve un directorio temporal
/// controlado por el test.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.cachePath);

  final String cachePath;

  @override
  Future<String?> getApplicationCachePath() async => cachePath;

  @override
  Future<String?> getTemporaryPath() async => cachePath;

  @override
  Future<String?> getApplicationSupportPath() async => cachePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => cachePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  /// Contador para generar claves únicas por test. Es necesario porque la
  /// caché en memoria de ArticleCache es estática y persiste entre tests.
  var keySeed = 0;
  String uniqueKey(String prefix) => '${prefix}_${keySeed++}';

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('dlg_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Escribe una entrada directamente en disco con un timestamp arbitrario,
  /// para poder simular contenido caducado sin esperar.
  Future<void> writeRawEntry(
    String key,
    String data, {
    required int timestamp,
    bool restricted = false,
  }) async {
    final safe = key.replaceAll(RegExp(r'[^\w-]'), '_');
    final file = File('${tempDir.path}/dlg_$safe.json');
    await file.writeAsString(
      jsonEncode({'d': data, 't': timestamp, 'r': restricted}),
    );
  }

  int minutesAgo(int minutes) => DateTime.now()
      .subtract(Duration(minutes: minutes))
      .millisecondsSinceEpoch;

  group('Listados', () {
    test('guarda y recupera un listado con la clave por defecto', () async {
      final cache = ArticleCache();
      await cache.saveList('["articulo"]');

      expect(await cache.getList(), '["articulo"]');
    });

    test('guarda y recupera un listado con clave personalizada', () async {
      final cache = ArticleCache();
      final key = uniqueKey('articles_analysis');
      await cache.saveList('["analisis"]', key: key);

      expect(await cache.getList(key: key), '["analisis"]');
    });

    test('devuelve null cuando la clave no existe', () async {
      final cache = ArticleCache();

      expect(await cache.getList(key: uniqueKey('inexistente')), isNull);
    });

    test('isListStale es true cuando no hay nada cacheado', () async {
      final cache = ArticleCache();

      expect(await cache.isListStale(key: uniqueKey('vacio')), isTrue);
    });

    test('isListStale es false justo después de guardar', () async {
      final cache = ArticleCache();
      final key = uniqueKey('reciente');
      await cache.saveList('["fresco"]', key: key);

      expect(await cache.isListStale(key: key), isFalse);
    });

    test('isListStale es true pasadas más de 2 horas', () async {
      final cache = ArticleCache();
      final key = uniqueKey('caducado');
      await writeRawEntry(key, '["viejo"]', timestamp: minutesAgo(121));

      expect(await cache.isListStale(key: key), isTrue);
    });

    test('isListStale es false dentro del TTL de 2 horas', () async {
      final cache = ArticleCache();
      final key = uniqueKey('en_ttl');
      await writeRawEntry(key, '["vigente"]', timestamp: minutesAgo(119));

      expect(await cache.isListStale(key: key), isFalse);
    });
  });

  group('Detalles', () {
    test('guarda y recupera el detalle de un artículo', () async {
      final cache = ArticleCache();
      await cache.saveDetail(1001, '{"id":1001}');

      expect(await cache.getDetail(1001), '{"id":1001}');
    });

    test('devuelve null para un detalle no cacheado', () async {
      final cache = ArticleCache();

      expect(await cache.getDetail(999999), isNull);
    });

    test('isDetailStale es true cuando no hay nada cacheado', () async {
      final cache = ArticleCache();

      expect(await cache.isDetailStale(999998), isTrue);
    });

    test('isDetailStale es false justo después de guardar', () async {
      final cache = ArticleCache();
      await cache.saveDetail(1002, '{"id":1002}');

      expect(await cache.isDetailStale(1002), isFalse);
    });

    test('isDetailStale es true pasadas más de 24 horas', () async {
      final cache = ArticleCache();
      await writeRawEntry('detail_1003', '{"id":1003}',
          timestamp: minutesAgo(1441));

      expect(await cache.isDetailStale(1003), isTrue);
    });

    test('guarda el detalle marcado como premium', () async {
      final cache = ArticleCache();
      await cache.saveDetail(1004, '{"id":1004}', isPremium: true);

      expect(await cache.getDetail(1004), '{"id":1004}');
    });
  });

  group('Búsquedas', () {
    test('guarda y recupera una búsqueda dentro del TTL', () async {
      final cache = ArticleCache();
      await cache.saveSearch('ucrania', '["resultado"]');

      expect(await cache.getSearch('ucrania'), '["resultado"]');
    });

    test('devuelve null para una búsqueda no cacheada', () async {
      final cache = ArticleCache();

      expect(await cache.getSearch('consulta-sin-cachear'), isNull);
    });

    test('devuelve null cuando la búsqueda ha caducado', () async {
      final cache = ArticleCache();
      const query = 'consulta-caducada';
      await writeRawEntry('search_${query.hashCode}', '["antiguo"]',
          timestamp: minutesAgo(16));

      expect(await cache.getSearch(query), isNull);
    });

    test('devuelve el dato cuando la búsqueda sigue vigente', () async {
      final cache = ArticleCache();
      const query = 'consulta-vigente';
      await writeRawEntry('search_${query.hashCode}', '["vigente"]',
          timestamp: minutesAgo(14));

      expect(await cache.getSearch(query), '["vigente"]');
    });
  });

  group('Persistencia en disco', () {
    test('lee desde disco cuando la entrada no está en memoria', () async {
      final cache = ArticleCache();
      final key = uniqueKey('solo_disco');
      await writeRawEntry(key, '["desde_disco"]',
          timestamp: DateTime.now().millisecondsSinceEpoch);

      expect(await cache.getList(key: key), '["desde_disco"]');
    });

    test('devuelve null si el archivo tiene contenido corrupto', () async {
      final cache = ArticleCache();
      final key = uniqueKey('corrupto');
      final safe = key.replaceAll(RegExp(r'[^\w-]'), '_');
      await File('${tempDir.path}/dlg_$safe.json')
          .writeAsString('esto no es json valido {{{');

      expect(await cache.getList(key: key), isNull);
    });

    test('sanitiza caracteres especiales en el nombre de archivo', () async {
      final cache = ArticleCache();
      final key = uniqueKey('clave/con:caracteres raros');
      await cache.saveList('["sanitizado"]', key: key);

      expect(await cache.getList(key: key), '["sanitizado"]');

      final safe = key.replaceAll(RegExp(r'[^\w-]'), '_');
      expect(File('${tempDir.path}/dlg_$safe.json').existsSync(), isTrue);
    });

    test('entrada sin campo "r" se interpreta como no restringida', () async {
      final cache = ArticleCache();
      final key = uniqueKey('sin_flag');
      final safe = key.replaceAll(RegExp(r'[^\w-]'), '_');
      await File('${tempDir.path}/dlg_$safe.json').writeAsString(
        jsonEncode({
          'd': '["legado"]',
          't': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      expect(await cache.getList(key: key), '["legado"]');
    });

    test('no lanza excepción si falla la escritura en disco', () async {
      final cache = ArticleCache();

      // Se elimina el directorio de caché para que la escritura falle y se
      // ejecute el bloque catch. ArticleCache guarda el directorio de forma
      // estática, así que no basta con cambiar la ruta del provider.
      tempDir.deleteSync(recursive: true);

      final key = uniqueKey('fallo_escritura');
      await expectLater(cache.saveList('["dato"]', key: key), completes);

      // La entrada sigue disponible en memoria aunque el disco haya fallado.
      expect(await cache.getList(key: key), '["dato"]');

      tempDir.createSync(recursive: true);
    });
  });

  group('Caché en memoria', () {
    test('recupera de memoria sin necesidad del archivo en disco', () async {
      final cache = ArticleCache();
      final key = uniqueKey('en_memoria');
      await cache.saveList('["memoria"]', key: key);

      final safe = key.replaceAll(RegExp(r'[^\w-]'), '_');
      final file = File('${tempDir.path}/dlg_$safe.json');
      if (file.existsSync()) file.deleteSync();

      expect(await cache.getList(key: key), '["memoria"]');
    });

    test('descarta las entradas más antiguas al superar el límite', () async {
      final cache = ArticleCache();

      // Se escriben más entradas que el máximo en memoria (100) para forzar
      // la poda. La entrada más antigua debe salir de memoria.
      final oldest = uniqueKey('poda_primera');
      await cache.saveList('["primera"]', key: oldest);

      for (var i = 0; i < 110; i++) {
        await cache.saveList('["relleno_$i"]', key: uniqueKey('poda_relleno'));
      }

      // Al borrar el archivo, si siguiera en memoria se devolvería el dato.
      final safe = oldest.replaceAll(RegExp(r'[^\w-]'), '_');
      final file = File('${tempDir.path}/dlg_$safe.json');
      if (file.existsSync()) file.deleteSync();

      expect(await cache.getList(key: oldest), isNull);
    });
  });

  group('clearExclusiveContent', () {
    test('borra los detalles marcados como restringidos', () async {
      final cache = ArticleCache();
      await cache.saveDetail(2001, '{"id":2001}', isPremium: true);

      await cache.clearExclusiveContent();

      expect(
          File('${tempDir.path}/dlg_detail_2001.json').existsSync(), isFalse);
    });

    test('conserva los detalles no restringidos', () async {
      final cache = ArticleCache();
      await cache.saveDetail(2002, '{"id":2002}');

      await cache.clearExclusiveContent();

      expect(File('${tempDir.path}/dlg_detail_2002.json').existsSync(), isTrue);
      expect(await cache.getDetail(2002), '{"id":2002}');
    });

    test('no toca los listados aunque sean restringidos', () async {
      final cache = ArticleCache();
      final key = uniqueKey('lista_no_detalle');
      await cache.saveList('["lista"]', key: key);

      await cache.clearExclusiveContent();

      expect(await cache.getList(key: key), '["lista"]');
    });

    test('ignora archivos de detalle con contenido corrupto', () async {
      final cache = ArticleCache();
      final corrupt = File('${tempDir.path}/dlg_detail_9001.json');
      await corrupt.writeAsString('no es json');

      await expectLater(cache.clearExclusiveContent(), completes);

      // El archivo ilegible se deja intacto en lugar de romper el proceso.
      expect(corrupt.existsSync(), isTrue);
      corrupt.deleteSync();
    });

    test('no lanza excepción si el directorio no existe', () async {
      final cache = ArticleCache();
      tempDir.deleteSync(recursive: true);

      await expectLater(cache.clearExclusiveContent(), completes);

      tempDir.createSync(recursive: true);
    });

    test('funciona sin errores cuando no hay detalles cacheados', () async {
      final cache = ArticleCache();

      // Se vacía el directorio para que no haya ningún archivo de detalle.
      for (final entity in tempDir.listSync()) {
        entity.deleteSync(recursive: true);
      }

      await expectLater(cache.clearExclusiveContent(), completes);
    });
  });
}
