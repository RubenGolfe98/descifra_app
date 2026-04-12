import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final isDark = theme.isDark;
    final bg   = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ajustes',
          style: TextStyle(
            color: pri,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: bord),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── Apariencia ──────────────────────────────────────────────────
          _SectionHeader(label: 'Apariencia', textColor: sec),
          const SizedBox(height: 12),
          _ThemeSelector(isDark: isDark, surf: surf, bord: bord, pri: pri),
          const SizedBox(height: 24),

          // ── Tamaño de letra ─────────────────────────────────────────────
          _SectionHeader(label: 'Tamaño de letra', textColor: sec),
          const SizedBox(height: 8),
          Text(
            'Vista previa del texto con el tamaño seleccionado.',
            style: TextStyle(color: pri, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _FontSizeSelector(
            current: theme.fontSize,
            isDark: isDark,
            surf: surf,
            bord: bord,
            pri: pri,
            sec: sec,
          ),
          const SizedBox(height: 24),

          // ── Tipo de letra ────────────────────────────────────────────────
          _SectionHeader(label: 'Tipo de letra', textColor: sec),
          const SizedBox(height: 12),
          _FontFamilySelector(
            current: theme.font,
            isDark: isDark,
            surf: surf,
            bord: bord,
            pri: pri,
            sec: sec,
          ),
        ],
      ),
    );
  }
}

// ─── Cabecera de sección ──────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color textColor;
  const _SectionHeader({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Selector de tema ─────────────────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  final bool isDark;
  final Color surf, bord, pri;

  const _ThemeSelector({
    required this.isDark,
    required this.surf,
    required this.bord,
    required this.pri,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ThemeOption(
          label: 'Oscuro',
          icon: Icons.dark_mode_outlined,
          selected: isDark,
          surf: surf,
          bord: bord,
          pri: pri,
          onTap: () => context.read<ThemeNotifier>().setTheme(AppThemeMode.dark),
        ),
        const SizedBox(width: 12),
        _ThemeOption(
          label: 'Claro',
          icon: Icons.light_mode_outlined,
          selected: !isDark,
          surf: surf,
          bord: bord,
          pri: pri,
          onTap: () => context.read<ThemeNotifier>().setTheme(AppThemeMode.light),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color surf, bord, pri;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.surf,
    required this.bord,
    required this.pri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
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
              Icon(icon,
                  color: selected ? AppColors.accent : pri, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accent : pri,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Selector de tamaño de fuente (estilo Pixel) ──────────────────────────────
class _FontSizeSelector extends StatelessWidget {
  final AppFontSize current;
  final bool isDark;
  final Color surf, bord, pri, sec;

  const _FontSizeSelector({
    required this.current,
    required this.isDark,
    required this.surf,
    required this.bord,
    required this.pri,
    required this.sec,
  });

  static const _sizes = AppFontSize.values;

  // Tamaños de la "A" de muestra para cada opción
  static const _displaySizes = [14.0, 18.0, 22.0, 27.0, 33.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de "A"s
        Container(
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: bord, width: 0.5),
          ),
          child: Column(
            children: [
              // Línea indicadora (estilo Pixel)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_sizes.length, (i) {
                    final isSelected = _sizes[i] == current;
                    return GestureDetector(
                      onTap: () => context
                          .read<ThemeNotifier>()
                          .setFontSize(_sizes[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 52,
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
                            // Punto indicador
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: isSelected ? 20 : 6,
                              height: 3,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accent
                                    : bord,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Etiqueta del tamaño seleccionado
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  current.label,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Selector de tipo de letra ────────────────────────────────────────────────
class _FontFamilySelector extends StatelessWidget {
  final AppFont current;
  final bool isDark;
  final Color surf, bord, pri, sec;

  const _FontFamilySelector({
    required this.current,
    required this.isDark,
    required this.surf,
    required this.bord,
    required this.pri,
    required this.sec,
  });

  static const _preview = 'La información es poder.';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: AppFont.values.map((font) {
        final isSelected = font == current;
        return GestureDetector(
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
                        style: font.style(
                          color: pri,
                          fontSize: 13,
                        ),
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
                  const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Selector de frecuencia de refresco ──────────────────────────────────────
class _RefreshRateSelector extends StatelessWidget {
  final AppRefreshRate current;
  final Color surf, bord, pri;

  const _RefreshRateSelector({
    required this.current,
    required this.surf,
    required this.bord,
    required this.pri,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RateOption(
          label: '60 Hz',
          subtitle: 'Estándar',
          icon: Icons.speed_outlined,
          selected: current == AppRefreshRate.standard,
          surf: surf,
          bord: bord,
          pri: pri,
          onTap: () => context.read<ThemeNotifier>().setRefreshRate(AppRefreshRate.standard),
        ),
        const SizedBox(width: 12),
        _RateOption(
          label: 'Máximo',
          subtitle: '90 / 120 Hz',
          icon: Icons.bolt_outlined,
          selected: current == AppRefreshRate.high,
          surf: surf,
          bord: bord,
          pri: pri,
          onTap: () => context.read<ThemeNotifier>().setRefreshRate(AppRefreshRate.high),
        ),
      ],
    );
  }
}

class _RateOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color surf, bord, pri;
  final VoidCallback onTap;

  const _RateOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.surf,
    required this.bord,
    required this.pri,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected ? AppColors.accent : pri,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}