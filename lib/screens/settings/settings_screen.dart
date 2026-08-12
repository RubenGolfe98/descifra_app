import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dlg_app_bar.dart';
import 'widgets/settings_selectors.dart';
import '../../widgets/stored_data_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _abrir(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final bg = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: DlgAppBar(title: 'Ajustes', isDark: isDark),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Apariencia ──────────────────────────────────────────────────
          const SectionHeader(label: 'Apariencia'),
          const SizedBox(height: 12),
          const ThemeSelector(),
          const SizedBox(height: 24),

          // ── Tamaño de letra ─────────────────────────────────────────────
          const SectionHeader(label: 'Tamaño de letra'),
          const SizedBox(height: 8),
          Text(
            'Vista previa del texto con el tamaño seleccionado.',
            style: TextStyle(color: pri, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const FontSizeSelector(),
          const SizedBox(height: 24),

          // ── Tipo de letra ────────────────────────────────────────────────
          const SectionHeader(label: 'Tipo de letra'),
          const SizedBox(height: 12),
          const FontFamilySelector(),
          const SizedBox(height: 12),

          // ── Texto justificado ────────────────────────────────────────────
          const SectionHeader(label: 'Texto'),
          const SizedBox(height: 12),
          const JustifiedTextToggle(),
          const SizedBox(height: 24),

          // ── Acerca de ────────────────────────────────────────────────────
          const SectionHeader(label: 'Acerca de'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bord, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Descifrando la Guerra',
                        style: TextStyle(
                            color: pri,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${_version.isEmpty ? '1.0.0' : _version}',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Desarrollada por 👨🏼‍💻RubenGolfe98',
                  style: TextStyle(color: sec, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Divider(color: bord, thickness: 0.5),
                const SizedBox(height: 12),
                Text(
                  '⭐ ¿Te ha gustado la app?',
                  style: TextStyle(
                      color: pri, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Si la app te resulta útil, agradecería mucho que le des una estrella al proyecto en GitHub.',
                  style: TextStyle(color: sec, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                          'https://github.com/RubenGolfe98/descifra_app');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Ver en GitHub'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side:
                          const BorderSide(color: AppColors.accent, width: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: bord, thickness: 0.5),
                const SizedBox(height: 12),
                Text(
                  'Privacidad',
                  style: TextStyle(
                      color: pri, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                _LegalLink(
                  label: 'Datos que guarda la app',
                  color: sec,
                  icon: Icons.lock_outline,
                  onTap: () => showStoredDataSheet(context),
                ),
                const SizedBox(height: 10),
                _LegalLink(
                  label: 'Política de privacidad',
                  color: sec,
                  icon: Icons.open_in_new,
                  onTap: () => _abrir(
                      'https://www.descifrandolaguerra.es/politica-de-privacidad/'),
                ),
                const SizedBox(height: 10),
                _LegalLink(
                  label: 'Aviso legal',
                  color: sec,
                  icon: Icons.open_in_new,
                  onTap: () =>
                      _abrir('https://www.descifrandolaguerra.es/aviso-legal/'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _LegalLink({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
