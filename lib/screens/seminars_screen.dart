import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:provider/provider.dart';
import '../models/seminar.dart';
import '../repositories/seminar_repository.dart';
import '../services/auth_notifier.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/access_dialog.dart';
import '../services/analytics_service.dart';
import 'seminar_detail_screen.dart';

class SeminarsScreen extends StatefulWidget {
  const SeminarsScreen({super.key});

  @override
  State<SeminarsScreen> createState() => _SeminarsScreenState();
}

class _SeminarsScreenState extends State<SeminarsScreen> {
  final _repository = SeminarRepository();
  late Future<List<Seminar>> _future;
  bool _prefetchDone = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchSeminars();
    AnalyticsService.logSectionView('seminars');
    // Prefetch se lanza desde build() una vez disponible el contexto
  }

  Future<void> _prefetchAllSessions(String cookies) async {
    try {
      final seminars = await _future;
      for (final seminar in seminars) {
        // fetchSessions tiene caché interna, si ya está cacheado no hace petición
        await _repository.fetchSessions(seminar.link, cookies);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final auth  = context.watch<AuthNotifier>();

    // Lanzar prefetch de sesiones una sola vez en background
    if (!_prefetchDone && auth.state.isLoggedIn) {
      _prefetchDone = true;
      _prefetchAllSessions(auth.state.cookies ?? '');
    }

    final bg    = AppColors.bg(isDark);
    final surf  = AppColors.surf(isDark);
    final bord  = AppColors.bord(isDark);
    final pri   = AppColors.textPri(isDark);
    final sec   = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Seminarios', style: TextStyle(color: pri, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: bord),
        ),
      ),
      body: FutureBuilder<List<Seminar>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No hay seminarios disponibles', style: TextStyle(color: sec)));
          }

          final seminars = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: seminars.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final seminar = seminars[index];
              return GestureDetector(
                onTap: () {
                  if (!auth.state.isLoggedIn) {
                    showAccessDialog(context, onLoginTap: () {}, source: 'seminar');
                    return;
                  }
                  if (seminar.isPremium && !auth.state.isSubscriber) {
                    showAccessDialog(context, onLoginTap: () {}, source: 'seminar');
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SeminarDetailScreen(seminar: seminar)),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bord, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Portada
                      if (seminar.coverUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: seminar.coverUrl,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(height: 160, color: AppColors.bord(isDark)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge premium
                            if (seminar.isPremium)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentDim,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Exclusivo',
                                  style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            Text(seminar.title,
                              style: TextStyle(color: pri, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                            if (seminar.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(seminar.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: sec, fontSize: 13, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}