import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Servicio de Analytics — si Firebase no está configurado,
/// todos los métodos son no-ops silenciosos (la app no falla).
class AnalyticsService {
  static FirebaseAnalytics? _analytics;

  static bool get isAvailable => _analytics != null;

  /// Llamar una vez desde main.dart tras inicializar Firebase
  static void init(FirebaseAnalytics analytics) {
    _analytics = analytics;
    if (kDebugMode) debugPrint('📊 [Analytics] Inicializado');
  }

  // ─── Secciones (listados) ────────────────────────────────────────────────────

  static Future<void> logSectionView(String section) =>
      _log('section_view', {'section': section});
  // section: 'analysis' | 'interviews' | 'coverages' | 'seminars' | 'books' | 'maps'

  // ─── Regiones ───────────────────────────────────────────────────────────────

  static Future<void> logRegionArticlesView(String regionSlug) =>
      _log('region_articles_view', {'region': regionSlug});

  static Future<void> logRegionMapsView(String regionSlug) =>
      _log('region_maps_view', {'region': regionSlug});

  // ─── Artículos ──────────────────────────────────────────────────────────────

  static Future<void> logArticleView({
    required String slug,
    required String title,
    required String category, // noticia, analisis, entrevista
    String? author,
  }) => _log('article_view', {
        'slug': slug,
        'title': _trim(title),
        'category': category,
        if (author != null) 'author': author,
      });

  // ─── Coberturas ─────────────────────────────────────────────────────────────

  static Future<void> logCoverageView({
    required String slug,
    required String title,
  }) => _log('coverage_view', {
        'slug': slug,
        'title': _trim(title),
      });

  // ─── Seminarios ─────────────────────────────────────────────────────────────

  static Future<void> logSeminarView({
    required String title,
  }) => _log('seminar_view', {
        'title': _trim(title),
      });

  static Future<void> logSeminarSessionView({
    required String seminarTitle,
    required String sessionTitle,
  }) => _log('seminar_session_view', {
        'seminar': _trim(seminarTitle),
        'session': _trim(sessionTitle),
      });

  // ─── Mapas ──────────────────────────────────────────────────────────────────

  // ─── Newsletter ─────────────────────────────────────────────────────────────

  static Future<void> logNewsletterView() =>
      _log('newsletter_view', {});

  // ─── Búsqueda ────────────────────────────────────────────────────────────────

  static Future<void> logSearch(String query) =>
      _log('search', {'query': _trim(query)});

  // ─── Favoritos ──────────────────────────────────────────────────────────────

  static Future<void> logArticleSaved(String slug) =>
      _log('article_saved', {'slug': slug});

  static Future<void> logArticleUnsaved(String slug) =>
      _log('article_unsaved', {'slug': slug});

  // ─── Acceso / Login ─────────────────────────────────────────────────────────

  static Future<void> logLoginSuccess() =>
      _log('login_success', {});

  static Future<void> logLogout() =>
      _log('logout', {});

  // ─── Contenido exclusivo ────────────────────────────────────────────────────

  static Future<void> logAccessDialogShown({
    required bool isLoggedIn,
    required String source, // article, coverage, seminar...
  }) => _log('access_dialog_shown', {
        'logged_in': isLoggedIn.toString(),
        'source': source,
      });

  // ─── Navegación ─────────────────────────────────────────────────────────────

  static Future<void> logScreenView(String screenName) async {
    if (!isAvailable) return;
    try {
      await _analytics!.logScreenView(screenName: screenName);
      if (kDebugMode) debugPrint('📊 [Analytics] screen: $screenName');
    } catch (e) {
      if (kDebugMode) debugPrint('📊 [Analytics] Error: $e');
    }
  }

  // ─── Mapas ──────────────────────────────────────────────────────────────────

  static Future<void> logMapView({
    required String region,
    required String title,
  }) => _log('map_view', {
        'region': region,
        'title': _trim(title),
      });

  // ─── Libros ─────────────────────────────────────────────────────────────────

  static Future<void> logBookView(String title) =>
      _log('book_view', {'title': _trim(title)});

  // ─── Helper interno ─────────────────────────────────────────────────────────

  static Future<void> _log(
      String name, Map<String, String> params) async {
    if (!isAvailable) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
      if (kDebugMode) debugPrint('📊 [Analytics] $name $params');
    } catch (e) {
      if (kDebugMode) debugPrint('📊 [Analytics] Error en $name: $e');
    }
  }

  /// Firebase limita los valores a 100 caracteres
  static String _trim(String value) =>
      value.length > 100 ? value.substring(0, 100) : value;
}
