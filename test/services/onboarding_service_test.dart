import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/services/onboarding_service.dart';

const _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _key = 'dlg_onboarding_done';

/// Almacenamiento en memoria que sustituye a flutter_secure_storage.
late Map<String, String> storage;

/// Métodos que deben lanzar una excepción en el test en curso.
late Set<String> failingMethods;

/// Registro de las llamadas recibidas por el canal.
late List<String> calls;

void installStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    calls.add(call.method);
    if (failingMethods.contains(call.method)) {
      throw PlatformException(code: 'error', message: 'almacén no disponible');
    }
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
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    storage = {};
    failingMethods = {};
    calls = [];
    installStorage();
    // El estado es estático: se parte siempre de onboarding pendiente.
    await OnboardingService.reset();
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('initialize', () {
    test('queda pendiente si no hay nada guardado', () async {
      await OnboardingService.initialize();

      expect(OnboardingService.completed, isFalse);
    });

    test('queda completado si el valor guardado es "true"', () async {
      storage[_key] = 'true';

      await OnboardingService.initialize();

      expect(OnboardingService.completed, isTrue);
    });

    test('queda pendiente si el valor guardado es "false"', () async {
      storage[_key] = 'false';

      await OnboardingService.initialize();

      expect(OnboardingService.completed, isFalse);
    });

    test('queda pendiente ante un valor inesperado', () async {
      storage[_key] = 'sí';

      await OnboardingService.initialize();

      expect(OnboardingService.completed, isFalse);
    });

    test('asume completado si la lectura falla', () async {
      failingMethods.add('read');

      await OnboardingService.initialize();

      expect(OnboardingService.completed, isTrue,
          reason: 'ante un error no debe repetirse la bienvenida');
    });

    test('lee de la clave esperada', () async {
      await OnboardingService.initialize();

      expect(calls, contains('read'));
    });

    test('puede llamarse varias veces sin efectos raros', () async {
      storage[_key] = 'true';

      await OnboardingService.initialize();
      await OnboardingService.initialize();

      expect(OnboardingService.completed, isTrue);
    });

    test('refleja un cambio del almacenamiento entre llamadas', () async {
      await OnboardingService.initialize();
      expect(OnboardingService.completed, isFalse);

      storage[_key] = 'true';
      await OnboardingService.initialize();

      expect(OnboardingService.completed, isTrue);
    });
  });

  group('complete', () {
    test('marca el onboarding como completado y lo persiste', () async {
      await OnboardingService.complete();

      expect(OnboardingService.completed, isTrue);
      expect(storage[_key], 'true');
    });

    test('marca como completado aunque falle el guardado', () async {
      failingMethods.add('write');

      await OnboardingService.complete();

      expect(OnboardingService.completed, isTrue,
          reason: 'no debe repetirse la bienvenida en esta sesión');
      expect(storage.containsKey(_key), isFalse);
    });

    test('el estado sobrevive a una nueva inicialización', () async {
      await OnboardingService.complete();

      await OnboardingService.initialize();

      expect(OnboardingService.completed, isTrue);
    });

    test('es idempotente', () async {
      await OnboardingService.complete();
      await OnboardingService.complete();

      expect(OnboardingService.completed, isTrue);
      expect(storage[_key], 'true');
    });
  });

  group('reset', () {
    test('vuelve a dejar el onboarding pendiente', () async {
      await OnboardingService.complete();
      expect(OnboardingService.completed, isTrue);

      await OnboardingService.reset();

      expect(OnboardingService.completed, isFalse);
      expect(storage.containsKey(_key), isFalse);
    });

    test('tras reiniciar, initialize lo ve como pendiente', () async {
      await OnboardingService.complete();

      await OnboardingService.reset();
      await OnboardingService.initialize();

      expect(OnboardingService.completed, isFalse);
    });

    test('funciona aunque no hubiera nada guardado', () async {
      await expectLater(OnboardingService.reset(), completes);

      expect(OnboardingService.completed, isFalse);
    });
  });

  group('Ciclo completo', () {
    test('primer arranque, bienvenida vista y arranques posteriores',
        () async {
      // Primer arranque: no hay nada guardado.
      await OnboardingService.initialize();
      expect(OnboardingService.completed, isFalse);

      // El usuario termina la bienvenida.
      await OnboardingService.complete();
      expect(OnboardingService.completed, isTrue);

      // Arranques siguientes: ya está marcada.
      await OnboardingService.initialize();
      expect(OnboardingService.completed, isTrue);
    });
  });
}
