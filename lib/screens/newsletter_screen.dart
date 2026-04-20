import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/auth_state.dart';
import '../theme/app_colors.dart';

class NewsletterScreen extends StatelessWidget {
  final MembershipInfo membership;

  const NewsletterScreen({super.key, required this.membership});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.bg(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Newsletter',
          style: TextStyle(color: pri, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: pri),
        elevation: 0,
      ),
      body: membership.hasNewsletter
          ? _NewsletterContent(
              html: membership.newsletterHtml!,
              isDark: isDark,
              pri: pri,
              sec: sec,
              bg: bg,
            )
          : _Paywall(isDark: isDark, pri: pri, sec: sec),
    );
  }
}

// ─── Contenido cuando tiene newsletter ───────────────────────────────────────

class _NewsletterContent extends StatelessWidget {
  final String html;
  final bool isDark;
  final Color pri, sec, bg;

  const _NewsletterContent({
    required this.html,
    required this.isDark,
    required this.pri,
    required this.sec,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = pri.value.toRadixString(16).padLeft(8, '0');
    final linkColor = AppColors.accent.value.toRadixString(16).padLeft(8, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Html(
        data: html,
        style: {
          'body': Style(
            color: pri,
            fontSize: FontSize(15),
            lineHeight: const LineHeight(1.6),
            backgroundColor: bg,
          ),
          'h2': Style(
            color: pri,
            fontSize: FontSize(18),
            fontWeight: FontWeight.w700,
            margin: Margins.only(top: 20, bottom: 8),
          ),
          'h3': Style(
            color: pri,
            fontSize: FontSize(16),
            fontWeight: FontWeight.w600,
            margin: Margins.only(top: 16, bottom: 6),
          ),
          'p': Style(
            color: pri,
            margin: Margins.only(bottom: 12),
          ),
          'a': Style(
            color: AppColors.accent,
            textDecoration: TextDecoration.underline,
          ),
          'strong': Style(fontWeight: FontWeight.w700),
          'em': Style(fontStyle: FontStyle.italic),
        },
        onLinkTap: (url, _, __) async {
          if (url == null) return;
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }
}

// ─── Paywall cuando no tiene suscripción con newsletter ───────────────────────

class _Paywall extends StatelessWidget {
  final bool isDark;
  final Color pri, sec;

  const _Paywall({required this.isDark, required this.pri, required this.sec});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 64, color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            'Newsletter DLG',
            style: TextStyle(
              color: pri,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Tu plan actual no incluye acceso a la newsletter. '
            'Puedes gestionar tu suscripción desde la página web oficial.',
            style: TextStyle(color: sec, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Volver', style: TextStyle(color: sec)),
          ),
        ],
      ),
    );
  }
}