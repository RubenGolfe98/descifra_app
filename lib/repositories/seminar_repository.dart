import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/seminar.dart';

class SeminarRepository {
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  static const _ttl = Duration(hours: 4);

  final http.Client _client;

  // Caché listado con TTL
  static List<Seminar>? _seminarsCache;
  static DateTime? _seminarsCachedAt;

  // Caché sesiones y detalles (sin TTL)
  static final Map<String, List<SeminarSession>> _sessionsCache = {};
  static final Map<String, SeminarSessionDetail> _detailCache = {};

  SeminarRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Limpia la caché (usar tras logout)
  static void clearCache() {
    _seminarsCache = null;
    _seminarsCachedAt = null;
    _sessionsCache.clear();
    _detailCache.clear();
  }

  bool get _seminarsCacheValid =>
      _seminarsCache != null &&
      _seminarsCachedAt != null &&
      DateTime.now().difference(_seminarsCachedAt!) < _ttl;

  Future<List<Seminar>> fetchSeminars() async {
    if (_seminarsCacheValid) {
      if (kDebugMode) debugPrint('📚 [Seminars] Desde caché');
      return _seminarsCache!;
    }
    try {
      final uri = Uri.parse(
        '$_baseUrl/seminario'
        '?_fields=id,title,link,class_list,yoast_head_json.og_image,yoast_head_json.og_description'
        '&per_page=20&orderby=date&order=desc',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return _seminarsCache ?? [];
      final List<dynamic> data = jsonDecode(response.body);
      _seminarsCache = data.map((j) => Seminar.fromJson(j)).toList();
      _seminarsCachedAt = DateTime.now();
      return _seminarsCache!;
    } catch (e) {
      if (kDebugMode) debugPrint('📚 [Seminars] Error: $e');
      return _seminarsCache ?? [];
    }
  }

  /// Precarga en background — llamar desde ExploreScreen
  static void prefetch() {
    final repo = SeminarRepository();
    if (repo._seminarsCacheValid) return;
    repo.fetchSeminars().ignore();
    if (kDebugMode) debugPrint('📚 [Seminars] Precarga iniciada');
  }

  /// Parsea el HTML de la página de un seminario para extraer las sesiones
  Future<List<SeminarSession>> fetchSessions(String seminarUrl, String cookies) async {
    try {
      final uri = Uri.parse(seminarUrl);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length < 2) return [];
      final seminarSlug = segments.last;

      // Devolver caché si existe
      if (_sessionsCache.containsKey(seminarSlug)) {
        if (kDebugMode) debugPrint('📚 [Seminars] Sessions from cache: $seminarSlug');
        return _sessionsCache[seminarSlug]!;
      }

      final apiUri = Uri.parse(
        '$_baseUrl/sesion-seminario'
        '?per_page=100&orderby=menu_order&order=asc'
        '&_fields=id,title,link',
      );

      final response = await _client.get(
        apiUri,
        headers: cookies.isNotEmpty ? {'Cookie': cookies} : {},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);

      final sessions = data
          .where((j) => (j['link'] as String? ?? '').contains('/$seminarSlug/'))
          .map((j) => SeminarSession(
            title: _stripHtml(j['title']?['rendered'] ?? ''),
            url: j['link'] ?? '',
          ))
          .toList();

      // Guardar en caché todas las sesiones agrupadas por seminario
      // (aprovechamos que ya tenemos todas para cachear los demás seminarios también)
      final Map<String, List<SeminarSession>> bySlug = {};
      for (final j in data) {
        final link = j['link'] as String? ?? '';
        final match = RegExp(r'/seminarios/([^/]+)/').firstMatch(link);
        if (match == null) continue;
        final slug = match.group(1)!;
        bySlug.putIfAbsent(slug, () => []).add(SeminarSession(
          title: _stripHtml(j['title']?['rendered'] ?? ''),
          url: link,
        ));
      }
      _sessionsCache.addAll(bySlug);

      return _sessionsCache[seminarSlug] ?? [];
    } catch (e) {
      if (kDebugMode) debugPrint('📚 [Seminars] Error fetching sessions: $e');
      return [];
    }
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  /// Parsea el HTML de una sesión concreta
  Future<SeminarSessionDetail?> fetchSessionDetail(String sessionUrl, String cookies) async {
    // Devolver caché si existe
    if (_detailCache.containsKey(sessionUrl)) {
      if (kDebugMode) debugPrint('📚 [Seminars] Detail from cache: $sessionUrl');
      return _detailCache[sessionUrl];
    }
    try {
      final headers = <String, String>{
        'Accept-Encoding': 'gzip, deflate',
      };
      if (cookies.isNotEmpty) headers['Cookie'] = cookies;
      final response = await _client.get(
        Uri.parse(sessionUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final detail = _parseSessionDetail(response.body, sessionUrl);
      _detailCache[sessionUrl] = detail;
      return detail;
    } catch (e) {
      if (kDebugMode) debugPrint('📚 [Seminars] Error fetching session detail: $e');
      return null;
    }
  }

  /// Precarga en background el detalle de las sesiones de un seminario
  void prefetchSessionDetails(List<SeminarSession> sessions, String cookies) {
    for (final session in sessions) {
      if (!_detailCache.containsKey(session.url)) {
        fetchSessionDetail(session.url, cookies).ignore();
      }
    }
  }

  List<SeminarSession> _parseSessions(String html) {
    final sessions = <SeminarSession>[];

    // Buscar el <ul class="menu-sesiones-seminario"> ignorando el CSS
    final ulMatch = RegExp(
      r'<ul\s+class="menu-sesiones-seminario">(.*?)</ul>',
      dotAll: true,
    ).firstMatch(html);

    if (kDebugMode) debugPrint('📚 [Seminars] ul match found: ${ulMatch != null}');
    if (ulMatch == null) return sessions;

    final liRegex = RegExp(
      r'<li[^>]*>\s*<a href="([^"]+)">([^<]+)</a>\s*</li>',
      dotAll: true,
    );

    for (final m in liRegex.allMatches(ulMatch.group(1) ?? '')) {
      sessions.add(SeminarSession(
        title: m.group(2)!.trim(),
        url: m.group(1)!,
      ));
    }

    if (kDebugMode) debugPrint('📚 [Seminars] Sessions found: ${sessions.length}');
    return sessions;
  }

  SeminarSessionDetail _parseSessionDetail(String html, String sessionUrl) {
    // Título
    final titleMatch = RegExp(r'<h1[^>]*>([^<]+)</h1>').firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '';

    // URL de Vimeo
    final vimeoMatch = RegExp(
      r'data-src="(https://player\.vimeo\.com/video/[^"]+)"',
    ).firstMatch(html);
    final vimeoUrl = vimeoMatch?.group(1) ?? '';

    // Materiales PDF
    final materials = <SeminarMaterial>[];
    final materialsSection = RegExp(
      r'<section class="dlg-sesion-materials">(.*?)</section>',
      dotAll: true,
    ).firstMatch(html);
    if (materialsSection != null) {
      final linkRegex = RegExp(r'href="([^"]+\.pdf)"[^>]*>([^<]+)<');
      for (final m in linkRegex.allMatches(materialsSection.group(1) ?? '')) {
        materials.add(SeminarMaterial(
          url: m.group(1)!,
          name: m.group(2)!.trim(),
        ));
      }
    }

    // Descripción de la sesión — buscar el widget theme-post-content específicamente
    final postContentMatch = RegExp(
      r'data-widget_type="theme-post-content\.default".*?<div class="elementor-widget-container">(.*?)</div>\s*</div>\s*</div>',
      dotAll: true,
    ).firstMatch(html);
    final descHtml = postContentMatch?.group(1) ?? '';
    final description = descHtml
        .replaceAll(RegExp(r'</p>'), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // Sesiones del menú lateral
    final allSessions = _parseSessions(html);

    return SeminarSessionDetail(
      title: title,
      vimeoUrl: vimeoUrl,
      description: description,
      materials: materials,
      allSessions: allSessions,
    );
  }
}