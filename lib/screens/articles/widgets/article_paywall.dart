import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_notifier.dart';
import '../../../theme/app_colors.dart';

class ArticlePaywall extends StatelessWidget {
  final bool isLoggedIn;

  const ArticlePaywall({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFAAAAAA), Colors.transparent],
              stops: [0.0, 0.8],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Column(
              children: List.generate(
                5,
                (i) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.surf(isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  width: i == 4 ? 160 : double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0x22C0392B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                color: Color(0xFFC0392B), size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Contenido exclusivo para suscriptores',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPri(isDark),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Accede a análisis en profundidad y cobertura '
            'completa de la política internacional.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSec(isDark),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (!isLoggedIn) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Iniciar sesión',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar',
                style:
                    TextStyle(color: AppColors.textMut(isDark), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
