import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  late Future<List<Book>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchBooks();
  }

  Future<List<Book>> _fetchBooks() async {
    final uri = Uri.parse(
      'https://www.descifrandolaguerra.es/wp-json/wp/v2/libro'
      '?_fields=id,title,link,content,yoast_head_json.og_image,yoast_head_json.og_description'
      '&per_page=20',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((j) => Book.fromJson(j)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg   = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Libros', style: TextStyle(color: pri, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: bord),
        ),
      ),
      body: FutureBuilder<List<Book>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No hay libros disponibles',
                  style: TextStyle(color: AppColors.textSec(isDark))),
            );
          }

          final books = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.55,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portada sin recortar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: book.coverUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        placeholder: (_, __) => AspectRatio(
                          aspectRatio: 0.7,
                          child: Container(color: surf),
                        ),
                        errorWidget: (_, __, ___) => AspectRatio(
                          aspectRatio: 0.7,
                          child: Container(
                            color: surf,
                            child: Icon(Icons.book_outlined,
                                color: AppColors.bord(isDark), size: 40),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pri,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Detalle del libro ────────────────────────────────────────────────────────
class BookDetailScreen extends StatefulWidget {
  final Book book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book;
  bool _loadingFicha = true;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _fetchFicha();
  }

  Future<void> _fetchFicha() async {
    try {
      final response = await http.get(Uri.parse(_book.link))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final html = response.body;

      // Fecha de publicación
      final dateMatch = RegExp(r'Fecha de publicaci[oó]n:?\s*</strong>\s*([\d/]+)')
          .firstMatch(html);
      final publishDate = dateMatch?.group(1)?.trim() ?? '';

      // Autores
      final authorMatches = RegExp(r'class="dlg-book-author-name">([^<]+)<')
          .allMatches(html);
      final authors = authorMatches.map((m) => m.group(1)!.trim()).toList();

      // Editorial
      final editorialMatch = RegExp(r'Editorial:?\s*</strong>\s*([^<\n]+)')
          .firstMatch(html);
      final editorial = editorialMatch?.group(1)?.trim() ?? '';

      // URLs de Amazon — extraer por orden de aparición junto al texto del botón
      String amazonUrl = '';
      String amazonKindleUrl = '';
      final buttonRegex = RegExp(
        r'href="(https://amzn\.to/[^"]+)"[^>]*>.*?<span class="elementor-button-text">(Comprar en Amazon[^<]*)</span>',
        dotAll: true,
      );
      for (final m in buttonRegex.allMatches(html)) {
        final url = m.group(1) ?? '';
        final label = m.group(2) ?? '';
        if (label.toLowerCase().contains('kindle')) {
          amazonKindleUrl = url;
        } else {
          amazonUrl = url;
        }
      }

      if (mounted) {
        setState(() {
          _book = _book.withFicha(
            publishDate: publishDate,
            authors: authors,
            editorial: editorial,
            amazonUrl: amazonUrl,
            amazonKindleUrl: amazonKindleUrl,
          );
          _loadingFicha = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFicha = false);
    }
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: bord),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Portada centrada
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: _book.coverUrl,
                  width: 200,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(width: 200, height: 300, color: surf),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              _book.title,
              style: TextStyle(color: pri, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 12),

            // Descripción
            if (_book.description.isNotEmpty) ...[
              Text(_book.description, style: TextStyle(color: sec, fontSize: 14, height: 1.6)),
              const SizedBox(height: 20),
            ],

            // Ficha técnica
            if (_loadingFicha)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: AppColors.textMut(isDark), strokeWidth: 1.5)),
                  const SizedBox(width: 8),
                  Text('Cargando ficha...', style: TextStyle(color: AppColors.textMut(isDark), fontSize: 12)),
                ]),
              )
            else if (_book.publishDate.isNotEmpty || _book.authors.isNotEmpty || _book.editorial.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bord, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ficha del libro',
                      style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    if (_book.publishDate.isNotEmpty) _FichaRow(label: 'Fecha', value: _book.publishDate, pri: pri, sec: sec),
                    if (_book.editorial.isNotEmpty) _FichaRow(label: 'Editorial', value: _book.editorial, pri: pri, sec: sec),
                    if (_book.authors.isNotEmpty) _FichaRow(label: 'Autores', value: _book.authors.join(', '), pri: pri, sec: sec),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Botones de compra
            if (_book.amazonUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_book.amazonUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Comprar en Amazon'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (_book.amazonKindleUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_book.amazonKindleUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.tablet_outlined, size: 18),
                  label: const Text('Comprar en Amazon (Kindle)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent, width: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (_book.amazonUrl.isEmpty && !_loadingFicha)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(_book.link);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Ver ficha completa y comprar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Divider(color: bord, thickness: 0.5),

            // Contenido HTML
            Html(
              data: _book.contentHtml,
              onLinkTap: (url, _, __) async {
                if (url == null) return;
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: {
                'body': Style(
                  color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
                  fontSize: FontSize(14),
                  lineHeight: const LineHeight(1.7),
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                  backgroundColor: Colors.transparent,
                ),
                'p': Style(margin: Margins.only(bottom: 14)),
                'a': Style(color: AppColors.accent, textDecoration: TextDecoration.none),
                'strong': Style(color: pri, fontWeight: FontWeight.w600),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FichaRow extends StatelessWidget {
  final String label;
  final String value;
  final Color pri;
  final Color sec;

  const _FichaRow({required this.label, required this.value, required this.pri, required this.sec});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: sec, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: pri, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}