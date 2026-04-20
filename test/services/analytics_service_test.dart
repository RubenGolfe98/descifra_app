import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/services/analytics_service.dart';

void main() {
  group('AnalyticsService - sin Firebase inicializado', () {
    // Sin llamar a AnalyticsService.init(), isAvailable es false
    // Todos los métodos deben ser no-ops silenciosos (no lanzar excepciones)

    test('isAvailable es false por defecto', () {
      expect(AnalyticsService.isAvailable, false);
    });

    test('logArticleView no lanza excepción sin Firebase', () async {
      await expectLater(
        AnalyticsService.logArticleView(
          slug: 'test-slug',
          title: 'Test Title',
          category: 'analisis',
        ),
        completes,
      );
    });

    test('logCoverageView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logCoverageView(slug: 'slug', title: 'title'),
        completes,
      );
    });

    test('logSeminarView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logSeminarView(title: 'seminario'),
        completes,
      );
    });

    test('logSeminarSessionView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logSeminarSessionView(
          seminarTitle: 'seminario',
          sessionTitle: 'sesión',
        ),
        completes,
      );
    });

    test('logNewsletterView no lanza excepción', () async {
      await expectLater(AnalyticsService.logNewsletterView(), completes);
    });

    test('logSearch no lanza excepción', () async {
      await expectLater(AnalyticsService.logSearch('ucrania'), completes);
    });

    test('logArticleSaved no lanza excepción', () async {
      await expectLater(AnalyticsService.logArticleSaved('slug'), completes);
    });

    test('logArticleUnsaved no lanza excepción', () async {
      await expectLater(AnalyticsService.logArticleUnsaved('slug'), completes);
    });

    test('logLoginSuccess no lanza excepción', () async {
      await expectLater(AnalyticsService.logLoginSuccess(), completes);
    });

    test('logLogout no lanza excepción', () async {
      await expectLater(AnalyticsService.logLogout(), completes);
    });

    test('logSectionView no lanza excepción', () async {
      await expectLater(AnalyticsService.logSectionView('analysis'), completes);
    });

    test('logRegionArticlesView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logRegionArticlesView('europa'),
        completes,
      );
    });

    test('logRegionMapsView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logRegionMapsView('asia'),
        completes,
      );
    });

    test('logBookView no lanza excepción', () async {
      await expectLater(AnalyticsService.logBookView('Geopolítica'), completes);
    });

    test('logAccessDialogShown no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logAccessDialogShown(
          isLoggedIn: true,
          source: 'article',
        ),
        completes,
      );
    });

    test('logScreenView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logScreenView('home'),
        completes,
      );
    });

    test('logMapView no lanza excepción', () async {
      await expectLater(
        AnalyticsService.logMapView(region: 'europa', title: 'Mapa Europa'),
        completes,
      );
    });
  });
}
