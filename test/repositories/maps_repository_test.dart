import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dlg_app/repositories/maps_repository.dart';

const _uploads = 'https://www.descifrandolaguerra.es/wp-content/uploads';

/// Envuelve el HTML en la respuesta que devuelve el endpoint de páginas.
String pageBody(String html) => jsonEncode({
      'content': {'rendered': html}
    });

/// Genera el bloque de un mapa: enlace a la imagen completa, miniatura y alt.
String mapBlock({
  required String name,
  String alt = 'Descripción del mapa',
  bool withThumb = true,
  String thumbSize = '-300x200',
}) {
  final buffer = StringBuffer()
    ..write('<a href="$_uploads/2026/06/$name.jpg">');
  if (withThumb) {
    buffer.write('<img src="$_uploads/2026/06/$name$thumbSize.jpg" '
        'alt="$alt" />');
  }
  buffer.write('</a>');
  return buffer.toString();
}

/// Construye una sección con su título h2 y sus mapas.
String section(String title, List<String> blocks) {
  return '<h2 class="elementor-heading-title elementor-size-default">'
      '$title</h2>'
      '${blocks.join()}';
}

/// Página completa con varias regiones.
String fullPage() => [
      section('Europa', [
        mapBlock(name: 'europa-1', alt: 'Mapa de Europa uno'),
        mapBlock(name: 'europa-2', alt: 'Mapa de Europa dos'),
      ]),
      section('Asia-Pacífico', [mapBlock(name: 'asia-1', alt: 'Mapa de Asia')]),
      section('América', [mapBlock(name: 'america-1', alt: 'Mapa de América')]),
    ].join();

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

  RecordingClient({this.body = '{}', this.status = 200});

  late final MockClient client = MockClient((request) async {
    requests.add(request.url);
    return http.Response(body, status);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MapsRepository.clearCache);
  tearDown(MapsRepository.clearCache);

  group('fetchAllMaps', () {
    test('agrupa los mapas por región', () async {
      final repo =
          MapsRepository(client: clientReturning(pageBody(fullPage())));

      final maps = await repo.fetchAllMaps();

      expect(maps.keys, containsAll(['Europa', 'Asia-Pacífico', 'América']));
      expect(maps['Europa'], hasLength(2));
      expect(maps['Asia-Pacífico'], hasLength(1));
    });

    test('conserva el orden en que aparecen las regiones', () async {
      final repo =
          MapsRepository(client: clientReturning(pageBody(fullPage())));

      final maps = await repo.fetchAllMaps();

      expect(maps.keys.toList(), ['Europa', 'Asia-Pacífico', 'América']);
    });

    test('reutiliza la caché en la segunda llamada', () async {
      final recording = RecordingClient(body: pageBody(fullPage()));
      final repo = MapsRepository(client: recording.client);

      await repo.fetchAllMaps();
      await repo.fetchAllMaps();

      expect(recording.requests, hasLength(1));
    });

    test('la caché se comparte entre instancias', () async {
      await MapsRepository(client: clientReturning(pageBody(fullPage())))
          .fetchAllMaps();

      final recording = RecordingClient();
      final maps =
          await MapsRepository(client: recording.client).fetchAllMaps();

      expect(maps, isNotEmpty);
      expect(recording.requests, isEmpty);
    });

    test('sigue usando la caché justo antes de que expire', () {
      fakeAsync((async) {
        final recording = RecordingClient(body: pageBody(fullPage()));
        final repo = MapsRepository(client: recording.client);

        repo.fetchAllMaps();
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 1, minutes: 59));

        repo.fetchAllMaps();
        async.flushMicrotasks();

        expect(recording.requests, hasLength(1));
      });
    });

    test('devuelve un mapa vacío si el servidor responde con error', () async {
      final repo = MapsRepository(client: clientReturning('', status: 500));

      expect(await repo.fetchAllMaps(), isEmpty);
    });

    test('un error del servidor no se guarda en caché', () async {
      final recording = RecordingClient(status: 500);
      final repo = MapsRepository(client: recording.client);

      await repo.fetchAllMaps();
      await repo.fetchAllMaps();

      expect(recording.requests, hasLength(2));
    });

    test('devuelve la caché anterior si el servidor falla', () {
      fakeAsync((async) {
        var call = 0;
        final repo = MapsRepository(
          client: MockClient((_) async {
            call++;
            if (call == 1) return http.Response(pageBody(fullPage()), 200);
            return http.Response('', 503);
          }),
        );

        repo.fetchAllMaps();
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 3));

        Map<String, Object>? resultado;
        repo.fetchAllMaps().then((m) => resultado = m.cast<String, Object>());
        async.flushMicrotasks();

        expect(resultado, isNotEmpty);
      });
    });

    test('devuelve un mapa vacío si falta el contenido', () async {
      final repo = MapsRepository(client: clientReturning(jsonEncode({})));

      expect(await repo.fetchAllMaps(), isEmpty);
    });

    test('pide la página de mapas por su identificador', () async {
      final recording = RecordingClient(body: pageBody(fullPage()));
      final repo = MapsRepository(client: recording.client);

      await repo.fetchAllMaps();

      expect(recording.requests.single.path, endsWith('/pages/2620'));
    });
  });

  group('Reintentos', () {
    test('reintenta dos veces antes de rendirse', () {
      fakeAsync((async) {
        var calls = 0;
        final repo = MapsRepository(
          client: MockClient((_) async {
            calls++;
            throw Exception('sin red');
          }),
        );

        Map<String, Object>? resultado;
        repo.fetchAllMaps().then((m) => resultado = m.cast<String, Object>());

        // 1s + 2s de espera acumulada entre reintentos.
        async.elapse(const Duration(seconds: 10));

        expect(calls, 3, reason: 'un intento inicial y dos reintentos');
        expect(resultado, isEmpty);
      });
    });

    test('devuelve el resultado si un reintento tiene éxito', () {
      fakeAsync((async) {
        var calls = 0;
        final repo = MapsRepository(
          client: MockClient((_) async {
            calls++;
            if (calls < 3) throw Exception('sin red');
            return http.Response(pageBody(fullPage()), 200);
          }),
        );

        Map<String, Object>? resultado;
        repo.fetchAllMaps().then((m) => resultado = m.cast<String, Object>());

        async.elapse(const Duration(seconds: 10));

        expect(calls, 3);
        expect(resultado, isNotEmpty);
      });
    });

    test('devuelve la caché previa si se agotan los reintentos', () {
      fakeAsync((async) {
        var call = 0;
        final repo = MapsRepository(
          client: MockClient((_) async {
            call++;
            if (call == 1) return http.Response(pageBody(fullPage()), 200);
            throw Exception('sin red');
          }),
        );

        repo.fetchAllMaps();
        async.flushMicrotasks();

        async.elapse(const Duration(hours: 3));

        Map<String, Object>? resultado;
        repo.fetchAllMaps().then((m) => resultado = m.cast<String, Object>());
        async.elapse(const Duration(seconds: 10));

        expect(resultado, isNotEmpty);
      });
    });
  });

  group('fetchMapsForRegion', () {
    test('devuelve los mapas de la región pedida', () async {
      final repo =
          MapsRepository(client: clientReturning(pageBody(fullPage())));

      final maps = await repo.fetchMapsForRegion('europa');

      expect(maps, hasLength(2));
    });

    test('traduce cada slug conocido a su título', () async {
      final html = [
        section('Europa', [mapBlock(name: 'a')]),
        section('Asia-Pacífico', [mapBlock(name: 'b')]),
        section('América', [mapBlock(name: 'c')]),
        section('Oriente Medio y Norte de África', [mapBlock(name: 'd')]),
        section('África Subsahariana', [mapBlock(name: 'e')]),
        section('Asia Central y Meridional', [mapBlock(name: 'f')]),
      ].join();
      final repo = MapsRepository(client: clientReturning(pageBody(html)));

      for (final slug in [
        'europa',
        'asia-pacifico',
        'america',
        'oriente-medio-y-norte-de-africa',
        'africa-subsahariana',
        'asia-central-meridional',
      ]) {
        expect(await repo.fetchMapsForRegion(slug), hasLength(1),
            reason: 'falla el slug $slug');
      }
    });

    test('devuelve vacío para un slug desconocido', () async {
      final repo =
          MapsRepository(client: clientReturning(pageBody(fullPage())));

      expect(await repo.fetchMapsForRegion('narnia'), isEmpty);
    });

    test('encuentra la región aunque el título tenga texto añadido', () async {
      final html = section(
        'Mapas Colaboración con FairPolitik Europa',
        [mapBlock(name: 'europa-1')],
      );
      final repo = MapsRepository(client: clientReturning(pageBody(html)));

      expect(await repo.fetchMapsForRegion('europa'), hasLength(1));
    });

    test('devuelve vacío si la región no aparece en la página', () async {
      final html = section('Europa', [mapBlock(name: 'europa-1')]);
      final repo = MapsRepository(client: clientReturning(pageBody(html)));

      expect(await repo.fetchMapsForRegion('america'), isEmpty);
    });

    test('devuelve vacío si no se pudo descargar la página', () async {
      final repo = MapsRepository(client: clientReturning('', status: 500));

      expect(await repo.fetchMapsForRegion('europa'), isEmpty);
    });
  });

  group('Parseo del HTML', () {
    Future<Map<String, List<Object>>> parse(String html) async {
      MapsRepository.clearCache();
      final repo = MapsRepository(client: clientReturning(pageBody(html)));
      final maps = await repo.fetchAllMaps();
      return maps.map((k, v) => MapEntry(k, v.cast<Object>()));
    }

    test('un HTML vacío no produce regiones', () async {
      expect(await parse(''), isEmpty);
    });

    test('ignora las secciones sin título', () async {
      final html = '<h2 class="elementor-heading-title"></h2>'
          '${mapBlock(name: 'suelto')}';

      expect(await parse(html), isEmpty);
    });

    test('ignora las secciones sin imágenes', () async {
      final html =
          section('Europa', []) + section('América', [mapBlock(name: 'a')]);
      final maps = await parse(html);

      expect(maps.keys, ['América']);
    });

    test('limpia las etiquetas HTML del título', () async {
      final html = '<h2 class="elementor-heading-title">'
          '<span>Europa</span></h2>${mapBlock(name: 'a')}';

      expect((await parse(html)).keys, ['Europa']);
    });

    test('normaliza los espacios del título', () async {
      final html = '<h2 class="elementor-heading-title">  Europa\n   '
          'Central  </h2>${mapBlock(name: 'a')}';

      expect((await parse(html)).keys, ['Europa Central']);
    });

    test('asigna cada mapa a la sección que le corresponde', () async {
      final maps = await parse(fullPage());

      expect(maps['Europa'], hasLength(2));
      expect(maps['América'], hasLength(1));
    });

    test('acepta las cuatro extensiones de imagen', () async {
      final html = section('Europa', [
        '<a href="$_uploads/a.jpg"><img src="$_uploads/a-300x200.jpg" alt="Mapa uno" /></a>',
        '<a href="$_uploads/b.png"><img src="$_uploads/b-300x200.png" alt="Mapa dos" /></a>',
        '<a href="$_uploads/c.jpeg"><img src="$_uploads/c-300x200.jpeg" alt="Mapa tres" /></a>',
        '<a href="$_uploads/d.webp"><img src="$_uploads/d-300x200.webp" alt="Mapa cuatro" /></a>',
      ]);

      expect((await parse(html))['Europa'], hasLength(4));
    });

    test('ignora los enlaces que no son de la carpeta de subidas', () async {
      final html = section('Europa', [
        '<a href="https://otrositio.es/mapa.jpg"><img src="https://otrositio.es/mapa.jpg" alt="Ajeno" /></a>',
        mapBlock(name: 'valido'),
      ]);

      expect((await parse(html))['Europa'], hasLength(1));
    });
  });

  group('Selección de miniatura y texto alternativo', () {
    Future<List<dynamic>> mapsOf(String html) async {
      MapsRepository.clearCache();
      final repo = MapsRepository(client: clientReturning(pageBody(html)));
      final all = await repo.fetchAllMaps();
      return all.values.first;
    }

    test('prefiere la miniatura de 300 píxeles', () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', thumbSize: '-300x200')]),
      );

      expect(maps.first.thumbUrl, contains('-300x200'));
    });

    test('acepta también la miniatura de 268 píxeles', () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', thumbSize: '-268x180')]),
      );

      expect(maps.first.thumbUrl, contains('-268x180'));
    });

    test('usa la imagen completa si no hay ninguna miniatura', () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', withThumb: false)]),
      );

      expect(maps.first.thumbUrl, maps.first.url);
    });

    test('recurre a la imagen a tamaño real si la miniatura no encaja',
        () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', thumbSize: '-1024x768')]),
      );

      expect(maps.first.thumbUrl, contains('-1024x768'));
    });

    test('guarda el texto alternativo de la imagen', () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', alt: 'Mapa del estrecho')]),
      );

      expect(maps.first.alt, 'Mapa del estrecho');
    });

    test('deja el alternativo vacío si no lo hay', () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', withThumb: false)]),
      );

      expect(maps.first.alt, isEmpty);
    });

    test('descarta los textos alternativos demasiado cortos', () async {
      final maps = await mapsOf(
        section('Europa', [mapBlock(name: 'a', alt: 'abc')]),
      );

      expect(maps.first.alt, isEmpty);
    });

    test('guarda la URL de la imagen a tamaño completo', () async {
      final maps = await mapsOf(section('Europa', [mapBlock(name: 'ormuz')]));

      expect(maps.first.url, '$_uploads/2026/06/ormuz.jpg');
    });
  });

  group('clearCache', () {
    test('obliga a volver a la red tras limpiarla', () async {
      final recording = RecordingClient(body: pageBody(fullPage()));
      final repo = MapsRepository(client: recording.client);

      await repo.fetchAllMaps();
      MapsRepository.clearCache();
      await repo.fetchAllMaps();

      expect(recording.requests, hasLength(2));
    });

    test('puede llamarse sin que haya nada cacheado', () {
      expect(MapsRepository.clearCache, returnsNormally);
    });
  });

  group('Constructor', () {
    test('usa el pool compartido si no se le inyecta cliente', () {
      expect(MapsRepository(), isA<MapsRepository>());
    });
  });
}
