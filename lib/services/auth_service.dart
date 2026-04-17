import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
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
  static const String _keyNewsletter = 'dlg_newsletter_html';

  static final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );

  final http.Client _client;
  String? _lastNonce; // Nonce obtenido durante el último login
  String? get lastNonce => _lastNonce;

  AuthService({http.Client? client}) : _client = client ?? LoggingHttpClient();

  // ─── Sesión guardada ────────────────────────────────────────────────────────

  Future<AuthState> loadSavedSession() async {
    final savedStatus = await _storage.read(key: _keySessionStatus);
    if (savedStatus == null) return const AuthState.unknown();
    if (savedStatus == 'guest') return const AuthState.guest();
    if (savedStatus == 'loggedIn') {
      final displayName = await _storage.read(key: _keyDisplayName);
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
          newsletterHtml: await _storage.read(key: _keyNewsletter),
        );
      }

      // Si el displayName está vacío (sesión antigua), intentar recuperarlo
      String? resolvedName = displayName;
      if (resolvedName == null || resolvedName.isEmpty) {
        try {
          final nonce = await _fetchRestNonce(cookies);
          final headers = <String, String>{'Cookie': cookies};
          if (nonce != null) headers['X-WP-Nonce'] = nonce;
          final resp = await _client
              .get(Uri.parse('$_apiUrl/users/me?_fields=id,name'), headers: headers)
              .timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            resolvedName = data['name'] as String?;
            if (resolvedName != null && resolvedName.isNotEmpty) {
              await _storage.write(key: _keyDisplayName, value: resolvedName);
            }
          }
        } catch (_) {}
      }

      return AuthState(
        status: SessionStatus.loggedIn,
        cookies: cookies,
        userEmail: await _storage.read(key: _keyEmail),
        userDisplayName: resolvedName,
        isSubscriber: (await _storage.read(key: _keyIsSubscriber)) == 'true',
        membership: membership,
      );
    }
    return const AuthState.unknown();
  }

  // ─── Login con cookies del WebView ─────────────────────────────────────────

  Future<AuthState> loginWithCookies(String cookieString) async {
    if (cookieString.isEmpty) {
      throw const AuthException('No se pudo completar el inicio de sesión.');
    }

    debugPrint('🔐 [Auth] Verificando sesión con cookies del WebView...');

    // Lanzar en paralelo: nonce + membresía desde /mi-cuenta/
    final results = await Future.wait([
      _fetchRestNonce(cookieString),
      _fetchMembership(cookieString),
    ]);

    final restNonce = results[0] as String?;
    final membership = results[1] as MembershipInfo?;
    _lastNonce = restNonce; // Cachear para que auth_notifier lo use sin nueva petición
    debugPrint('🔐 [Auth] REST nonce obtenido: $restNonce');
    debugPrint('🔐 [Auth] Membresía: ${membership?.name} / ${membership?.status}');

    // Obtener datos del usuario con el nonce ya disponible
    final headers = <String, String>{'Cookie': cookieString};
    if (restNonce != null) headers['X-WP-Nonce'] = restNonce;

    final userData = await _fetchUserData(cookieString, headers);
    debugPrint('🔐 [Auth] Datos usuario: $userData');

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

  // ─── Nonce REST ─────────────────────────────────────────────────────────────

  Future<String?> getRestNonce(String cookies) => _fetchRestNonce(cookies);

  Future<String?> _fetchRestNonce(String cookies) async {
    try {
      final response = await _client.get(
        Uri.parse('$_siteUrl/wp-admin/admin-ajax.php?action=rest-nonce'),
        headers: {'Cookie': cookies},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return response.body.trim();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 [Auth] Error obteniendo REST nonce: $e');
    }
    return null;
  }

  // ─── Datos del usuario ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchUserData(
      String cookies, Map<String, String> headers) async {
    try {
      // /users/me y verificación suscripción en paralelo
      final results = await Future.wait([
        _client.get(
          Uri.parse('$_apiUrl/users/me?_fields=id,name,email'),
          headers: headers,
        ).timeout(const Duration(seconds: 15)),
        _client.get(
          Uri.parse('$_apiUrl/posts?per_page=1&_fields=id,content&rcp_is_restricted=1'),
          headers: headers,
        ).timeout(const Duration(seconds: 15)),
      ]);

      final userResponse = results[0];
      final restrictedResponse = results[1];

      if (kDebugMode) debugPrint('🔐 [Auth] /users/me status: ${userResponse.statusCode}');
      if (kDebugMode) debugPrint('🔐 [Auth] Test restricted post status: ${restrictedResponse.statusCode}');

      if (userResponse.statusCode != 200) {
        return {'email': '', 'displayName': '', 'isSubscriber': false};
      }

      final data = jsonDecode(userResponse.body);

      bool isSubscriber = false;
      if (restrictedResponse.statusCode == 200) {
        final posts = jsonDecode(restrictedResponse.body) as List;
        if (posts.isNotEmpty) {
          final content = posts.first['content']?['rendered'] ?? '';
          isSubscriber = content.isNotEmpty;
        }
      }

      if (kDebugMode) debugPrint('🔐 [Auth] isSubscriber: $isSubscriber');

      return {
        'email': data['email'] ?? '',
        'displayName': data['name'] ?? '',
        'isSubscriber': isSubscriber,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 [Auth] Error fetchUserData: $e');
      return {'email': '', 'displayName': '', 'isSubscriber': false};
    }
  }

  // ─── Membresía desde /mi-cuenta/ ───────────────────────────────────────────

  Future<MembershipInfo?> _fetchMembership(String cookies) async {
    try {
      final response = await _client.get(
        Uri.parse('$_siteUrl/mi-cuenta/'),
        headers: {'Cookie': cookies},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final html = response.body;

      final nameRegex = RegExp(
        'data-th=["\']Membres[íi]a["\'][^>]*>([^<]+)<',
        caseSensitive: false,
      );
      final statusRegex = RegExp(
        'data-th=["\']Estado["\'][^>]*>([^<]+)<',
        caseSensitive: false,
      );
      final expiresRegex = RegExp(
        'data-th=["\']Expiration[^"\']*["\'][^>]*>([^<]+)<',
        caseSensitive: false,
      );

      final nameMatch = nameRegex.firstMatch(html);
      final statusMatch = statusRegex.firstMatch(html);
      final expiresMatch = expiresRegex.firstMatch(html);

      if (nameMatch == null || statusMatch == null) return null;

      // Extraer HTML del último boletín (tab Newsletter)
      String? newsletterHtml;
      final nlMatch = RegExp(
        r'id="elementor-tab-content-2441"[^>]*>([\s\S]*?)</div>\s*<div[^>]*elementor-tab-title[^>]*>[^<]*Guardado',
        caseSensitive: false,
      ).firstMatch(html);
      if (nlMatch != null) {
        newsletterHtml = nlMatch.group(1)?.trim();
      }

      return MembershipInfo(
        name: nameMatch.group(1)!.trim(),
        status: statusMatch.group(1)!.trim(),
        expiresAt: expiresMatch?.group(1)?.trim(),
        newsletterHtml: newsletterHtml,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('🔐 [Auth] Error obteniendo membresía: $e');
      return null;
    }
  }

  // ─── Guest / Logout ─────────────────────────────────────────────────────────

  Future<AuthState> continueAsGuest() async {
    await _storage.write(key: _keySessionStatus, value: 'guest');
    return const AuthState.guest();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    try {
      final cookieManager = webview.CookieManager.instance();
      await cookieManager.deleteAllCookies();
    } catch (_) {}
  }

  // ─── Persistencia ───────────────────────────────────────────────────────────

  Future<void> _persistSession(AuthState state) async {
    await _storage.write(key: _keySessionStatus, value: 'loggedIn');
    await _storage.write(key: _keyCookies, value: state.cookies ?? '');
    await _storage.write(key: _keyEmail, value: state.userEmail ?? '');
    await _storage.write(key: _keyDisplayName, value: state.userDisplayName ?? '');
    await _storage.write(key: _keyIsSubscriber, value: state.isSubscriber.toString());
    if (state.membership != null) {
      await _storage.write(key: _keyMembershipName, value: state.membership!.name);
      await _storage.write(key: _keyMembershipStatus, value: state.membership!.status);
      await _storage.write(key: _keyMembershipExpires, value: state.membership!.expiresAt ?? '');
      await _storage.write(key: _keyNewsletter, value: state.membership!.newsletterHtml ?? '');
    }
  }
}