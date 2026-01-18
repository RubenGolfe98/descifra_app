import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/article_model.dart';
import '../services/api_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<String> _contentFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Solo cargamos el contenido si no lo tenemos ya
    _contentFuture = _apiService.getArticleContent(widget.article.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Colors.black),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // La imagen y el título se cargan INSTANTÁNEAMENTE 
            // porque ya venían de la pantalla anterior
            CachedNetworkImage(imageUrl: widget.article.imageUrl ?? ""),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: FutureBuilder<String>(
                future: _contentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.red));
                  }
                  if (snapshot.hasError) {
                    return const Text("Error al cargar el texto completo", style: TextStyle(color: Colors.white));
                  }

                  // Guardamos el contenido en el objeto y lo mostramos
                  widget.article.content = snapshot.data!;
                  return HtmlWidget(
                    widget.article.content, // Pasamos el HTML sin limpiar (el que tiene etiquetas)
                    textStyle: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5, // Controla el interlineado general
                    ),
                    customStylesBuilder: (element) {
                      // 1. Corregir subtítulos (h2, h3, h4)
                      if (element.localName == 'h2' || element.localName == 'h3') {
                        return {
                          'color': 'white',
                          'font-weight': 'bold',
                          'font-size': '20px',
                          'margin-top': '20px',
                          'margin-bottom': '10px',
                        };
                      }
                      
                      // 2. Corregir pies de foto (WordPress usa figcaption o la clase wp-caption-text)
                      if (element.localName == 'figcaption' || element.classes.contains('wp-caption-text')) {
                        return {
                          'color': 'grey',
                          'font-size': '12px', // Fuente pequeña para el pie de foto
                          'font-style': 'italic',
                          'text-align': 'center',
                        };
                      }

                      // 3. Ajustar saltos de línea en párrafos
                      if (element.localName == 'p') {
                        return {
                          'margin-bottom': '12px', // Reduce el espacio exagerado entre párrafos
                        };
                      }

                      return null;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Función temporal para que el contenido no se vea con etiquetas HTML
  String _stripHtml(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }
}
