import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/article_card.dart';
import 'article_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _repository = ArticleRepository();

  List<Article> _suggestions = [];
  List<Article> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text;
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    // Delay de 400ms para no llamar en cada letra
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _repository.searchArticles(query, perPage: 5);
      if (mounted && _controller.text == query) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _suggestions = [];
    });
    final results = await _repository.searchArticles(query, perPage: 20);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _openArticle(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg   = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(color: pri, fontSize: 15),
          cursorColor: AppColors.accent,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Buscar artículos...',
            hintStyle: TextStyle(color: sec, fontSize: 15),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: sec, size: 20),
              onPressed: () {
                _controller.clear();
                _focusNode.requestFocus();
              },
            ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.accent, size: 22),
            onPressed: _search,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: bord),
        ),
      ),
      body: _buildBody(isDark, surf, bord, pri, sec),
    );
  }

  Widget _buildBody(bool isDark, Color surf, Color bord, Color pri, Color sec) {
    // Estado vacío
    if (_controller.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, color: AppColors.bord(isDark), size: 48),
            const SizedBox(height: 12),
            Text('Busca artículos por título', style: TextStyle(color: sec, fontSize: 14)),
          ],
        ),
      );
    }

    // Cargando
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
      );
    }

    // Resultados completos (tras pulsar buscar)
    if (_hasSearched) {
      if (_results.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, color: AppColors.bord(isDark), size: 48),
              const SizedBox(height: 12),
              Text('Sin resultados para "${_controller.text}"',
                  style: TextStyle(color: sec, fontSize: 14)),
            ],
          ),
        );
      }
      return ListView.separated(
        itemCount: _results.length,
        separatorBuilder: (_, __) => Divider(height: 0.5, color: bord),
        itemBuilder: (_, i) => ArticleCard(
          article: _results[i],
          onTap: () => _openArticle(_results[i]),
        ),
      );
    }

    // Sugerencias en tiempo real
    if (_suggestions.isEmpty) {
      return Center(
        child: Text('Sin resultados', style: TextStyle(color: sec, fontSize: 14)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => Divider(height: 0.5, color: bord),
            itemBuilder: (_, i) {
              final article = _suggestions[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(Icons.article_outlined, color: sec, size: 20),
                title: Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pri, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(
                        article.author,
                        style: TextStyle(color: sec, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Text('·', style: TextStyle(color: sec, fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(article.date),
                        style: TextStyle(color: sec, fontSize: 11),
                      ),
                      if (article.isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.premiumBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock_outline, color: AppColors.premiumText, size: 8),
                              SizedBox(width: 3),
                              Text('Exclusivo',
                                  style: TextStyle(color: AppColors.premiumText, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                onTap: () => _openArticle(article),
              );
            },
          ),
        ),
        // Botón ver todos
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: surf,
            border: Border(top: BorderSide(color: bord, width: 0.5)),
          ),
          child: TextButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search, color: AppColors.accent, size: 18),
            label: Text(
              'Ver todos los resultados de "${_controller.text}"',
              style: const TextStyle(color: AppColors.accent, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}