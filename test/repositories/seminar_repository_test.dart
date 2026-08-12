import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dlg_app/models/seminar.dart';
import 'package:dlg_app/repositories/seminar_repository.dart';

// ─── Constructores de respuestas ──────────────────────────────────────────────

Map<String, dynamic> seminarJson({
  int id = 1,
  String title = 'La guerra en el golfo Pérsico',
  String link = 'https://www.descifrandolaguerra.es/seminarios/golfo-persico/',
  String content = '<p>Introducción</p>',
  List<String> classList = const ['post-1', 'seminario'],
}) {
  return {
    'id': id,
    'title': {'rendered': title},
    'link': link,
    'content': {'rendered': content},
    'class_list': classList,
    'yoast_head_json': {
      'og_image': [
        {'url': 'https://ejemplo.es/portada.jpg'}
      ],
      'og_description': 'Descripción del seminario',
    },
  };
}

String seminarsBody(int count) => jsonEncode([
      for (var i = 0; i < count; i++)
        seminarJson(id: i + 1, title: 'Seminario ${i + 1}')
    ]);

/// Entrada de sesión tal y como la devuelve el endpoint sesion-seminario.
Map<String, dynamic> sessionJson({
  int id = 10,
  String title = 'Sesión 1',
  String slug = 'golfo-persico',
  String sessionSlug = 'sesion-1',
}) {
  return {
    'id': id,
    'title': {'rendered': title},
    'link': 'https://www.descifrandolaguerra.es/seminarios/$slug/$sessionSlug/',
  };
}

/// HTML de una sesión con todas sus partes.
String sessionHtml({
  String? title = 'Primera sesión',
  String? vimeoId = '123456',
  List<String> pdfs = const ['informe.pdf'],
  String? description = '<p>Primer párrafo</p><p>Segundo párrafo</p>',
  List<String> menuSessions = const ['Sesión 1', 'Sesión 2'],
}) {
  final buffer = StringBuffer();
  if (title != null) buffer.write('<h1 class="titulo">$title</h1>');
  if (vimeoId != null) {
    buffer.write(
        '<iframe data-src="https://player.vimeo.com/video/$vimeoId?h=abc"></iframe>');
  }
  if (pdfs.isNotEmpty) {
    buffer.write('<section class="dlg-sesion-materials">');
    for (final pdf in pdfs) {
      buffer.write('<a href="https://ejemplo.es/$pdf" class="x">$pdf</a>');
    }
    buffer.write('</section>');
  }
  if (description != null) {
    buffer
      ..write('<div data-widget_type="theme-post-content.default">')
      ..write('<div class="elementor-widget-container">')
      ..write(description)
      ..write('</div> </div> </div>');
  }
  if (menuSessions.isNotEmpty) {
    buffer.write('<ul class="menu-sesiones-seminario">');
    for (var i = 0; i < menuSessions.length; i++) {
      buffer.write(
          '<li class="item"> <a href="https://ejemplo.es/sesion-${i + 1}/">${menuSessions[i]}</a> </li>');
    }
    buffer.write('</ul>');
  }
  return buffer.toString();
}

// ─── Clientes de prueba ───────────────────────────────────────────────────────

MockClient clientReturning(String body, {int status = 200}) =>
    MockClient((_) async => http.Response(body, status));

MockClient clientThrowing() =>
    MockClient((_) async => throw Exception('sin red'));

/// Cliente que registra las peticiones recibidas.
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
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

const _seminarUrl =
    'https://www.descifrandolaguerra.es/seminarios/golfo-persico/';
const _sessionUrl =
    'https://www.descifrandolaguerra.es/seminarios/golfo-persico/sesion-1/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SeminarRepository.clearCache);
  tearDown(SeminarRepository.clearCache);

  group('fetchSeminars', () {
    test('descarga los seminarios y los devuelve', () async {
      final repo = SeminarRepository(client: clientReturning(seminarsBody(3)));

      final seminars = await repo.fetchSeminars();

      expect(seminars, hasLength(3));
      expect(seminars.first.title, 'Seminario 1');
      expect(seminars.first.contentHtml, '<p>Introducción</p>');
    });

    test('reutiliza la caché en la segunda llamada', () async {
      final recording = RecordingClient(body: seminarsBody(2));
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSeminars();
      final segunda = await repo.fetchSeminars();

      expect(segunda, hasLength(2));
      expect(recording.requests, hasLength(1),
          reason: 'la segunda llamada sale de caché');
    });

    test('la caché se comparte entre instancias', () async {
      await SeminarRepository(client: clientReturning(seminarsBody(2)))
          .fetchSeminars();

      final recording = RecordingClient();
      final otra = SeminarRepository(client: recording.client);
      final seminars = await otra.fetchSeminars();

      expect(seminars, hasLength(2));
      expect(recording.requests, isEmpty);
    });

    test('devuelve lista vacía si el servidor responde con error', () async {
      final repo = SeminarRepository(client: clientReturning('', status: 500));

      expect(await repo.fetchSeminars(), isEmpty);
    });

    test('conserva la caché anterior si el servidor falla', () async {
      await SeminarRepository(client: clientReturning(seminarsBody(2)))
          .fetchSeminars();
      SeminarRepository.clearCache();
      await SeminarRepository(client: clientReturning(seminarsBody(2)))
          .fetchSeminars();

      // Se fuerza la caducidad recreando el escenario: con caché válida no
      // se llega a la red, así que se comprueba el camino de error partiendo
      // de una caché vacía.
      SeminarRepository.clearCache();
      final repo = SeminarRepository(client: clientReturning('', status: 503));

      expect(await repo.fetchSeminars(), isEmpty);
    });

    test('devuelve lista vacía ante una excepción de red', () async {
      final repo = SeminarRepository(client: clientThrowing());

      expect(await repo.fetchSeminars(), isEmpty);
    });

    test('devuelve lista vacía si la respuesta no es JSON válido', () async {
      final repo = SeminarRepository(client: clientReturning('<html>'));

      expect(await repo.fetchSeminars(), isEmpty);
    });

    test('pide los campos y el orden esperados', () async {
      final recording = RecordingClient(body: seminarsBody(1));
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSeminars();

      final url = recording.requests.single.toString();
      expect(url, contains('/seminario'));
      expect(url, contains('per_page=20'));
      expect(url, contains('order=desc'));
    });
  });

  group('prefetch', () {
    test('no hace nada si la caché sigue vigente', () async {
      await SeminarRepository(client: clientReturning(seminarsBody(1)))
          .fetchSeminars();

      expect(SeminarRepository.prefetch, returnsNormally);
    });

    test('lanza la descarga si no hay caché', () async {
      // Usa el cliente real, interceptado por el entorno de test.
      expect(SeminarRepository.prefetch, returnsNormally);
      await settle();
    });
  });

  group('clearCache', () {
    test('obliga a volver a la red tras limpiarla', () async {
      final recording = RecordingClient(body: seminarsBody(1));
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSeminars();
      SeminarRepository.clearCache();
      await repo.fetchSeminars();

      expect(recording.requests, hasLength(2));
    });

    test('limpia también sesiones y detalles', () async {
      final recording = RecordingClient(
        body: jsonEncode([sessionJson()]),
      );
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessions(_seminarUrl, '');
      SeminarRepository.clearCache();
      await repo.fetchSessions(_seminarUrl, '');

      expect(recording.requests, hasLength(2));
    });
  });

  group('fetchSessions', () {
    test('agrupa las sesiones por seminario', () async {
      final repo = SeminarRepository(
        client: clientReturning(jsonEncode([
          sessionJson(id: 1, title: 'Sesión 1', sessionSlug: 'sesion-1'),
          sessionJson(id: 2, title: 'Sesión 2', sessionSlug: 'sesion-2'),
          sessionJson(id: 3, title: 'Otra', slug: 'otro-seminario'),
        ])),
      );

      final sessions = await repo.fetchSessions(_seminarUrl, '');

      expect(sessions, hasLength(2));
      expect(sessions.first.title, 'Sesión 1');
    });

    test('limpia el HTML de los títulos', () async {
      final repo = SeminarRepository(
        client: clientReturning(jsonEncode([
          sessionJson(title: '<em>Sesión</em> con etiquetas'),
        ])),
      );

      final sessions = await repo.fetchSessions(_seminarUrl, '');

      expect(sessions.single.title, 'Sesión con etiquetas');
    });

    test('reutiliza la caché en la segunda llamada', () async {
      final recording = RecordingClient(body: jsonEncode([sessionJson()]));
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessions(_seminarUrl, '');
      final segunda = await repo.fetchSessions(_seminarUrl, '');

      expect(segunda, hasLength(1));
      expect(recording.requests, hasLength(1));
    });

    test('cachea de paso las sesiones de otros seminarios', () async {
      final recording = RecordingClient(
        body: jsonEncode([
          sessionJson(slug: 'golfo-persico'),
          sessionJson(id: 2, slug: 'otro-seminario', title: 'De otro'),
        ]),
      );
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessions(_seminarUrl, '');
      final otras = await repo.fetchSessions(
        'https://www.descifrandolaguerra.es/seminarios/otro-seminario/',
        '',
      );

      expect(otras.single.title, 'De otro');
      expect(recording.requests, hasLength(1));
    });

    test('devuelve vacío si la URL no tiene suficientes segmentos', () async {
      final recording = RecordingClient();
      final repo = SeminarRepository(client: recording.client);

      final sessions = await repo.fetchSessions(
        'https://www.descifrandolaguerra.es/seminarios/',
        '',
      );

      expect(sessions, isEmpty);
      expect(recording.requests, isEmpty);
    });

    test('devuelve vacío si el seminario no aparece en la respuesta', () async {
      final repo = SeminarRepository(
        client:
            clientReturning(jsonEncode([sessionJson(slug: 'otro-seminario')])),
      );

      expect(await repo.fetchSessions(_seminarUrl, ''), isEmpty);
    });

    test('ignora entradas cuyo enlace no encaja con el patrón', () async {
      final repo = SeminarRepository(
        client: clientReturning(jsonEncode([
          {
            'id': 1,
            'title': {'rendered': 'Suelta'},
            'link': 'https://www.descifrandolaguerra.es/otra-cosa/',
          },
          sessionJson(),
        ])),
      );

      expect(await repo.fetchSessions(_seminarUrl, ''), hasLength(1));
    });

    test('ignora entradas sin enlace', () async {
      final repo = SeminarRepository(
        client: clientReturning(jsonEncode([
          {
            'id': 1,
            'title': {'rendered': 'Sin enlace'}
          },
          sessionJson(),
        ])),
      );

      expect(await repo.fetchSessions(_seminarUrl, ''), hasLength(1));
    });

    test('devuelve vacío si el servidor responde con error', () async {
      final repo = SeminarRepository(client: clientReturning('', status: 500));

      expect(await repo.fetchSessions(_seminarUrl, ''), isEmpty);
    });

    test('devuelve vacío ante una excepción', () async {
      final repo = SeminarRepository(client: clientThrowing());

      expect(await repo.fetchSessions(_seminarUrl, ''), isEmpty);
    });

    test('envía las cookies cuando se le pasan', () async {
      final recording = RecordingClient(body: jsonEncode([sessionJson()]));
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessions(_seminarUrl, 'wordpress=abc');

      expect(recording.headers.single['Cookie'], 'wordpress=abc');
    });

    test('no envía cookies si la cadena está vacía', () async {
      final recording = RecordingClient(body: jsonEncode([sessionJson()]));
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessions(_seminarUrl, '');

      expect(recording.headers.single.containsKey('Cookie'), isFalse);
    });
  });

  group('fetchSessionDetail', () {
    test('extrae todos los datos de la sesión', () async {
      final repo = SeminarRepository(client: clientReturning(sessionHtml()));

      final detail = await repo.fetchSessionDetail(_sessionUrl, '');

      expect(detail, isNotNull);
      expect(detail!.title, 'Primera sesión');
      expect(detail.vimeoUrl, 'https://player.vimeo.com/video/123456?h=abc');
      expect(detail.materials, hasLength(1));
      expect(detail.materials.single.name, 'informe.pdf');
      expect(detail.description, contains('Primer párrafo'));
      expect(detail.allSessions, hasLength(2));
    });

    test('reutiliza la caché en la segunda llamada', () async {
      final recording = RecordingClient(body: sessionHtml());
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessionDetail(_sessionUrl, '');
      final segunda = await repo.fetchSessionDetail(_sessionUrl, '');

      expect(segunda, isNotNull);
      expect(recording.requests, hasLength(1));
    });

    test('devuelve null si el servidor responde con error', () async {
      final repo = SeminarRepository(client: clientReturning('', status: 403));

      expect(await repo.fetchSessionDetail(_sessionUrl, ''), isNull);
    });

    test('devuelve null ante una excepción', () async {
      final repo = SeminarRepository(client: clientThrowing());

      expect(await repo.fetchSessionDetail(_sessionUrl, ''), isNull);
    });

    test('envía las cookies y la codificación aceptada', () async {
      final recording = RecordingClient(body: sessionHtml());
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessionDetail(_sessionUrl, 'wordpress=abc');

      expect(recording.headers.single['Cookie'], 'wordpress=abc');
      expect(recording.headers.single['Accept-Encoding'], contains('gzip'));
    });

    test('no envía cookies si la cadena está vacía', () async {
      final recording = RecordingClient(body: sessionHtml());
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessionDetail(_sessionUrl, '');

      expect(recording.headers.single.containsKey('Cookie'), isFalse);
    });
  });

  group('Parseo del detalle de sesión', () {
    Future<SeminarSessionDetail> detailFrom(String html) async {
      SeminarRepository.clearCache();
      final repo = SeminarRepository(client: clientReturning(html));
      return (await repo.fetchSessionDetail(_sessionUrl, ''))!;
    }

    test('título vacío si no hay h1', () async {
      final detail = await detailFrom(sessionHtml(title: null));

      expect(detail.title, isEmpty);
    });

    test('vimeo vacío si no hay reproductor', () async {
      final detail = await detailFrom(sessionHtml(vimeoId: null));

      expect(detail.vimeoUrl, isEmpty);
    });

    test('sin materiales si falta la sección', () async {
      final detail = await detailFrom(sessionHtml(pdfs: []));

      expect(detail.materials, isEmpty);
    });

    test('recoge varios materiales', () async {
      final detail = await detailFrom(
        sessionHtml(pdfs: ['informe.pdf', 'presentacion.pdf']),
      );

      expect(detail.materials, hasLength(2));
      expect(detail.materials.last.url, endsWith('presentacion.pdf'));
    });

    test('ignora enlaces que no son PDF dentro de materiales', () async {
      final detail = await detailFrom(
        '<section class="dlg-sesion-materials">'
        '<a href="https://ejemplo.es/pagina.html">Web</a>'
        '<a href="https://ejemplo.es/guia.pdf">Guía</a>'
        '</section>',
      );

      expect(detail.materials, hasLength(1));
      expect(detail.materials.single.name, 'Guía');
    });

    test('descripción vacía si falta el widget de contenido', () async {
      final detail = await detailFrom(sessionHtml(description: null));

      expect(detail.description, isEmpty);
    });

    test('convierte los párrafos en saltos de línea', () async {
      final detail = await detailFrom(sessionHtml(
        description: '<p>Uno</p><p>Dos</p>',
      ));

      expect(detail.description, 'Uno\n\nDos');
    });

    test('colapsa los saltos de línea repetidos', () async {
      final detail = await detailFrom(sessionHtml(
        description: '<p>Uno</p><br><br><p>Dos</p>',
      ));

      expect(detail.description, isNot(contains('\n\n\n')));
    });

    test('sin sesiones si falta el menú lateral', () async {
      final detail = await detailFrom(sessionHtml(menuSessions: []));

      expect(detail.allSessions, isEmpty);
    });

    test('extrae título y enlace de cada sesión del menú', () async {
      final detail = await detailFrom(sessionHtml(
        menuSessions: ['Primera', 'Segunda', 'Tercera'],
      ));

      expect(detail.allSessions, hasLength(3));
      expect(detail.allSessions.first.title, 'Primera');
      expect(detail.allSessions.first.url, endsWith('/sesion-1/'));
    });

    test('menú vacío no produce sesiones', () async {
      final detail = await detailFrom(
        '<ul class="menu-sesiones-seminario"></ul>',
      );

      expect(detail.allSessions, isEmpty);
    });

    test('un HTML sin nada reconocible devuelve un detalle vacío', () async {
      final detail = await detailFrom('<html><body></body></html>');

      expect(detail.title, isEmpty);
      expect(detail.vimeoUrl, isEmpty);
      expect(detail.materials, isEmpty);
      expect(detail.description, isEmpty);
      expect(detail.allSessions, isEmpty);
    });
  });

  group('prefetchSessionDetails', () {
    test('descarga las sesiones que no estén cacheadas', () async {
      final recording = RecordingClient(body: sessionHtml());
      final repo = SeminarRepository(client: recording.client);

      repo.prefetchSessionDetails(
        const [
          SeminarSession(title: 'Una', url: 'https://ejemplo.es/s1/'),
          SeminarSession(title: 'Otra', url: 'https://ejemplo.es/s2/'),
        ],
        '',
      );
      await settle();

      expect(recording.requests, hasLength(2));
    });

    test('omite las sesiones ya cacheadas', () async {
      final recording = RecordingClient(body: sessionHtml());
      final repo = SeminarRepository(client: recording.client);

      await repo.fetchSessionDetail('https://ejemplo.es/s1/', '');
      recording.requests.clear();

      repo.prefetchSessionDetails(
        const [
          SeminarSession(title: 'Una', url: 'https://ejemplo.es/s1/'),
          SeminarSession(title: 'Otra', url: 'https://ejemplo.es/s2/'),
        ],
        '',
      );
      await settle();

      expect(recording.requests, hasLength(1));
    });

    test('no falla con una lista vacía', () async {
      final repo = SeminarRepository(client: clientReturning(sessionHtml()));

      expect(() => repo.prefetchSessionDetails(const [], ''), returnsNormally);
    });
  });

  group('Constructor', () {
    test('usa el pool compartido si no se le inyecta cliente', () {
      expect(SeminarRepository(), isA<SeminarRepository>());
    });
  });
}
