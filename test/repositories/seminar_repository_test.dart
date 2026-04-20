import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlg_app/repositories/seminar_repository.dart';

final _seminarJson = {
  'id': 1,
  'link': 'https://www.descifrandolaguerra.es/seminarios/ucrania/',
  'title': {'rendered': 'La guerra en Ucrania'},
  'class_list': ['post-1', 'seminario'],
  'yoast_head_json': {
    'og_description': 'Descripción',
    'og_image': [{'url': 'https://example.com/cover.jpg'}],
  },
};

http.Client _mock(dynamic body, {int statusCode = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(body), statusCode));

void main() {
  setUp(() => SeminarRepository.clearCache());

  group('SeminarRepository - fetchSeminars', () {
    test('fetches list from network', () async {
      final repo = SeminarRepository(client: _mock([_seminarJson]));
      final list = await repo.fetchSeminars();
      expect(list.length, 1);
      expect(list.first.title, 'La guerra en Ucrania');
    });

    test('returns empty on non-200', () async {
      final repo = SeminarRepository(client: _mock([], statusCode: 500));
      expect(await repo.fetchSeminars(), isEmpty);
    });

    test('returns empty on network error', () async {
      final repo = SeminarRepository(
        client: MockClient((_) async => throw Exception('error')),
      );
      expect(await repo.fetchSeminars(), isEmpty);
    });

    test('uses cache on second call within TTL', () async {
      int calls = 0;
      final repo = SeminarRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode([_seminarJson]), 200);
        }),
      );
      await repo.fetchSeminars();
      await repo.fetchSeminars();
      expect(calls, 1);
    });

    test('prefetch no lanza si ya hay caché válida', () async {
      int calls = 0;
      final repo = SeminarRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode([_seminarJson]), 200);
        }),
      );
      await repo.fetchSeminars();
      SeminarRepository.prefetch();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(calls, 1);
    });

    test('isPremium detectado en seminario restringido', () async {
      final premiumJson = Map<String, dynamic>.from(_seminarJson)
        ..['class_list'] = ['post-1', 'seminario', 'rcp-is-restricted'];
      final repo = SeminarRepository(client: _mock([premiumJson]));
      final list = await repo.fetchSeminars();
      expect(list.first.isPremium, true);
    });
  });

  group('SeminarRepository - clearCache', () {
    test('limpia caché correctamente', () async {
      int calls = 0;
      final repo = SeminarRepository(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode([_seminarJson]), 200);
        }),
      );
      await repo.fetchSeminars();
      SeminarRepository.clearCache();
      await repo.fetchSeminars();
      expect(calls, 2); // segunda llamada fue a red porque se limpió la caché
    });
  });
}
