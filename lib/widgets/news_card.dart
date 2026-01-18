import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/article_model.dart';
import '../services/api_service.dart';
import '../screens/article_detail_screen.dart';

class NewsCard extends StatelessWidget {
  final Article article;
  final ApiService apiService;

  const NewsCard({super.key, required this.article, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArticleDetailScreen(article: article),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mucho más simple y rápido:
          CachedNetworkImage(
            imageUrl: article.imageUrl ?? "", // Ya no hay que esperar a otro Future!
            key: ValueKey(article.id),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[900]),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(article.date),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  article.title,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (article.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    article.excerpt,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}