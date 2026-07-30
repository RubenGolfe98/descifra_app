import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/theme/app_colors.dart';

void main() {
  group('AppColors', () {
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
      test('subscriberText is green', () {
        expect(AppColors.subscriberText, const Color(0xFF4CAF50));
      });
    });
  });

  group('badge and status colors', () {
    test('analysisBg and analysisText are defined', () {
      expect(AppColors.analysisBg, isNotNull);
      expect(AppColors.analysisText, isNotNull);
    });
    test('newsBg and newsText are defined', () {
      expect(AppColors.newsBg, isNotNull);
      expect(AppColors.newsText, isNotNull);
    });

    test('subscriberBorder is dark green', () {
      expect(AppColors.subscriberBorder, const Color(0xFF2E5E2E));
    });
    test('subscriberBg is semi-transparent green', () {
      expect(AppColors.subscriberBg, const Color(0x224CAF50));
    });
    test('accentDim is semi-transparent accent', () {
      expect(AppColors.accentDim, const Color(0x33C0392B));
    });
  });
}
