import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/auth_state.dart';
import '../models/auth_exception.dart';
import 'logging_http_client.dart';

class AuthService {
  static const String _siteUrl = 'https://www.descifrandolaguerra.es';
  static const String _apiUrl = '$_siteUrl/wp-json/wp/v2';

  static const String _keyCookies = 'dlg_cookies';
  static const String _keyEmail = 'dlg_user_email';
  static const String _keyDisplayName = 'dlg_user_display_name';
  static const String _keyIsSubscriber = 'dlg_is_subscriber';
  static const String _keySessionStatus = 'dlg_session_status';
  static const String _keyMembershipName = 'dlg_membership_name';
  static const String _keyMembershipStatus = 'dlg_membership_status';
  static const String _keyMembershipExpires = 'dlg_membership_expires';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? LoggingHttpClient();

  // ─── Sesión guardada ────────────────────────────────────────────────────────

  Future<AuthState> loadSavedSession() async {
    final savedStatus = await _storage.read(key: _keySessionStatus);
    if (savedStatus == null) return const AuthState.unknown();
    if (savedStatus == 'guest') return const AuthState.guest();
    if (savedStatus == 'loggedIn') {
      final cookies = await _storage.read(key: _keyCookies);
      if (cookies == null || cookies.isEmpty) return const AuthState.unknown();

      final membershipName = await _storage.read(key: _keyMembershipName);
      final membershipStatus = await _storage.read(key: _keyMembershipStatus);
      final membershipExpires = await _storage.read(key: _keyMembershipExpires);

      MembershipInfo? membership;
      if (membershipName != null && membershipStatus != null) {
        membership = MembershipInfo(
          name: membershipName,
          status: membershipStatus,
          expiresAt: membershipExpires,
        );
      }

      return AuthState(
        status: SessionStatus.loggedIn,
        cookies: cookies,
        userEmail: await _storage.read(key: _keyEmail),
        userDisplayName: await _storage.read(key: _keyDisplayName),
        isSubscriber: (await _storage.read(key: _keyIsSubscriber)) == 'true',
        membership: membership,
      );
    }
    return const AuthState.unknown();
  }

  // ─── Login con cookies del WebView ─────────────────────────────────────────
  // Las credenciales NUNCA pasan por Flutter — el usuario las escribe
  // directamente en el WebView. Aquí solo recibimos las cookies resultantes.

  Future<AuthState> loginWithCookies(String cookieString) async {
    if (cookieString.isEmpty) {
      throw const AuthException('No se pudo completar el inicio de sesión.');
    }

    debugPrint('🔐 [Auth] Verificando sesión con cookies del WebView...');

    final userData = await _fetchUserData(cookieString);
    debugPrint('🔐 [Auth] Datos usuario: $userData');

    // Obtener datos de membresía desde /mi-cuenta/
    final membership = await _fetchMembership(cookieString);
    debugPrint('🔐 [Auth] Membresía: ${membership?.name} / ${membership?.status}');

    final state = AuthState(
      status: SessionStatus.loggedIn,
      cookies: cookieString,
      userEmail: userData['email'],
      userDisplayName: userData['displayName'],
      isSubscriber: userData['isSubscriber'] as bool,
      membership: membership,
    );

    await _persistSession(state);
    return state;
  }

  // ─── Membresía ──────────────────────────────────────────────────────────────

  /// Parsea los datos de membresía desde el HTML de /mi-cuenta/
  Future<MembershipInfo?> _fetchMembership(String cookies) async {
    try {
      final response = await _client.get(
        Uri.parse('$_siteUrl/mi-cuenta/'),
        headers: {'Cookie': cookies},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final html = response.body;

      // Buscar dentro de #rcp-account-overview los span[data-th]
      final nameRegex = RegExp(
        "data-th=[\"']Membres[íi]a[\"'][^>]*>([^<]+)<",
        caseSensitive: false,
      );
      final statusRegex = RegExp(
        "data-th=[\"']Estado[\"'][^>]*>([^<]+)<",
        caseSensitive: false,
      );
      final expiresRegex = RegExp(
        "data-th=[\"']Expiration[^\"']*[\"'][^>]*>([^<]+)<",
        caseSensitive: false,
      );

      final nameMatch = nameRegex.firstMatch(html);
      final statusMatch = statusRegex.firstMatch(html);
      final expiresMatch = expiresRegex.firstMatch(html);

      if (nameMatch == null || statusMatch == null) return null;

      return MembershipInfo(
        name: nameMatch.group(1)!.trim(),
        status: statusMatch.group(1)!.trim(),
        expiresAt: expiresMatch?.group(1)?.trim(),
      );
    } catch (e) {
      debugPrint('🔐 [Auth] Error obteniendo membresía: $e');
      return null;
    }
  }

  // ─── Guest ──────────────────────────────────────────────────────────────────

  Future<AuthState> continueAsGuest() async {
    await _storage.write(key: _keySessionStatus, value: 'guest');
    return const AuthState.guest();
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// Obtiene el nonce REST para usar en peticiones autenticadas.
  /// Llamar con las cookies de sesión activas.
  Future<String?> getRestNonce(String cookies) => _fetchRestNonce(cookies);
  /// Lo obtenemos llamando al endpoint wp-admin/admin-ajax.php con las cookies activas.
  Future<String?> _fetchRestNonce(String cookies) async {
    try {
      final response = await _client.get(
        Uri.parse('$_siteUrl/wp-admin/admin-ajax.php?action=rest-nonce'),
        headers: {'Cookie': cookies},
      ).timeout(const Duration(seconds: 10));

      debugPrint('🔐 [Auth] rest-nonce status: ${response.statusCode}');
      debugPrint('🔐 [Auth] rest-nonce body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return response.body.trim();
      }
    } catch (e) {
      debugPrint('🔐 [Auth] Error obteniendo REST nonce: $e');
    }

    // Fallback: obtener nonce desde wp-json directamente
    try {
      final response = await _client.get(
        Uri.parse('$_siteUrl/?rest_route=/'),
        headers: {'Cookie': cookies},
      ).timeout(const Duration(seconds: 10));

      final nonceHeader = response.headers['x-wp-nonce'];
      if (nonceHeader != null && nonceHeader.isNotEmpty) {
        debugPrint('🔐 [Auth] REST nonce (header fallback): $nonceHeader');
        return nonceHeader;
      }
    } catch (e) {
      debugPrint('🔐 [Auth] Error en fallback nonce: $e');
    }

    return null;
  }

  Future<Map<String, dynamic>> _fetchUserData(String cookies) async {
    try {
      final restNonce = await _fetchRestNonce(cookies);
      debugPrint('🔐 [Auth] REST nonce obtenido: $restNonce');

      final headers = <String, String>{'Cookie': cookies};
      if (restNonce != null) headers['X-WP-Nonce'] = restNonce;

      // Obtener datos básicos del usuario
      final response = await _client.get(
        Uri.parse('$_apiUrl/users/me?_fields=id,name,email'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('🔐 [Auth] /users/me status: ${response.statusCode}');
      debugPrint('🔐 [Auth] /users/me body: ${response.body}');

      if (response.statusCode != 200) {
        return {'email': '', 'displayName': '', 'isSubscriber': false};
      }

      final data = jsonDecode(response.body);
      final userId = data['id'];

      // Verificar suscripción via RCP
      final isSubscriber = await _checkRcpSubscription(
          cookies, headers, userId);
      debugPrint('🔐 [Auth] isSubscriber: $isSubscriber');

      return {
        'email': data['email'] ?? '',
        'displayName': data['name'] ?? '',
        'isSubscriber': isSubscriber,
      };
    } catch (e) {
      debugPrint('🔐 [Auth] Error fetchUserData: $e');
      return {'email': '', 'displayName': '', 'isSubscriber': false};
    }
  }

  /// Comprueba si el usuario tiene suscripción activa en RCP
  /// intentando acceder a un artículo restringido
  Future<bool> _checkRcpSubscription(
      String cookies,
      Map<String, String> headers,
      dynamic userId) async {
    try {
      // Método 1: endpoint de membresías de RCP
      final rcpResponse = await _client.get(
        Uri.parse('$_siteUrl/wp-json/rcp/v1/memberships?customer_id=$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('🔐 [Auth] RCP memberships status: ${rcpResponse.statusCode}');
      debugPrint('🔐 [Auth] RCP memberships body: ${rcpResponse.body}');

      if (rcpResponse.statusCode == 200) {
        final memberships = jsonDecode(rcpResponse.body);
        if (memberships is List && memberships.isNotEmpty) {
          // Verificar si alguna membresía está activa
          return memberships.any((m) =>
              m['status'] == 'active' || m['status'] == 'free');
        }
      }

      // Método 2: intentar leer un post restringido — si devuelve contenido
      // es suscriptor, si devuelve vacío no lo es
      final testResponse = await _client.get(
        Uri.parse(
            '$_apiUrl/posts?per_page=1&_fields=id,content&rcp_is_restricted=1'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('🔐 [Auth] Test restricted post status: ${testResponse.statusCode}');

      if (testResponse.statusCode == 200) {
        final posts = jsonDecode(testResponse.body) as List;
        if (posts.isNotEmpty) {
          final content = posts.first['content']?['rendered'] ?? '';
          return content.isNotEmpty;
        }
      }
    } catch (e) {
      debugPrint('🔐 [Auth] Error checkRcpSubscription: $e');
    }

    return false;
  }

  // ─── Persistencia ───────────────────────────────────────────────────────────

  Future<void> _persistSession(AuthState state) async {
    await _storage.write(key: _keySessionStatus, value: 'loggedIn');
    await _storage.write(key: _keyCookies, value: state.cookies ?? '');
    await _storage.write(key: _keyEmail, value: state.userEmail ?? '');
    await _storage.write(key: _keyDisplayName, value: state.userDisplayName ?? '');
    await _storage.write(
        key: _keyIsSubscriber, value: state.isSubscriber.toString());
    if (state.membership != null) {
      await _storage.write(
          key: _keyMembershipName, value: state.membership!.name);
      await _storage.write(
          key: _keyMembershipStatus, value: state.membership!.status);
      await _storage.write(
          key: _keyMembershipExpires, value: state.membership!.expiresAt ?? '');
    }
  }
}