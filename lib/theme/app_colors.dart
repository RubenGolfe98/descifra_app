import 'package:flutter/material.dart';

class AppColors {
  // ─── Tema oscuro ─────────────────────────────────────────────────────────────
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const border = Color(0xFF1A1A1A);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);

  // ─── Tema claro (papel periódico) ────────────────────────────────────────────
  static const lightBackground = Color(0xFFF5F0E8); // crema suave
  static const lightSurface = Color(0xFFEDE8DF); // crema más oscura
  static const lightBorder = Color(0xFFD6CFC3); // borde tostado

  static const lightTextPrimary = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF555555);
  static const lightTextMuted = Color(0xFF888888);

  // ─── Compartidos ─────────────────────────────────────────────────────────────
  static const accent = Color(0xFFC0392B);
  static const accentDim = Color(0x33C0392B);

  static const premiumBg = Color(0x33C0392B);
  static const premiumText = Color(0xFFE57A72);

  // ─── Badges dinámicos ────────────────────────────────────────────────────────
  static Color analysisBg(bool isDark) =>
      isDark ? const Color(0x33185FA5) : const Color(0x22185FA5);
  static Color analysisText(bool isDark) =>
      isDark ? const Color(0xFF4A9BE0) : const Color(0xFF1557A0);
  static Color newsBg(bool isDark) =>
      isDark ? const Color(0x331D9E75) : const Color(0x221D9E75);
  static Color newsText(bool isDark) =>
      isDark ? const Color(0xFF2DBD8E) : const Color(0xFF167A56);
  static Color interviewBg(bool isDark) =>
      isDark ? const Color(0x33A0522D) : const Color(0x22A0522D);
  static Color interviewText(bool isDark) =>
      isDark ? const Color(0xFFD4815E) : const Color(0xFF8B4226);
  static Color tagBg(bool isDark) =>
      isDark ? const Color(0x33757575) : const Color(0x22555555);
  static Color tagText(bool isDark) =>
      isDark ? const Color(0xFFA0A0A0) : const Color(0xFF555555);

  static const subscriberBorder = Color(0xFF2E5E2E);
  static const subscriberText = Color(0xFF4CAF50);
  static const subscriberBg = Color(0x224CAF50);

  // ─── Helpers dinámicos ───────────────────────────────────────────────────────
  static Color bg(bool isDark) => isDark ? background : lightBackground;
  static Color surf(bool isDark) => isDark ? surface : lightSurface;
  static Color bord(bool isDark) => isDark ? border : lightBorder;
  static Color textPri(bool isDark) => isDark ? textPrimary : lightTextPrimary;
  static Color textSec(bool isDark) =>
      isDark ? textSecondary : lightTextSecondary;
  static Color textMut(bool isDark) => isDark ? textMuted : lightTextMuted;
}
