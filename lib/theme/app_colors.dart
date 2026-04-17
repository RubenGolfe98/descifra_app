import 'package:flutter/material.dart';

class AppColors {
  // ─── Tema oscuro ─────────────────────────────────────────────────────────────
  static const background = Color(0xFF0D0D0D);
  static const surface    = Color(0xFF1A1A1A);
  static const border     = Color(0xFF242424);

  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted     = Color(0xFF555555);

  // ─── Tema claro (papel periódico) ────────────────────────────────────────────
  static const lightBackground = Color(0xFFF5F0E8); // crema suave
  static const lightSurface    = Color(0xFFEDE8DF); // crema más oscura
  static const lightBorder     = Color(0xFFD6CFC3); // borde tostado

  static const lightTextPrimary   = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF555555);
  static const lightTextMuted     = Color(0xFF888888);

  // ─── Compartidos ─────────────────────────────────────────────────────────────
  static const accent     = Color(0xFFC0392B);
  static const accentDim  = Color(0x33C0392B);

  static const premiumBg   = Color(0x33C0392B);
  static const premiumText = Color(0xFFE57A72);

  static const analysisBg      = Color(0x22185FA5);
  static const analysisText    = Color(0xFF85B7EB);
  static const newsBg          = Color(0x221D9E75);
  static const newsText        = Color(0xFF5DCAA5);
  static const interviewBg     = Color(0x22A0522D);
  static const interviewText   = Color(0xFFE8956D);

  static const subscriberBorder = Color(0xFF2E5E2E);
  static const subscriberText   = Color(0xFF4CAF50);
  static const subscriberBg     = Color(0x224CAF50);

  // ─── Helpers dinámicos ───────────────────────────────────────────────────────
  static Color bg(bool isDark)          => isDark ? background     : lightBackground;
  static Color surf(bool isDark)        => isDark ? surface        : lightSurface;
  static Color bord(bool isDark)        => isDark ? border         : lightBorder;
  static Color textPri(bool isDark)     => isDark ? textPrimary    : lightTextPrimary;
  static Color textSec(bool isDark)     => isDark ? textSecondary  : lightTextSecondary;
  static Color textMut(bool isDark)     => isDark ? textMuted      : lightTextMuted;
}