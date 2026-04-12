import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode { dark, light }

enum AppFontSize {
  xsmall, small, normal, large, xlarge;

  double get scale {
    switch (this) {
      case AppFontSize.xsmall: return 0.80;
      case AppFontSize.small:  return 0.90;
      case AppFontSize.normal: return 1.00;
      case AppFontSize.large:  return 1.15;
      case AppFontSize.xlarge: return 1.30;
    }
  }

  String get label {
    switch (this) {
      case AppFontSize.xsmall: return 'Muy pequeño';
      case AppFontSize.small:  return 'Pequeño';
      case AppFontSize.normal: return 'Normal';
      case AppFontSize.large:  return 'Grande';
      case AppFontSize.xlarge: return 'Muy grande';
    }
  }
}

enum AppFont {
  raleway,
  lora,
  merriweather,
  sourceSans,
  crimsonPro;

  String get label {
    switch (this) {
      case AppFont.raleway:      return 'Raleway';
      case AppFont.lora:         return 'Lora';
      case AppFont.merriweather: return 'Merriweather';
      case AppFont.sourceSans:   return 'Source Sans';
      case AppFont.crimsonPro:   return 'Crimson Pro';
    }
  }

  String get description {
    switch (this) {
      case AppFont.raleway:      return 'Sans-serif elegante';
      case AppFont.lora:         return 'Serif clásica';
      case AppFont.merriweather: return 'Diseñada para pantalla';
      case AppFont.sourceSans:   return 'Sans-serif neutra';
      case AppFont.crimsonPro:   return 'Serif periodística';
    }
  }

  TextTheme textTheme(TextTheme base) {
    switch (this) {
      case AppFont.raleway:      return GoogleFonts.ralewayTextTheme(base);
      case AppFont.lora:         return GoogleFonts.loraTextTheme(base);
      case AppFont.merriweather: return GoogleFonts.merriweatherTextTheme(base);
      case AppFont.sourceSans:   return GoogleFonts.sourceSans3TextTheme(base);
      case AppFont.crimsonPro:   return GoogleFonts.crimsonProTextTheme(base);
    }
  }

  // Para usos puntuales (cabecera home, splash, etc.)
  TextStyle style({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    final params = {
      if (color != null) 'color': color,
      if (fontSize != null) 'fontSize': fontSize,
      if (fontWeight != null) 'fontWeight': fontWeight,
      if (letterSpacing != null) 'letterSpacing': letterSpacing,
    };
    switch (this) {
      case AppFont.raleway:
        return GoogleFonts.raleway(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing);
      case AppFont.lora:
        return GoogleFonts.lora(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing);
      case AppFont.merriweather:
        return GoogleFonts.merriweather(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing);
      case AppFont.sourceSans:
        return GoogleFonts.sourceSans3(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing);
      case AppFont.crimsonPro:
        return GoogleFonts.crimsonPro(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing);
    }
  }
}

enum AppRefreshRate { standard, high }

class ThemeNotifier extends ChangeNotifier {
  static const _keyTheme       = 'dlg_theme_mode';
  static const _keyFontSize    = 'dlg_font_size';
  static const _keyFont        = 'dlg_font';
  static const _keyRefreshRate = 'dlg_refresh_rate';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AppThemeMode _themeMode  = AppThemeMode.dark;
  AppFontSize  _fontSize   = AppFontSize.normal;
  AppFont      _font       = AppFont.raleway;
  AppRefreshRate _refreshRate = AppRefreshRate.standard;

  AppThemeMode   get themeMode   => _themeMode;
  AppFontSize    get fontSize    => _fontSize;
  AppFont        get font        => _font;
  AppRefreshRate get refreshRate => _refreshRate;
  bool get isDark => _themeMode == AppThemeMode.dark;

  Future<void> initialize() async {
    final savedTheme = await _storage.read(key: _keyTheme);
    final savedFont  = await _storage.read(key: _keyFontSize);
    final savedTypeface = await _storage.read(key: _keyFont);

    if (savedTheme != null) {
      _themeMode = savedTheme == 'light' ? AppThemeMode.light : AppThemeMode.dark;
    }
    if (savedFont != null) {
      _fontSize = AppFontSize.values.firstWhere(
        (e) => e.name == savedFont, orElse: () => AppFontSize.normal);
    }
    if (savedTypeface != null) {
      _font = AppFont.values.firstWhere(
        (e) => e.name == savedTypeface, orElse: () => AppFont.raleway);
    }
    final savedRefreshRate = await _storage.read(key: _keyRefreshRate);
    if (savedRefreshRate != null) {
      _refreshRate = savedRefreshRate == 'high'
          ? AppRefreshRate.high
          : AppRefreshRate.standard;
    }
    notifyListeners();
  }

  Future<void> setRefreshRate(AppRefreshRate rate) async {
    _refreshRate = rate;
    await _storage.write(
        key: _keyRefreshRate, value: rate == AppRefreshRate.high ? 'high' : 'standard');
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _themeMode = mode;
    await _storage.write(key: _keyTheme, value: mode.name);
    notifyListeners();
  }

  Future<void> setFontSize(AppFontSize size) async {
    _fontSize = size;
    await _storage.write(key: _keyFontSize, value: size.name);
    notifyListeners();
  }

  Future<void> setFont(AppFont font) async {
    _font = font;
    await _storage.write(key: _keyFont, value: font.name);
    notifyListeners();
  }
}