import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:dlg_app/models/auth_exception.dart';
import 'package:dlg_app/models/auth_state.dart';
import 'package:dlg_app/services/auth_notifier.dart';
import 'package:dlg_app/services/auth_service.dart';

/// Doble de AuthService que devuelve respuestas programadas y registra
/// las llamadas recibidas.
class FakeAuthService extends AuthService {
  FakeAuthService();

  AuthState savedSession = const AuthState.unknown();
  bool membershipStale = false;
  AuthState? refreshedMembership;
  NonceResult nonceResult =
      const NonceResult(nonce: null, sessionExpired: false);
  AuthState? loginResult;
  Object? loginError;
  String? nonceAfterLogin;

  int logoutCalls = 0;
  int refreshMembershipCalls = 0;
  int nonceCalls = 0;
  final List<String> loginCookies = [];

  @override
  String? get lastNonce => nonceAfterLogin;

  @override
  Future<AuthState> loadSavedSession() async => savedSession;

  @override
  Future<bool> isMembershipStale() async => membershipStale;

  @override
  Future<AuthState?> refreshMembership(String cookies) async {
    refreshMembershipCalls++;
    return refreshedMembership;
  }

  @override
  Future<NonceResult> getRestNonceWithStatus(String cookies) async {
    nonceCalls++;
    return nonceResult;
  }

  @override
  Future<AuthState> loginWithCookies(String cookieString, {void Function(String step, double progress)? onProgress}) async {
    loginCookies.add(cookieString);
    onProgress?.call('Obteniendo sesión...', 0.33);
    if (loginError != null) throw loginError!;
    return loginResult ?? const AuthState.unknown();
  }

  @override
  Future<AuthState> continueAsGuest() async => const AuthState.guest();

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

/// path_provider falso para que ArticleCache pueda escribir en disco cuando
/// AuthNotifier limpia el contenido exclusivo.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Estado de sesión iniciada listo para usar en los tests.
AuthState loggedIn({
  bool isSubscriber = false,
  String cookies = 'wordpress_logged_in=abc',
}) =>
    AuthState(
      status: SessionStatus.loggedIn,
      cookies: cookies,
      userEmail: 'lector@ejemplo.es',
      userDisplayName: 'Lector',
      isSubscriber: isSubscriber,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('dlg_auth_notifier_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Estado inicial', () {
    test('arranca inicializando y sin sesión', () {
      final notifier = AuthNotifier(service: FakeAuthService());

      expect(notifier.initializing, isTrue);
      expect(notifier.isLoading, isFalse);
      expect(notifier.state.status, SessionStatus.unknown);
      expect(notifier.errorMessage, isNull);
      expect(notifier.restNonce, isNull);
      expect(notifier.sessionExpired, isFalse);
    });

    test('crea un AuthService propio si no se le pasa ninguno', () {
      expect(() => AuthNotifier(), returnsNormally);
    });
  });

  group('initialize', () {
    test('marca la inicialización como terminada sin sesión guardada',
        () async {
      final service = FakeAuthService();
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.initializing, isFalse);
      expect(notifier.state.status, SessionStatus.unknown);
      expect(service.nonceCalls, 0,
          reason: 'sin sesión no debe pedirse el nonce');
    });

    test('no valida la membresía si no está obsoleta', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn(isSubscriber: true)
        ..membershipStale = false
        ..nonceResult =
            const NonceResult(nonce: 'abc123', sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(service.refreshMembershipCalls, 0);
      expect(notifier.state.isSubscriber, isTrue);
    });

    test('valida la membresía cuando está obsoleta', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn(isSubscriber: true)
        ..membershipStale = true
        ..refreshedMembership = loggedIn(isSubscriber: true)
        ..nonceResult =
            const NonceResult(nonce: 'abc123', sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(service.refreshMembershipCalls, 1);
      expect(notifier.state.isSubscriber, isTrue);
    });

    test('conserva el estado previo si el refresco devuelve null', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn(isSubscriber: true)
        ..membershipStale = true
        ..refreshedMembership = null
        ..nonceResult =
            const NonceResult(nonce: 'abc123', sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.state.isSubscriber, isTrue,
          reason: 'un fallo de red no debe degradar la suscripción');
    });

    test('limpia el contenido exclusivo cuando caduca la suscripción',
        () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn(isSubscriber: true)
        ..membershipStale = true
        ..refreshedMembership = loggedIn(isSubscriber: false)
        ..nonceResult =
            const NonceResult(nonce: 'abc123', sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.state.isSubscriber, isFalse);
    });

    test('no limpia caché si nunca fue suscriptor', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn(isSubscriber: false)
        ..membershipStale = true
        ..refreshedMembership = loggedIn(isSubscriber: false)
        ..nonceResult =
            const NonceResult(nonce: 'abc123', sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.state.isSubscriber, isFalse);
    });

    test('guarda el nonce cuando la sesión sigue activa', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult =
            const NonceResult(nonce: 'nonce-vivo', sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.restNonce, 'nonce-vivo');
      expect(notifier.sessionExpired, isFalse);
      expect(notifier.state.isLoggedIn, isTrue);
    });

    test('cierra la sesión cuando el nonce indica que ha expirado', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult = const NonceResult(nonce: null, sessionExpired: true);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.sessionExpired, isTrue);
      expect(notifier.restNonce, isNull);
      expect(notifier.state.status, SessionStatus.unknown);
      expect(service.logoutCalls, 1);
    });

    test('un error de red no cierra la sesión', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult = const NonceResult(nonce: null, sessionExpired: false);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(notifier.sessionExpired, isFalse);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(service.logoutCalls, 0);
    });

    test('no pide el nonce si la sesión guardada es de invitado', () async {
      final service = FakeAuthService()..savedSession = const AuthState.guest();
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(service.nonceCalls, 0);
      expect(notifier.state.isGuest, isTrue);
    });

    test('no pide el nonce si la sesión no tiene cookies', () async {
      final service = FakeAuthService()
        ..savedSession = const AuthState(status: SessionStatus.loggedIn);
      final notifier = AuthNotifier(service: service);

      await notifier.initialize();

      expect(service.nonceCalls, 0);
    });

    test('notifica antes y después de resolver el nonce', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult = const NonceResult(nonce: 'abc', sessionExpired: false);
      final notifier = AuthNotifier(service: service);
      var notifications = 0;
      notifier.addListener(() => notifications++);

      await notifier.initialize();

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });

  group('loginWithCookies', () {
    test('guarda el estado y el nonce tras un login correcto', () async {
      final service = FakeAuthService()
        ..loginResult = loggedIn(isSubscriber: true)
        ..nonceAfterLogin = 'nonce-login';
      final notifier = AuthNotifier(service: service);

      await notifier.loginWithCookies('wordpress_logged_in=xyz');

      expect(notifier.state.isLoggedIn, isTrue);
      expect(notifier.state.isSubscriber, isTrue);
      expect(notifier.restNonce, 'nonce-login');
      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(service.loginCookies.single, 'wordpress_logged_in=xyz');
    });

    test('marca isLoading mientras la petición está en curso', () async {
      final service = FakeAuthService()..loginResult = loggedIn();
      final notifier = AuthNotifier(service: service);

      var sawLoading = false;
      notifier.addListener(() {
        if (notifier.isLoading) sawLoading = true;
      });

      await notifier.loginWithCookies('cookie');

      expect(sawLoading, isTrue);
      expect(notifier.isLoading, isFalse);
    });

    test('muestra el mensaje de una AuthException', () async {
      final service = FakeAuthService()
        ..loginError = const AuthException('Credenciales no válidas');
      final notifier = AuthNotifier(service: service);

      await notifier.loginWithCookies('cookie');

      expect(notifier.errorMessage, 'Credenciales no válidas');
      expect(notifier.isLoading, isFalse);
    });

    test('muestra un mensaje genérico ante cualquier otro error', () async {
      final service = FakeAuthService()..loginError = StateError('roto');
      final notifier = AuthNotifier(service: service);

      await notifier.loginWithCookies('cookie');

      expect(notifier.errorMessage,
          'Error al verificar la sesión. Inténtalo de nuevo.');
      expect(notifier.isLoading, isFalse);
    });

    test('limpia el aviso de sesión expirada al iniciar sesión', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult = const NonceResult(nonce: null, sessionExpired: true);
      final notifier = AuthNotifier(service: service);
      await notifier.initialize();
      expect(notifier.sessionExpired, isTrue);

      service.loginResult = loggedIn();
      await notifier.loginWithCookies('cookie');

      expect(notifier.sessionExpired, isFalse);
    });

    test('limpia un error anterior al reintentar', () async {
      final service = FakeAuthService()
        ..loginError = const AuthException('Fallo');
      final notifier = AuthNotifier(service: service);
      await notifier.loginWithCookies('cookie');
      expect(notifier.errorMessage, isNotNull);

      service.loginError = null;
      service.loginResult = loggedIn();
      await notifier.loginWithCookies('cookie');

      expect(notifier.errorMessage, isNull);
    });
  });

  group('continueAsGuest', () {
    test('deja el estado como invitado', () async {
      final notifier = AuthNotifier(service: FakeAuthService());
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.continueAsGuest();

      expect(notifier.state.isGuest, isTrue);
      expect(notified, isTrue);
    });
  });

  group('logout', () {
    test('limpia todo el estado', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult = const NonceResult(nonce: 'abc', sessionExpired: false);
      final notifier = AuthNotifier(service: service);
      await notifier.initialize();

      await notifier.logout();

      expect(notifier.state.status, SessionStatus.unknown);
      expect(notifier.restNonce, isNull);
      expect(notifier.errorMessage, isNull);
      expect(notifier.sessionExpired, isFalse);
      expect(service.logoutCalls, 1);
    });

    test('notifica a los oyentes', () async {
      final notifier = AuthNotifier(service: FakeAuthService());
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.logout();

      expect(notified, isTrue);
    });
  });

  group('renewRestNonce', () {
    test('devuelve null si no hay cookies', () async {
      final service = FakeAuthService();
      final notifier = AuthNotifier(service: service);

      final result = await notifier.renewRestNonce();

      expect(result, isNull);
      expect(service.nonceCalls, 0);
    });

    test('devuelve el nonce renovado', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult =
            const NonceResult(nonce: 'primero', sessionExpired: false);
      final notifier = AuthNotifier(service: service);
      await notifier.initialize();

      service.nonceResult =
          const NonceResult(nonce: 'renovado', sessionExpired: false);
      final result = await notifier.renewRestNonce();

      expect(result, 'renovado');
      expect(notifier.restNonce, 'renovado');
    });

    test('cierra la sesión si el nonce indica expiración', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult =
            const NonceResult(nonce: 'primero', sessionExpired: false);
      final notifier = AuthNotifier(service: service);
      await notifier.initialize();

      service.nonceResult =
          const NonceResult(nonce: null, sessionExpired: true);
      final result = await notifier.renewRestNonce();

      expect(result, isNull);
      expect(notifier.sessionExpired, isTrue);
      expect(notifier.restNonce, isNull);
      expect(notifier.state.status, SessionStatus.unknown);
      expect(service.logoutCalls, 1);
    });

    test('un fallo de red devuelve null sin cerrar sesión', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult =
            const NonceResult(nonce: 'primero', sessionExpired: false);
      final notifier = AuthNotifier(service: service);
      await notifier.initialize();

      service.nonceResult =
          const NonceResult(nonce: null, sessionExpired: false);
      final result = await notifier.renewRestNonce();

      expect(result, isNull);
      expect(notifier.state.isLoggedIn, isTrue);
      expect(service.logoutCalls, 0);
    });
  });

  group('clearError y clearSessionExpired', () {
    test('clearError borra el mensaje y notifica', () async {
      final service = FakeAuthService()
        ..loginError = const AuthException('Fallo');
      final notifier = AuthNotifier(service: service);
      await notifier.loginWithCookies('cookie');
      expect(notifier.errorMessage, isNotNull);

      var notified = false;
      notifier.addListener(() => notified = true);
      notifier.clearError();

      expect(notifier.errorMessage, isNull);
      expect(notified, isTrue);
    });

    test('clearSessionExpired baja la bandera y notifica', () async {
      final service = FakeAuthService()
        ..savedSession = loggedIn()
        ..nonceResult = const NonceResult(nonce: null, sessionExpired: true);
      final notifier = AuthNotifier(service: service);
      await notifier.initialize();
      expect(notifier.sessionExpired, isTrue);

      var notified = false;
      notifier.addListener(() => notified = true);
      notifier.clearSessionExpired();

      expect(notifier.sessionExpired, isFalse);
      expect(notified, isTrue);
    });
  });
}
