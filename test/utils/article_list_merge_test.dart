import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/article.dart';
import 'package:dlg_app/utils/article_list_merge.dart';

Article _article(int id) => Article(
      id: id,
      date: DateTime(2026, 1, 1),
      title: 'Artículo $id',
      description: '',
      author: '',
      imageUrl: '',
      isPremium: false,
    );

List<int> _ids(List<Article> list) => list.map((a) => a.id).toList();

void main() {
  group('mergeFreshArticles', () {
    test('pone los nuevos arriba y conserva las páginas ya cargadas', () {
      final current = [3, 2, 1, 0].map(_article).toList();
      final fresh = [5, 4, 3, 2].map(_article).toList();

      final added = mergeFreshArticles(current, fresh);

      expect(_ids(current), [5, 4, 3, 2, 1, 0]);
      expect(added, {5, 4});
    });

    test('sin cambios no devuelve ids nuevos', () {
      final current = [2, 1].map(_article).toList();
      final added = mergeFreshArticles(current, [2, 1].map(_article).toList());

      expect(_ids(current), [2, 1]);
      expect(added, isEmpty);
    });

    test('con el listado vacío marca todos como nuevos', () {
      final current = <Article>[];
      final added = mergeFreshArticles(current, [2, 1].map(_article).toList());

      expect(_ids(current), [2, 1]);
      expect(added, {2, 1});
    });
  });

  group('appendNewArticles', () {
    test('descarta los artículos que ya están en el listado', () {
      final current = [5, 4, 3].map(_article).toList();
      appendNewArticles(current, [3, 2, 1].map(_article).toList());

      expect(_ids(current), [5, 4, 3, 2, 1]);
    });
  });
}
