import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/services/connectivity_service.dart';

/// Implementación de plataforma controlada por el test: devuelve el estado
/// inicial que se le indique y permite emitir cambios a voluntad.
class FakeConnectivityPlatform extends ConnectivityPlatform {
  FakeConnectivityPlatform({
    this.initial = const [ConnectivityResult.wifi],
    this.throwOnCheck = false,
  });

  List<ConnectivityResult> initial;
  bool throwOnCheck;

  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  int checkCalls = 0;

  /// Emite un cambio de conectividad hacia el servicio.
  void emit(List<ConnectivityResult> results) => _controller.add(results);

  Future<void> close() => _controller.close();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCalls++;
    if (throwOnCheck) throw Exception('sin plataforma');
    return initial;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;
}

/// Espera a que se resuelva la inicialización asíncrona del servicio.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeConnectivityPlatform platform;

  setUp(() {
    platform = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = platform;
  });

  tearDown(() async {
    await platform.close();
  });

  group('Estado inicial', () {
    test('consulta el estado real al construirse', () async {
      final service = ConnectivityService();
      await settle();

      expect(platform.checkCalls, 1);

      service.dispose();
    });

    test('queda online si el dispositivo tiene wifi', () async {
      platform.initial = [ConnectivityResult.wifi];
      final service = ConnectivityService();
      await settle();

      expect(service.isOnline, isTrue);

      service.dispose();
    });

    test('queda offline si no hay ninguna conexión', () async {
      platform.initial = [ConnectivityResult.none];
      final service = ConnectivityService();
      await settle();

      expect(service.isOnline, isFalse);

      service.dispose();
    });

    test('queda offline con una lista vacía', () async {
      platform.initial = [];
      final service = ConnectivityService();
      await settle();

      expect(service.isOnline, isFalse);

      service.dispose();
    });

    test('notifica tras resolver el estado inicial', () async {
      final service = ConnectivityService();
      var notifications = 0;
      service.addListener(() => notifications++);
      await settle();

      expect(notifications, greaterThanOrEqualTo(1));

      service.dispose();
    });
  });

  group('Tipos de conexión', () {
    Future<bool> onlineWith(List<ConnectivityResult> results) async {
      platform.initial = results;
      final service = ConnectivityService();
      await settle();
      final online = service.isOnline;
      service.dispose();
      return online;
    }

    test('datos móviles cuentan como conexión', () async {
      expect(await onlineWith([ConnectivityResult.mobile]), isTrue);
    });

    test('wifi cuenta como conexión', () async {
      expect(await onlineWith([ConnectivityResult.wifi]), isTrue);
    });

    test('ethernet cuenta como conexión', () async {
      expect(await onlineWith([ConnectivityResult.ethernet]), isTrue);
    });

    test('vpn por sí sola no cuenta como conexión', () async {
      expect(await onlineWith([ConnectivityResult.vpn]), isFalse);
    });

    test('bluetooth por sí solo no cuenta como conexión', () async {
      expect(await onlineWith([ConnectivityResult.bluetooth]), isFalse);
    });

    test('other por sí solo no cuenta como conexión', () async {
      expect(await onlineWith([ConnectivityResult.other]), isFalse);
    });

    test('basta con que una de las conexiones sea válida', () async {
      expect(
        await onlineWith([ConnectivityResult.vpn, ConnectivityResult.wifi]),
        isTrue,
      );
    });

    test('varias conexiones no válidas siguen siendo sin conexión', () async {
      expect(
        await onlineWith(
            [ConnectivityResult.bluetooth, ConnectivityResult.none]),
        isFalse,
      );
    });
  });

  group('Cambios de conectividad', () {
    test('pasa a offline cuando se pierde la conexión', () async {
      platform.initial = [ConnectivityResult.wifi];
      final service = ConnectivityService();
      await settle();

      platform.emit([ConnectivityResult.none]);
      await settle();

      expect(service.isOnline, isFalse);

      service.dispose();
    });

    test('vuelve a online cuando se recupera la conexión', () async {
      platform.initial = [ConnectivityResult.none];
      final service = ConnectivityService();
      await settle();
      expect(service.isOnline, isFalse);

      platform.emit([ConnectivityResult.mobile]);
      await settle();

      expect(service.isOnline, isTrue);

      service.dispose();
    });

    test('notifica en cada cambio real de estado', () async {
      platform.initial = [ConnectivityResult.wifi];
      final service = ConnectivityService();
      await settle();

      var notifications = 0;
      service.addListener(() => notifications++);

      platform.emit([ConnectivityResult.none]);
      await settle();
      platform.emit([ConnectivityResult.wifi]);
      await settle();

      expect(notifications, 2);

      service.dispose();
    });

    test('no notifica si el estado no cambia', () async {
      platform.initial = [ConnectivityResult.wifi];
      final service = ConnectivityService();
      await settle();

      var notifications = 0;
      service.addListener(() => notifications++);

      platform.emit([ConnectivityResult.wifi]);
      await settle();
      platform.emit([ConnectivityResult.ethernet]);
      await settle();

      expect(notifications, 0,
          reason: 'seguir online no es un cambio de estado');

      service.dispose();
    });

    test('no notifica al repetir el estado offline', () async {
      platform.initial = [ConnectivityResult.none];
      final service = ConnectivityService();
      await settle();

      var notifications = 0;
      service.addListener(() => notifications++);

      platform.emit([ConnectivityResult.none]);
      await settle();

      expect(notifications, 0);

      service.dispose();
    });

    test('sigue varios cambios encadenados', () async {
      platform.initial = [ConnectivityResult.wifi];
      final service = ConnectivityService();
      await settle();

      platform.emit([ConnectivityResult.none]);
      await settle();
      expect(service.isOnline, isFalse);

      platform.emit([ConnectivityResult.mobile]);
      await settle();
      expect(service.isOnline, isTrue);

      platform.emit([ConnectivityResult.none]);
      await settle();
      expect(service.isOnline, isFalse);

      service.dispose();
    });
  });

  group('dispose', () {
    test('deja de reaccionar a los cambios tras liberarse', () async {
      platform.initial = [ConnectivityResult.wifi];
      final service = ConnectivityService();
      await settle();

      service.dispose();

      // Emitir después de dispose no debe provocar ningún error.
      platform.emit([ConnectivityResult.none]);
      await settle();

      expect(service.isOnline, isTrue);
    });

    test('puede liberarse sin lanzar excepción', () async {
      final service = ConnectivityService();
      await settle();

      expect(service.dispose, returnsNormally);
    });
  });
}
