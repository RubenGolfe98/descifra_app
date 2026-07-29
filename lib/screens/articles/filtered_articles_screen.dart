import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/article_repository.dart';
import '../../services/tag_service.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import 'category_articles_screen.dart';
import '../../services/author_service.dart';

enum FilterType { author, tag }

class FilteredArticlesScreen extends StatefulWidget {
  final String name; // Slug del tag o nombre del autor (para la API)
  final String? displayName; // Nombre bonito para mostrar como título
  final FilterType filterType;

  const FilteredArticlesScreen({
    super.key,
    required this.name,
    this.displayName,
    required this.filterType,
  });

  String get title => displayName ?? name;

  @override
  State<FilteredArticlesScreen> createState() => _FilteredArticlesScreenState();
}

class _FilteredArticlesScreenState extends State<FilteredArticlesScreen> {
  final _repo = ArticleRepository();
  int? _filterId;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadFilterId();
  }

  Future<void> _loadFilterId() async {
    int? id;
    if (widget.filterType == FilterType.tag) {
      id = TagService.getTagId(widget.name);
    } else {
      id = AuthorService.getAuthorId(widget.name);
    }
    // Si no está en caché, buscar en la API
    if (id == null) {
      if (widget.filterType == FilterType.author) {
        id = await _repo.fetchAuthorId(widget.name);
      } else {
        id = await _repo.fetchTagId(widget.name);
      }
    }
    if (mounted) {
      setState(() {
        _filterId = id;
        _loading = false;
        _error = id == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    if (_loading || _error) {
      return Scaffold(
        backgroundColor: AppColors.bg(isDark),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: AppColors.bord(isDark), width: 0.5)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: AppColors.textPri(isDark), size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(widget.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPri(isDark),
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent, strokeWidth: 2))
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.filterType == FilterType.author
                                  ? 'No se encontró el autor'
                                  : 'No se encontraron resultados',
                              style: TextStyle(
                                  color: AppColors.textSec(isDark),
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = false;
                                });
                                _loadFilterId();
                              },
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    final id = _filterId!;
    if (widget.filterType == FilterType.author) {
      return CategoryArticlesScreen(
        title: widget.title,
        emptyMessage: 'No hay más artículos de este autor',
        fetchArticles: ({perPage = 10, onRefreshed}) =>
            _repo.fetchArticlesByAuthor(
                authorId: id, perPage: perPage, onRefreshed: onRefreshed),
        fetchMoreArticles: ({required page, perPage = 10}) =>
            _repo.fetchMoreArticlesByAuthor(
                authorId: id, page: page, perPage: perPage),
      );
    } else {
      return CategoryArticlesScreen(
        title: widget.title,
        emptyMessage: 'No hay más artículos con esta etiqueta',
        fetchArticles: ({perPage = 10, onRefreshed}) =>
            _repo.fetchArticlesByTag(
                tagId: id, perPage: perPage, onRefreshed: onRefreshed),
        fetchMoreArticles: ({required page, perPage = 10}) => _repo
            .fetchMoreArticlesByTag(tagId: id, page: page, perPage: perPage),
      );
    }
  }
}
