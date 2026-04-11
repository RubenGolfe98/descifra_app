import 'package:flutter/foundation.dart';
import '../models/auth_state.dart';
import '../models/auth_exception.dart';
import 'auth_service.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _service;

  AuthState _state = const AuthState.unknown();
  bool _initializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _restNonce; // caché del nonce REST

  AuthNotifier({AuthService? service})
      : _service = service ?? AuthService();

  AuthState get state => _state;
  bool get initializing => _initializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get restNonce => _restNonce;

  Future<void> initialize() async {
    _state = await _service.loadSavedSession();
    _initializing = false;
    notifyListeners();
    // Pre-cargar el nonce REST si hay sesión activa
    if (_state.isLoggedIn && _state.cookies != null) {
      _restNonce = await _service.getRestNonce(_state.cookies!);
      debugPrint('🔐 [Auth] Nonce REST pre-cargado: $_restNonce');
      notifyListeners();
    }
  }

  /// Recibe las cookies extraídas del WebView — las credenciales
  /// nunca pasan por aquí, solo la sesión ya autenticada
  Future<void> loginWithCookies(String cookieString) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final newState = await _service.loginWithCookies(cookieString);
      _state = newState;
      // Guardar nonce REST en caché tras login exitoso
      if (newState.cookies != null) {
        _restNonce = await _service.getRestNonce(newState.cookies!);
        debugPrint('🔐 [Auth] Nonce REST tras login: $_restNonce');
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
    } catch (e, stack) {
      debugPrint('Login error: $e\n$stack');
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}