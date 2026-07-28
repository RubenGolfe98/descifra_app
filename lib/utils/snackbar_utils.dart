import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';

void showArticleLoadingSnackBar(BuildContext context) {
  final isDark = context.read<ThemeNotifier>().isDark;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Cargando artículo...',
            style: TextStyle(color: AppColors.textPri(isDark)),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.surf(isDark),
    ),
  );
}
