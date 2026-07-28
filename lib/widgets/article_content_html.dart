import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' show Html, TagExtension;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/html_styles.dart';
import '../utils/snackbar_utils.dart';
import 'image_viewer.dart';

class ArticleContentHtml extends StatelessWidget {
  final String html;
  final ArticleRepository repository;
  final void Function(Article article) onLinkArticle;

  const ArticleContentHtml({
    super.key,
    required this.html,
    required this.repository,
    required this.onLinkArticle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final justified = context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Html(
            data: html,
            onLinkTap: (url, _, __) async {
              if (url == null || url.isEmpty) return;
              final uri = Uri.tryParse(url);
              if (uri == null) return;

              final isInternal = uri.host.contains('descifrandolaguerra.es');

              if (isInternal) {
                final segments =
                    uri.pathSegments.where((s) => s.isNotEmpty).toList();

                if (segments.isNotEmpty) {
                  final slug = segments.last;

                  if (context.mounted) {
                    showArticleLoadingSnackBar(context);
                  }

                  final article = await repository.fetchArticleBySlug(slug);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }

                  if (article != null && context.mounted) {
                    onLinkArticle(article);
                    return;
                  }
                }
              }

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: articleHtmlStyles(isDark, justified: justified),
            extensions: [
              TagExtension(
                tagsToExtend: {'img'},
                builder: (extensionContext) {
                  final src = extensionContext.attributes['src'] ?? '';
                  if (src.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () => showImageViewer(context, src),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: src,
                          width: screenWidth - 40,
                          fit: BoxFit.cover,
                          memCacheWidth: ((screenWidth - 40) * 2).toInt(),
                          placeholder: (_, __) => Container(
                            height: 200,
                            color: AppColors.surf(isDark),
                          ),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              TagExtension(
                tagsToExtend: {'iframe'},
                builder: (extensionContext) {
                  final src = extensionContext.attributes['src'] ?? '';
                  if (src.isEmpty) return const SizedBox.shrink();

                  final ytMatch = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)')
                      .firstMatch(src);

                  if (ytMatch != null) {
                    final videoId = ytMatch.group(1)!;
                    final thumbUrl =
                        'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(
                              'https://www.youtube.com/watch?v=$videoId');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedNetworkImage(
                                imageUrl: thumbUrl,
                                width: screenWidth - 40,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 200,
                                  color: AppColors.surf(isDark),
                                ),
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 32),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final spotifyMatch = RegExp(
                    r'open\.spotify\.com/embed/(episode|show|track|playlist)/([a-zA-Z0-9]+)',
                  ).firstMatch(src);

                  if (spotifyMatch != null) {
                    final type = spotifyMatch.group(1)!;
                    final id = spotifyMatch.group(2)!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: GestureDetector(
                        onTap: () async {
                          final uri =
                              Uri.parse('https://open.spotify.com/$type/$id');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          width: screenWidth - 40,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF1DB954)
                                  .withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1DB954),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type == 'episode'
                                          ? 'Escuchar podcast'
                                          : 'Escuchar en Spotify',
                                      style: const TextStyle(
                                        color: Color(0xFF1DB954),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Abrir en Spotify',
                                      style: TextStyle(
                                        color: AppColors.textSec(isDark),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.open_in_new,
                                  color: AppColors.textMut(isDark), size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.tryParse(src);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        width: screenWidth - 40,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surf(isDark),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline,
                                color: AppColors.accent, size: 24),
                            const SizedBox(width: 8),
                            Text('Ver vídeo',
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
    );
  }
}
