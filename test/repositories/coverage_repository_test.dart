import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlg_app/repositories/coverage_repository.dart';

final _coverageJson = {
  'id': 1,
  'slug': 'guerra-ucrania',
  'link': 'https://www.descifrandolaguerra.es/coberturas/guerra-ucrania/',
  'title': {'rendered': 'Guerra en Ucrania'},
  'yoast_head_json': {
    'description': 'Cobertura de la guerra',
    'og_image': [{'url': 'https://example.com/img.jpg'}],
  },
};

final _detailJson = {
  'id': 1,
  'slug': 'guerra-ucrania',
  'link': 'https://www.descifrandolaguerra.es/coberturas/guerra-ucrania/',
  'title': {'rendered': 'Guerra en Ucrania'},
  'content': {'rendered': '<p>Descripción larga</p>'},
  'yoast_head_json': {
    'description': 'desc',
    'og_image': [{'url': 'https://example.com/img.jpg'}],
  },
};

http.Client _mock(dynamic body, {int statusCode = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(body), statusCode));

void main() {
  setUp(() => CoverageRepository.clearCache());

  group('CoverageRepository - fetchCoverages', () {
    test('fetches list from network', () async {
      final repo = CoverageRepository(client: _mock([_coverageJson]));
      final list = await repo.fetchCoverages();
      expect(list.length, 1);
      expect(list.first.slug, 'guerra-ucrania');
    });

    test('returns empty on non-200', () async {
      final repo = CoverageRepository(client: _mock([], statusCode: 500));
      expect(await repo.fetchCoverages(), isEmpty);
    });

    test('returns empty on network error', () async {
      final repo = CoverageRepository(
        client: MockClient((_) async => throw Exception('error')),
      );
      expect(await repo.fetchCoverages(), isEmpty);
    });

    test('uses cache on second call within TTL', () async {
      int calls = 0;
      final repo = CoverageRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode([_coverageJson]), 200);
        }),
      );
      await repo.fetchCoverages();
      await repo.fetchCoverages();
      expect(calls, 1); // segunda llamada usa caché
    });

    test('prefetch no lanza si ya hay caché válida', () async {
      int calls = 0;
      final repo = CoverageRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode([_coverageJson]), 200);
        }),
      );
      await repo.fetchCoverages(); // rellena caché
      CoverageRepository.prefetch();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(calls, 1); // no hizo petición extra
    });
  });

  group('CoverageRepository - fetchCoverageDetail', () {
    test('fetches detail from network', () async {
      final repo = CoverageRepository(client: _mock(_detailJson));
      final detail = await repo.fetchCoverageDetail(1);
      expect(detail, isNotNull);
      expect(detail!.contentHtml, '<p>Descripción larga</p>');
    });

    test('returns null on non-200', () async {
      final repo = CoverageRepository(client: _mock({}, statusCode: 404));
      expect(await repo.fetchCoverageDetail(1), isNull);
    });

    test('caches detail on second call', () async {
      int calls = 0;
      final repo = CoverageRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(_detailJson), 200);
        }),
      );
      await repo.fetchCoverageDetail(1);
      await repo.fetchCoverageDetail(1);
      expect(calls, 1);
    });
  });
}
