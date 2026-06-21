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

      // Arrancamos la carga del nonce YA, en paralelo con cualquier
      // validación de membresía, para que esté listo cuando el
      // usuario toque un artículo premium.
      final nonceFuture = _service.getRestNonce(_state.cookies!);

      if (stale) {
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

      // Esperamos el nonce (ya debería haber llegado, corría en paralelo)
      _restNonce = await nonceFuture;
      if (kDebugMode) debugPrint('🔐 [Auth] Nonce REST pre-cargado: $_restNonce');
    }

    _initializing = false;
    notifyListeners();
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