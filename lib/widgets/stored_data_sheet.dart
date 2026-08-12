import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';

/// Muestra qué datos guarda la aplicación en el dispositivo.
Future<void> showStoredDataSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _StoredDataSheet(),
  );
}

class _StoredDataSheet extends StatelessWidget {
  const _StoredDataSheet();

  static const _items = [
    (
      Icons.cookie_outlined,
      'Sesión',
      'Las cookies de tu sesión de WordPress, para mantenerte identificado.',
    ),
    (
      Icons.person_outline,
      'Cuenta',
      'Tu correo electrónico y tu nombre de usuario.',
    ),
    (
      Icons.card_membership_outlined,
      'Suscripción',
      'El estado de tu suscripción y su fecha de renovación.',
    ),
    (
      Icons.tune,
      'Preferencias',
      'Tema, tipografía, tamaño de letra y texto justificado.',
    ),
    (
      Icons.download_for_offline_outlined,
      'Lectura sin conexión',
      'Una copia temporal de los artículos que has abierto.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);
    final mut = AppColors.textMut(isDark);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: bord,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppColors.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Datos guardados en tu dispositivo',
                          style: TextStyle(
                            color: pri,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Esta aplicación guarda de forma local y cifrada:',
                    style: TextStyle(color: sec, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  for (final (icon, titulo, detalle) in _items) ...[
                    _StoredItem(
                      icon: icon,
                      title: titulo,
                      description: detalle,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 6),
                  Divider(color: bord, thickness: 0.5),
                  const SizedBox(height: 16),
                  _Nota(
                    text: 'Estos datos no se comparten con terceros ni salen '
                        'del dispositivo, salvo las cookies de sesión, que se '
                        'envían a descifrandolaguerra.es para verificar tu '
                        'identidad y tu suscripción.',
                    color: sec,
                  ),
                  const SizedBox(height: 12),
                  _Nota(
                    text: 'Tus artículos guardados se sincronizan con tu '
                        'cuenta en la web, así que están disponibles desde '
                        'cualquier dispositivo.',
                    color: sec,
                  ),
                  const SizedBox(height: 12),
                  _Nota(
                    text: 'Puedes borrar todos estos datos cerrando sesión '
                        'desde tu perfil o desinstalando la aplicación.',
                    color: sec,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cerrar',
                  style: TextStyle(color: mut, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entrada de la lista ──────────────────────────────────────────────────────
class _StoredItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  const _StoredItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.accentDim,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.accent, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPri(isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.textSec(isDark),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Párrafo informativo ──────────────────────────────────────────────────────
class _Nota extends StatelessWidget {
  final String text;
  final Color color;

  const _Nota({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 13, height: 1.55),
    );
  }
}
