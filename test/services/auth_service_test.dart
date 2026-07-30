import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dlg_app/models/auth_exception.dart';
import 'package:dlg_app/models/auth_state.dart';
import 'package:dlg_app/services/auth_service.dart';

/// Almacenamiento en memoria que sustituye a flutter_secure_storage.
late Map<String, String> storage;

/// Registra las peticiones recibidas para poder afirmar sobre ellas.
late List<http.Request> requests;

/// Construye un cliente que responde según la URL solicitada.
MockClient routedClient(
  Map<String, http.Response> Function(String url) routes,
) {
  return MockClient((request) async {
    requests.add(request);
    final url = request.url.toString();
    final table = routes(url);
    for (final entry in table.entries) {
      if (url.contains(entry.key)) return entry.value;
    }
    return http.Response('no encontrado', 404);
  });
}

/// Atajo para el caso más habitual: rutas fijas.
MockClient clientWithRoutes(Map<String, http.Response> routes) =>
    routedClient((_) => routes);

http.Response ok(String body) => http.Response(body, 200);

/// HTML de /mi-cuenta/ con los datos de membresía.
String accountHtml({
  String name = 'Premium',
  String status = 'Activo',
  String? expires = '21 de abril de 2026',
  String? newsletter,
}) {
  final buffer = StringBuffer()
    ..write('<table><tr>')
    ..write('<td data-th="Membresía">$name</td>')
    ..write('<td data-th="Estado">$status</td>');
  if (expires != null) {
    buffer.write('<td data-th="Expiration Date">$expires</td>');
  }
  buffer.write('</tr></table>');
  if (newsletter != null) {
    buffer
      ..write('<div id="elementor-tab-content-2441">$newsletter</div>')
      ..write('<div class="elementor-tab-title">Guardado');
  }
  return buffer.toString();
}

/// Respuesta de /users/me
String userMeBody({String name = 'Lector', String email = 'a@b.es'}) =>
    jsonEncode({'id': 1, 'name': name, 'email': email});

/// Respuesta del post restringido usado para deducir si es suscriptor.
String restrictedPostBody({String content = '<p>Texto exclusivo</p>'}) =>
    jsonEncode([
      {
        'id': 10,
        'content': {'rendered': content}
      }
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    storage = {};
    requests = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        switch (call.method) {
          case 'read':
            return storage[args['key']];
          case 'write':
            storage[args['key']] = args['value'] as String;
            return null;
          case 'delete':
            storage.remove(args['key']);
            return null;
          case 'deleteAll':
            storage.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(storage);
          case 'containsKey':
            return storage.containsKey(args['key']);
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('loadSavedSession', () {
    test('devuelve unknown si no hay nada guardado', () async {
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.status, SessionStatus.unknown);
    });

    test('devuelve guest si la sesión guardada es de invitado', () async {
      storage['dlg_session_status'] = 'guest';
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.isGuest, isTrue);
    });

    test('devuelve unknown si el estado guardado no se reconoce', () async {
      storage['dlg_session_status'] = 'otra-cosa';
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.status, SessionStatus.unknown);
    });

    test('devuelve unknown si faltan las cookies', () async {
      storage['dlg_session_status'] = 'loggedIn';
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.status, SessionStatus.unknown);
    });

    test('devuelve unknown si las cookies están vacías', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = '';
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.status, SessionStatus.unknown);
    });

    test('restaura la sesión completa con membresía', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1'
        ..['dlg_user_email'] = 'lector@ejemplo.es'
        ..['dlg_user_display_name'] = 'Lector'
        ..['dlg_is_subscriber'] = 'true'
        ..['dlg_membership_name'] = 'Premium'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = '21 de abril de 2026'
        ..['dlg_newsletter_html'] = '<p>Boletín</p>';
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.isLoggedIn, isTrue);
      expect(state.userEmail, 'lector@ejemplo.es');
      expect(state.userDisplayName, 'Lector');
      expect(state.isSubscriber, isTrue);
      expect(state.membership?.name, 'Premium');
      expect(state.membership?.isActive, isTrue);
      expect(state.membership?.hasNewsletter, isTrue);
    });

    test('deja la membresía nula si faltan sus datos', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1'
        ..['dlg_user_display_name'] = 'Lector';
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.loadSavedSession();

      expect(state.membership, isNull);
      expect(state.isSubscriber, isFalse);
    });

    test('recupera el nombre del servidor si no estaba guardado', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1';
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody(name: 'Recuperado')),
        }),
      );

      final state = await service.loadSavedSession();

      expect(state.userDisplayName, 'Recuperado');
      expect(storage['dlg_user_display_name'], 'Recuperado');
    });

    test('recupera el nombre aunque el nombre guardado esté vacío', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1'
        ..['dlg_user_display_name'] = '';
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody(name: 'Rellenado')),
        }),
      );

      final state = await service.loadSavedSession();

      expect(state.userDisplayName, 'Rellenado');
    });

    test('no guarda el nombre si el servidor devuelve uno vacío', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1';
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody(name: '')),
        }),
      );

      final state = await service.loadSavedSession();

      expect(state.userDisplayName, '');
      expect(storage.containsKey('dlg_user_display_name'), isFalse);
    });

    test('funciona sin nonce disponible', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1';
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': http.Response('', 500),
          'users/me': ok(userMeBody(name: 'SinNonce')),
        }),
      );

      final state = await service.loadSavedSession();

      expect(state.userDisplayName, 'SinNonce');
    });

    test('mantiene la sesión si la recuperación del nombre falla', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1';
      final service = AuthService(
        client: MockClient((_) async => throw Exception('sin red')),
      );

      final state = await service.loadSavedSession();

      expect(state.isLoggedIn, isTrue);
      expect(state.userDisplayName, isNull);
    });

    test('mantiene la sesión si /users/me responde con error', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1';
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': http.Response('', 401),
        }),
      );

      final state = await service.loadSavedSession();

      expect(state.isLoggedIn, isTrue);
      expect(state.userDisplayName, isNull);
    });
  });

  group('isMembershipStale', () {
    test('es true si nunca se ha refrescado', () async {
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isTrue);
    });

    test('es true si la membresía no está activa', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Cancelado'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isTrue);
    });

    test('es true si no hay estado de membresía guardado', () async {
      storage['dlg_membership_refreshed_at'] = '123';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isTrue);
    });

    test('es false con membresía activa y fecha futura', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = '31 de diciembre de 2099'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('acepta el estado en inglés', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Active'
        ..['dlg_membership_expires'] = '31 de diciembre de 2099'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('es true si la fecha de expiración ya pasó', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = '1 de enero de 2020'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isTrue);
    });

    test('es false sin fecha de expiración guardada', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('es false si la fecha guardada está vacía', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = ''
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('ignora una fecha con formato irreconocible', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = 'fecha rara'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('ignora una fecha con mes inexistente', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = '5 de brumario de 2099'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('ignora una fecha con día no numérico', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = 'X de abril de 2099'
        ..['dlg_is_subscriber'] = 'true';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isFalse);
    });

    test('es true ante la inconsistencia activa sin isSubscriber', () async {
      storage
        ..['dlg_membership_refreshed_at'] = '123'
        ..['dlg_membership_status'] = 'Activo'
        ..['dlg_membership_expires'] = '31 de diciembre de 2099'
        ..['dlg_is_subscriber'] = 'false';
      final service = AuthService(client: clientWithRoutes({}));

      expect(await service.isMembershipStale(), isTrue);
    });
  });

  group('refreshMembership', () {
    test('actualiza y persiste el estado de la suscripción', () async {
      storage['dlg_user_email'] = 'lector@ejemplo.es';
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      final state = await service.refreshMembership('cookie=1');

      expect(state, isNotNull);
      expect(state!.isSubscriber, isTrue);
      expect(state.membership?.name, 'Premium');
      expect(storage['dlg_is_subscriber'], 'true');
      expect(storage['dlg_membership_status'], 'Activo');
      expect(storage['dlg_membership_refreshed_at'], isNotNull);
    });

    test('persiste isSubscriber false cuando el contenido llega vacío',
        () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody(content: '')),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      final state = await service.refreshMembership('cookie=1');

      expect(state!.isSubscriber, isFalse);
      expect(storage['dlg_is_subscriber'], 'false');
    });

    test('no escribe datos de membresía si no se pudo obtener', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': http.Response('', 500),
        }),
      );

      final state = await service.refreshMembership('cookie=1');

      expect(state!.membership, isNull);
      expect(storage.containsKey('dlg_membership_name'), isFalse);
    });

    test('guarda cadenas vacías cuando faltan fecha y boletín', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce123'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml(expires: null)),
        }),
      );

      await service.refreshMembership('cookie=1');

      expect(storage['dlg_membership_expires'], '');
      expect(storage['dlg_newsletter_html'], '');
    });

    test('devuelve null si algo falla', () async {
      final service = AuthService(
        client: MockClient((_) async => throw Exception('sin red')),
      );

      // _fetchUserData y _fetchMembership capturan sus propios errores, así
      // que se fuerza el fallo con un almacenamiento que rechaza escrituras.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          if (call.method == 'write') throw PlatformException(code: 'error');
          return null;
        },
      );

      final state = await service.refreshMembership('cookie=1');

      expect(state, isNull);
    });
  });

  group('loginWithCookies', () {
    test('rechaza una cadena de cookies vacía', () async {
      final service = AuthService(client: clientWithRoutes({}));

      expect(
        () => service.loginWithCookies(''),
        throwsA(isA<AuthException>()),
      );
    });

    test('crea y persiste la sesión', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-login'),
          'users/me': ok(userMeBody(name: 'Lector', email: 'l@e.es')),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml(newsletter: '<p>Boletín</p>')),
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.isLoggedIn, isTrue);
      expect(state.userEmail, 'l@e.es');
      expect(state.userDisplayName, 'Lector');
      expect(state.isSubscriber, isTrue);
      expect(state.membership?.name, 'Premium');
      expect(state.membership?.newsletterHtml, '<p>Boletín</p>');
      expect(service.lastNonce, 'nonce-login');
      expect(storage['dlg_session_status'], 'loggedIn');
      expect(storage['dlg_cookies'], 'cookie=1');
      expect(storage['dlg_membership_name'], 'Premium');
    });

    test('persiste la sesión aunque no haya membresía', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-login'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody(content: '')),
          'mi-cuenta': http.Response('', 404),
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.isLoggedIn, isTrue);
      expect(state.membership, isNull);
      expect(storage.containsKey('dlg_membership_name'), isFalse);
    });

    test('devuelve valores vacíos si /users/me falla', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-login'),
          'users/me': http.Response('', 403),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.userEmail, '');
      expect(state.userDisplayName, '');
      expect(state.isSubscriber, isFalse);
    });

    test('no marca suscriptor si la lista de posts llega vacía', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-login'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok('[]'),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.isSubscriber, isFalse);
    });

    test('no marca suscriptor si la comprobación responde con error',
        () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-login'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': http.Response('', 401),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.isSubscriber, isFalse);
    });

    test('usa cadenas vacías si el usuario no trae nombre ni email', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-login'),
          'users/me': ok(jsonEncode({'id': 1})),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.userEmail, '');
      expect(state.userDisplayName, '');
    });

    test('sobrevive a un error de red al pedir los datos del usuario',
        () async {
      var callCount = 0;
      final service = AuthService(
        client: MockClient((request) async {
          callCount++;
          final url = request.url.toString();
          if (url.contains('admin-ajax.php')) return ok('nonce-login');
          if (url.contains('mi-cuenta')) return ok(accountHtml());
          throw Exception('sin red');
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.isLoggedIn, isTrue);
      expect(state.userEmail, '');
      expect(callCount, greaterThan(0));
    });

    test('envía la cabecera del nonce cuando está disponible', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce-abc'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      await service.loginWithCookies('cookie=1');

      final userRequest =
          requests.firstWhere((r) => r.url.toString().contains('users/me'));
      expect(userRequest.headers['X-WP-Nonce'], 'nonce-abc');
    });

    test('omite la cabecera del nonce si no se pudo obtener', () async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': http.Response('', 500),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': ok(accountHtml()),
        }),
      );

      await service.loginWithCookies('cookie=1');

      final userRequest =
          requests.firstWhere((r) => r.url.toString().contains('users/me'));
      expect(userRequest.headers.containsKey('X-WP-Nonce'), isFalse);
    });
  });

  group('Membresía desde /mi-cuenta/', () {
    Future<MembershipInfo?> membershipFrom(http.Response response) async {
      final service = AuthService(
        client: clientWithRoutes({
          'admin-ajax.php': ok('nonce'),
          'users/me': ok(userMeBody()),
          'rcp_is_restricted': ok(restrictedPostBody()),
          'mi-cuenta': response,
        }),
      );
      final state = await service.loginWithCookies('cookie=1');
      return state.membership;
    }

    test('extrae nombre, estado y fecha', () async {
      final membership = await membershipFrom(ok(accountHtml(
        name: 'Embajador',
        status: 'Activo',
        expires: '3 de marzo de 2027',
      )));

      expect(membership?.name, 'Embajador');
      expect(membership?.status, 'Activo');
      expect(membership?.expiresAt, '3 de marzo de 2027');
    });

    test('devuelve null si falta el nombre', () async {
      final membership = await membershipFrom(
        ok('<td data-th="Estado">Activo</td>'),
      );

      expect(membership, isNull);
    });

    test('devuelve null si falta el estado', () async {
      final membership = await membershipFrom(
        ok('<td data-th="Membresía">Premium</td>'),
      );

      expect(membership, isNull);
    });

    test('acepta el nombre sin tilde', () async {
      final membership = await membershipFrom(ok(
        '<td data-th="Membresia">Premium</td>'
        '<td data-th="Estado">Activo</td>',
      ));

      expect(membership?.name, 'Premium');
    });

    test('deja la fecha nula si no aparece', () async {
      final membership = await membershipFrom(ok(accountHtml(expires: null)));

      expect(membership?.expiresAt, isNull);
    });

    test('detecta que no hay boletín', () async {
      final membership = await membershipFrom(ok(accountHtml()));

      expect(membership?.hasNewsletter, isFalse);
    });

    test('devuelve null ante un error de red', () async {
      final service = AuthService(
        client: routedClient((url) {
          if (url.contains('mi-cuenta')) throw Exception('sin red');
          return {
            'admin-ajax.php': ok('nonce'),
            'users/me': ok(userMeBody()),
            'rcp_is_restricted': ok(restrictedPostBody()),
          };
        }),
      );

      final state = await service.loginWithCookies('cookie=1');

      expect(state.membership, isNull);
    });
  });

  group('getRestNonceWithStatus', () {
    test('devuelve el nonce con la sesión activa', () async {
      final service =
          AuthService(client: clientWithRoutes({'admin-ajax.php': ok('abc123')}));

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.nonce, 'abc123');
      expect(result.sessionExpired, isFalse);
    });

    test('recorta los espacios del nonce', () async {
      final service = AuthService(
          client: clientWithRoutes({'admin-ajax.php': ok('  abc123  ')}));

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.nonce, 'abc123');
    });

    test('marca sesión expirada ante un 400', () async {
      final service = AuthService(
        client: clientWithRoutes({'admin-ajax.php': http.Response('0', 400)}),
      );

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.nonce, isNull);
      expect(result.sessionExpired, isTrue);
    });

    test('marca sesión expirada si el cuerpo es "0" con estado 200', () async {
      final service =
          AuthService(client: clientWithRoutes({'admin-ajax.php': ok('0')}));

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.sessionExpired, isTrue);
    });

    test('no marca expiración ante un error de servidor', () async {
      final service = AuthService(
        client: clientWithRoutes({'admin-ajax.php': http.Response('', 503)}),
      );

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.nonce, isNull);
      expect(result.sessionExpired, isFalse);
    });

    test('no marca expiración con un 200 de cuerpo vacío', () async {
      final service =
          AuthService(client: clientWithRoutes({'admin-ajax.php': ok('')}));

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.nonce, isNull);
      expect(result.sessionExpired, isFalse);
    });

    test('no marca expiración ante un fallo de red', () async {
      final service = AuthService(
        client: MockClient((_) async => throw Exception('sin red')),
      );

      final result = await service.getRestNonceWithStatus('cookie=1');

      expect(result.nonce, isNull);
      expect(result.sessionExpired, isFalse);
    });
  });

  group('getRestNonce', () {
    test('devuelve el nonce recortado', () async {
      final service = AuthService(
          client: clientWithRoutes({'admin-ajax.php': ok(' nonce-x \n')}));

      expect(await service.getRestNonce('cookie=1'), 'nonce-x');
    });

    test('devuelve null si el cuerpo viene vacío', () async {
      final service =
          AuthService(client: clientWithRoutes({'admin-ajax.php': ok('')}));

      expect(await service.getRestNonce('cookie=1'), isNull);
    });

    test('devuelve null ante un error de servidor', () async {
      final service = AuthService(
        client: clientWithRoutes({'admin-ajax.php': http.Response('x', 500)}),
      );

      expect(await service.getRestNonce('cookie=1'), isNull);
    });

    test('devuelve null ante un fallo de red', () async {
      final service = AuthService(
        client: MockClient((_) async => throw Exception('sin red')),
      );

      expect(await service.getRestNonce('cookie=1'), isNull);
    });
  });

  group('continueAsGuest y logout', () {
    test('continueAsGuest persiste el estado de invitado', () async {
      final service = AuthService(client: clientWithRoutes({}));

      final state = await service.continueAsGuest();

      expect(state.isGuest, isTrue);
      expect(storage['dlg_session_status'], 'guest');
    });

    test('logout borra todo el almacenamiento', () async {
      storage
        ..['dlg_session_status'] = 'loggedIn'
        ..['dlg_cookies'] = 'cookie=1';
      final service = AuthService(client: clientWithRoutes({}));

      await service.logout();

      expect(storage, isEmpty);
    });
  });

  group('NonceResult', () {
    test('guarda los valores que recibe', () {
      const result = NonceResult(nonce: 'abc', sessionExpired: false);

      expect(result.nonce, 'abc');
      expect(result.sessionExpired, isFalse);
    });
  });
}
