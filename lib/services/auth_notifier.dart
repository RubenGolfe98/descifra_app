import 'package:flutter/foundation.dart';
import '../models/auth_state.dart';
import '../models/auth_exception.dart';
import 'analytics_service.dart';
import 'article_cache.dart';
import 'auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const AuthState.unknown();
  bool _initializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _restNonce;

  AuthNotifier({AuthService? service})
      : _service = service ?? AuthService();

  AuthState get state => _state;
  bool get initializing => _initializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get restNonce => _restNonce;

  Future<void> initialize() async {
    _state = await _service.loadSavedSession();

    if (_state.isLoggedIn && _state.cookies != null) {
      final wasSubscriber = _state.isSubscriber;
      final stale = await _service.isMembershipStale();

      if (stale) {
        // Primera entrada del día — validar membresía ANTES de mostrar la app
        if (kDebugMode) debugPrint('🔐 [Auth] Primera entrada del día — validando membresía');
        final updated = await _service.refreshMembership(_state.cookies!);
        if (updated != null) {
          _state = updated;
          if (wasSubscriber && !updated.isSubscriber) {
            if (kDebugMode) debugPrint('🔐 [Auth] Suscripción expirada — limpiando caché');
            await ArticleCache().clearExclusiveContent();
          }
        }
      }
    }

    _initializing = false;
    notifyListeners();

    // Nonce REST en background — no bloquea el arranque
    if (_state.isLoggedIn && _state.cookies != null) {
      _service.getRestNonce(_state.cookies!).then((nonce) {
        _restNonce = nonce;
        if (kDebugMode) debugPrint('🔐 [Auth] Nonce REST pre-cargado: $_restNonce');
        notifyListeners();
      });
    }
  }

  /// Recibe las cookies extraídas del WebView
  Future<void> loginWithCookies(String cookieString) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newState = await _service.loginWithCookies(cookieString);
      _state = newState;
      _restNonce = _service.lastNonce;
      if (kDebugMode) debugPrint('🔐 [Auth] Nonce REST tras login: $_restNonce');
      AnalyticsService.logLoginSuccess();
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Login error: $e\n$stack');
      _errorMessage = 'Error al verificar la sesión. Inténtalo de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> continueAsGuest() async {
    _state = await _service.continueAsGuest();
    notifyListeners();
  }

  Future<void> logout() async {
    AnalyticsService.logLogout();
    await _service.logout();
    _state = const AuthState.unknown();
    _errorMessage = null;
    _restNonce = null;
    notifyListeners();
  }

  Future<String?> renewRestNonce() async {
    if (_state.cookies == null) return null;
    _restNonce = await _service.getRestNonce(_state.cookies!);
    if (kDebugMode) debugPrint('🔐 [Auth] Nonce REST renovado: $_restNonce');
    notifyListeners();
    return _restNonce;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}