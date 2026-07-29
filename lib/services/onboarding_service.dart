import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Controla si el usuario ya ha visto la pantalla de bienvenida.
class OnboardingService {
  static const _key = 'dlg_onboarding_done';
  static final _storage = FlutterSecureStorage();

  static bool _completed = false;
  static bool get completed => _completed;

  /// Lee el estado guardado. Ante cualquier error asume que ya se completó
  /// para no mostrar el onboarding repetidamente.
  static Future<void> initialize() async {
    try {
      final value = await _storage.read(key: _key);
      _completed = value == 'true';
    } catch (e) {
      if (kDebugMode) debugPrint('👋 [Onboarding] Error leyendo estado: $e');
      _completed = true;
    }
  }

  static Future<void> complete() async {
    _completed = true;
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (e) {
      if (kDebugMode) debugPrint('👋 [Onboarding] Error guardando estado: $e');
    }
  }

  /// Solo para depuración — permite volver a ver el onboarding.
  static Future<void> reset() async {
    _completed = false;
    await _storage.delete(key: _key);
  }
}
