import '../models/article.dart';

/// Fusiona la primera página recién descargada ([fresh]) con el listado que ya
/// se está mostrando ([current]), modificándolo in situ.
///
/// El resultado es [fresh] seguido de los artículos de [current] que no
/// aparecen en él (páginas siguientes ya cargadas), para no perder el scroll
/// infinito. Devuelve los ids que no estaban antes, para animarlos (todos si
/// [current] estaba vacío).
Set<int> mergeFreshArticles(List<Article> current, List<Article> fresh) {
  final previousIds = current.map((a) => a.id).toSet();
  final freshIds = fresh.map((a) => a.id).toSet();
  final kept = current.where((a) => !freshIds.contains(a.id)).toList();

  current
    ..clear()
    ..addAll(fresh)
    ..addAll(kept);

  return freshIds.difference(previousIds);
}

/// Añade [more] al final de [current] descartando los que ya estén, lo que
/// puede ocurrir tras un refresco que haya desplazado artículos de página.
void appendNewArticles(List<Article> current, List<Article> more) {
  final ids = current.map((a) => a.id).toSet();
  current.addAll(more.where((a) => !ids.contains(a.id)));
}
