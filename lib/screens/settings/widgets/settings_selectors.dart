import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/theme_notifier.dart';
import '../../../theme/app_colors.dart';

/// Cabecera de sección — usada en Ajustes y en el onboarding.
class SectionHeader extends StatelessWidget {
  final String label;
  final Color? textColor;

  const SectionHeader({super.key, required this.label, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: textColor ?? AppColors.accent,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Selector de tema ─────────────────────────────────────────────────────────
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeNotifier>().themeMode;
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    return Row(
      children: [
        _ThemeOption(
          label: 'Oscuro',
          icon: Icons.dark_mode_outlined,
          selected: themeMode == AppThemeMode.dark,
          isDark: isDark,
          onTap: () =>
              context.read<ThemeNotifier>().setTheme(AppThemeMode.dark),
        ),
        const SizedBox(width: 12),
        _ThemeOption(
          label: 'Claro',
          icon: Icons.light_mode_outlined,
          selected: themeMode == AppThemeMode.light,
          isDark: isDark,
          onTap: () =>
              context.read<ThemeNotifier>().setTheme(AppThemeMode.light),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentDim : surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : bord,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? AppColors.accent : pri, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accent : pri,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Selector de tamaño de fuente ─────────────────────────────────────────────
class FontSizeSelector extends StatelessWidget {
  const FontSizeSelector({super.key});

  static const _sizes = AppFontSize.values;
  static const _displaySizes = [14.0, 18.0, 22.0, 27.0, 33.0];

  @override
  Widget build(BuildContext context) {
    final current = context.select<ThemeNotifier, AppFontSize>((t) => t.fontSize);
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bord, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_sizes.length, (i) {
                final isSelected = _sizes[i] == current;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        context.read<ThemeNotifier>().setFontSize(_sizes[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'A',
                            style: TextStyle(
                              fontSize: _displaySizes[i],
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.textMut(isDark),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isSelected ? 20 : 6,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent : bord,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
              current.label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Selector de tipo de letra ────────────────────────────────────────────────
class FontFamilySelector extends StatelessWidget {
  const FontFamilySelector({super.key});

  static const _preview = 'La información es poder.';

  @override
  Widget build(BuildContext context) {
    final current = context.select<ThemeNotifier, AppFont>((t) => t.font);
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Column(
      children: AppFont.values.map((font) {
        final isSelected = font == current;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.read<ThemeNotifier>().setFont(font),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentDim : surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : bord,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        font.label,
                        style: font.style(
                          color: isSelected ? AppColors.accent : pri,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _preview,
                        style: font.style(color: pri, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        font.description,
                        style: TextStyle(color: sec, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: AppColors.accent, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Interruptor de texto justificado ─────────────────────────────────────────
class JustifiedTextToggle extends StatelessWidget {
  const JustifiedTextToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final isDark = theme.isDark;
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bord, width: 0.5),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Texto justificado',
            style: TextStyle(color: pri, fontSize: 14)),
        subtitle: Text('Alinea el texto a ambos márgenes',
            style: TextStyle(color: sec, fontSize: 12)),
        value: theme.justifiedText,
        activeThumbColor: AppColors.accent,
        onChanged: (v) => theme.setJustifiedText(v),
      ),
    );
  }
}
