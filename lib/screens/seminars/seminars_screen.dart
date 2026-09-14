import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/seminar.dart';
import '../../repositories/seminar_repository.dart';
import '../../services/auth_notifier.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/access_dialog.dart';
import '../../widgets/content_card.dart';
import '../../widgets/dlg_app_bar.dart';
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

  void _openSeminar(BuildContext context, Seminar seminar) {
    final auth = context.read<AuthNotifier>();
    final canAccess = !seminar.isPremium ||
        (auth.state.isLoggedIn && auth.state.isSubscriber);

    if (!canAccess) {
      showAccessDialog(context, onLoginTap: () {}, source: 'seminar');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeminarDetailScreen(seminar: seminar)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final auth = context.watch<AuthNotifier>();

    // Lanzar prefetch de sesiones una sola vez en background
    if (!_prefetchDone && auth.state.isLoggedIn) {
      _prefetchDone = true;
      _prefetchAllSessions(auth.state.cookies ?? '');
    }

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      appBar: DlgAppBar(title: 'Seminarios', isDark: isDark),
      body: FutureBuilder<List<Seminar>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.accent, strokeWidth: 2));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text('No hay seminarios disponibles',
                    style: TextStyle(color: AppColors.textSec(isDark))));
          }

          final seminars = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: seminars.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final seminar = seminars[index];
              return ContentCard(
                imageUrl: seminar.coverUrl,
                imageSizes: seminar.imageSizes,
                title: seminar.title,
                description: seminar.description,
                badges: [
                  if (seminar.isPremium)
                    const CardBadge(
                      label: 'Exclusivo',
                      background: AppColors.accentDim,
                      foreground: AppColors.accent,
                    ),
                ],
                onTap: () => _openSeminar(context, seminar),
              );
            },
          );
        },
      ),
    );
  }
}
