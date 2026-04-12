import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    group('dark theme colors', () {
      test('background is correct', () {
        expect(AppColors.background, const Color(0xFF0D0D0D));
      });
      test('surface is correct', () {
        expect(AppColors.surface, const Color(0xFF1A1A1A));
      });
      test('accent is correct', () {
        expect(AppColors.accent, const Color(0xFFC0392B));
      });
    });

    group('light theme colors', () {
      test('lightBackground is cream color', () {
        expect(AppColors.lightBackground, const Color(0xFFF5F0E8));
      });
      test('lightSurface is slightly darker cream', () {
        expect(AppColors.lightSurface, const Color(0xFFEDE8DF));
      });
    });

    group('dynamic helpers', () {
      test('bg returns dark background in dark mode', () {
        expect(AppColors.bg(true), AppColors.background);
      });
      test('bg returns light background in light mode', () {
        expect(AppColors.bg(false), AppColors.lightBackground);
      });
      test('surf returns dark surface in dark mode', () {
        expect(AppColors.surf(true), AppColors.surface);
      });
      test('surf returns light surface in light mode', () {
        expect(AppColors.surf(false), AppColors.lightSurface);
      });
      test('bord returns dark border in dark mode', () {
        expect(AppColors.bord(true), AppColors.border);
      });
      test('bord returns light border in light mode', () {
        expect(AppColors.bord(false), AppColors.lightBorder);
      });
      test('textPri returns white in dark mode', () {
        expect(AppColors.textPri(true), AppColors.textPrimary);
      });
      test('textPri returns dark in light mode', () {
        expect(AppColors.textPri(false), AppColors.lightTextPrimary);
      });
      test('textSec returns correct colors', () {
        expect(AppColors.textSec(true), AppColors.textSecondary);
        expect(AppColors.textSec(false), AppColors.lightTextSecondary);
      });
      test('textMut returns correct colors', () {
        expect(AppColors.textMut(true), AppColors.textMuted);
        expect(AppColors.textMut(false), AppColors.lightTextMuted);
      });
    });

    group('shared colors', () {
      test('accent is same in both themes', () {
        expect(AppColors.accent, const Color(0xFFC0392B));
      });
      test('premiumText color is correct', () {
        expect(AppColors.premiumText, const Color(0xFFE57A72));
      });
      test('subscriberText is green', () {
        expect(AppColors.subscriberText, const Color(0xFF4CAF50));
      });
    });
  });
}
