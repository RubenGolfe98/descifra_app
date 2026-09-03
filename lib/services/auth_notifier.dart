import 'package:flutter/foundation.dart';
import '../models/auth_state.dart';
import '../models/auth_exception.dart';
import 'article_cache.dart';
import 'auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const AuthState.unknown();
  bool _initializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _restNonce;
  bool _sessionExpired = false;
  String? _loginStep;
  double _loginProgress = 0.0;

  AuthNotifier({AuthService? service}) : _service = service ?? AuthService();

  AuthState get state => _state;
  bool get initializing => _initializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get restNonce => _restNonce;
  bool get sessionExpired => _sessionExpired;
  String? get loginStep => _loginStep;
  double get loginProgress => _loginProgress;

  Future<void> initialize() async {
    _state = await _service.loadSavedSession();

    if (_state.isLoggedIn && _state.cookies != null) {
      final wasSubscriber = _state.isSubscriber;
      final stale = await _service.isMembershipStale();

      if (stale) {
        if (kDebugMode) {
          debugPrint('🔐 [Auth] Primera entrada del día — validando membresía');
        }
        final updated = await _service.refreshMembership(_state.cookies!);
        if (updated != null) {
          _state = updated;
          if (wasSubscriber && !updated.isSubscriber) {
            if (kDebugMode) {
              debugPrint('🔐 [Auth] Suscripción expirada — limpiando caché');
            }
            await ArticleCache().clearExclusiveContent();
          }
        }
      }
    }

    _initializing = false;
    notifyListeners();

    // Nonce REST en background — detectar sesión expirada
    if (_state.isLoggedIn && _state.cookies != null) {
      final nonceResult =
          await _service.getRestNonceWithStatus(_state.cookies!);
      _restNonce = nonceResult.nonce;

      if (nonceResult.sessionExpired) {
        if (kDebugMode) {
          debugPrint(
              '🔐 [Auth] Sesión de WordPress expirada — cerrando sesión');
        }
        _sessionExpired = true;
        await _service.logout();
        _state = const AuthState.unknown();
        _restNonce = null;
      } else {
        if (kDebugMode) {
          debugPrint('🔐 [Auth] Nonce REST pre-cargado: $_restNonce');
        }
      }
      notifyListeners();
    }
  }

  /// Recibe las cookies extraídas del WebView
  Future<void> loginWithCookies(String cookieString) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    _loginProgress = 0.0;
    notifyListeners();
    try {
      final newState = await _service.loginWithCookies(cookieString,
          onProgress: (String step, double progress) {
        _loginStep = step;
        _loginProgress = progress;
        notifyListeners();
      });
      _restNonce = _service.lastNonce;
      if (kDebugMode) {
        debugPrint('🔐 [Auth] Nonce REST tras login: $_restNonce');
      }
      // Mostrar el 100% un instante antes de cambiar a la vista de perfil,
      // para que la barra complete su animación.
      _loginProgress = 1.0;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 700));
      _state = newState;
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Login error: $e\n$stack');
      _errorMessage = 'Error al verificar la sesión. Inténtalo de nuevo.';
    } finally {
      _isLoading = false;
      _loginStep = null;
      _loginProgress = 0.0;
      notifyListeners();
    }
  }

  Future<void> continueAsGuest() async {
    _state = await _service.continueAsGuest();
    _loginProgress = 0.0;
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    _state = const AuthState.unknown();
    _errorMessage = null;
    _restNonce = null;
    _sessionExpired = false;
    _loginStep = null;
    _loginProgress = 0.0;
    notifyListeners();
  }

  Future<String?> renewRestNonce() async {
    if (_state.cookies == null) return null;
    final result = await _service.getRestNonceWithStatus(_state.cookies!);

    if (result.sessionExpired) {
      if (kDebugMode) {
        debugPrint(
            '🔐 [Auth] Sesión expirada al renovar nonce — cerrando sesión');
      }
      _sessionExpired = true;
      await _service.logout();
      _state = const AuthState.unknown();
      _restNonce = null;
      notifyListeners();
      return null;
    }

    _restNonce = result.nonce;
    if (kDebugMode) debugPrint('🔐 [Auth] Nonce REST renovado: $_restNonce');
    notifyListeners();
    return _restNonce;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSessionExpired() {
    _sessionExpired = false;
    notifyListeners();
  }
}
