import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article_model.dart';
import '../services/api_service.dart';
import '../widgets/news_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService apiService = ApiService();
  late Future<List<Article>> futureArticles;

  @override
  void initState() {
    super.initState();
    futureArticles = apiService.getArticles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Negro casi puro
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "DESCIFRANDO LA GUERRA",
          style: GoogleFonts.oswald(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFE53935), // Rojo vibrante
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Article>>(
        future: futureArticles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error al cargar datos", style: TextStyle(color: Colors.white)));
          }

          final articles = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final art = articles[index];
              return NewsCard(article: art, apiService: apiService);
            },
          );
        },
      ),
    );
  }
}