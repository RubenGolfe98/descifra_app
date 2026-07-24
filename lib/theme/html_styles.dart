import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'app_colors.dart';

Style _bodyStyle(bool isDark) => Style(
      color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
      fontSize: FontSize(15),
      lineHeight: const LineHeight(1.75),
      margin: Margins.zero,
      padding: HtmlPaddings.zero,
      backgroundColor: Colors.transparent,
    );

Map<String, Style> articleHtmlStyles(bool isDark) => {
      'body': _bodyStyle(isDark),
      'h2': Style(
        color: AppColors.textPri(isDark),
        fontSize: FontSize(20),
        fontWeight: FontWeight.w700,
        margin: Margins.only(top: 24, bottom: 10),
      ),
      'h3': Style(
        color: AppColors.textPri(isDark),
        fontSize: FontSize(17),
        fontWeight: FontWeight.w700,
        margin: Margins.only(top: 20, bottom: 8),
      ),
      'p': Style(margin: Margins.only(bottom: 16)),
      'a': Style(color: AppColors.accent, textDecoration: TextDecoration.none),
      'strong':
          Style(color: AppColors.textPri(isDark), fontWeight: FontWeight.w600),
      'em': Style(
        color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
        fontStyle: FontStyle.italic,
      ),
      'blockquote': Style(
        color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
        border:
            const Border(left: BorderSide(color: AppColors.accent, width: 3)),
        padding: HtmlPaddings.only(left: 16),
        margin: Margins.symmetric(vertical: 16),
        fontStyle: FontStyle.italic,
      ),
      'figure': Style(margin: Margins.symmetric(vertical: 16)),
      'figcaption': Style(
        color: AppColors.textMut(isDark),
        fontSize: FontSize(12),
        textAlign: TextAlign.center,
        margin: Margins.only(top: 6),
      ),
      'ul': Style(margin: Margins.only(bottom: 16)),
      'ol': Style(margin: Margins.only(bottom: 16)),
      'li': Style(margin: Margins.only(bottom: 6)),
      'section': Style(
        backgroundColor: AppColors.surf(isDark),
        padding: HtmlPaddings.all(12),
        margin: Margins.symmetric(vertical: 12),
      ),
    };

Map<String, Style> bookHtmlStyles(bool isDark) => {
      'body': Style(
        color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
        fontSize: FontSize(14),
        lineHeight: const LineHeight(1.7),
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        backgroundColor: Colors.transparent,
      ),
      'p': Style(margin: Margins.only(bottom: 14)),
      'a': Style(color: AppColors.accent, textDecoration: TextDecoration.none),
      'strong':
          Style(color: AppColors.textPri(isDark), fontWeight: FontWeight.w600),
    };
