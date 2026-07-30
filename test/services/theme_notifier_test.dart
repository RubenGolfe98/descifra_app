import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dlg_app/services/theme_notifier.dart';

const _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Almacenamiento en memoria que sustituye a flutter_secure_storage.
late Map<String, String> storage;

void installStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map);
    switch (call.method) {
      case 'read':
        return storage[args['key']];
      case 'write':
        storage[args['key']] = args['value'] as String;
        return null;
      case 'delete':
        storage.remove(args['key']);
        return null;
      case 'deleteAll':
        storage.clear();
        return null;
      case 'readAll':
        return Map<String, String>.from(storage);
      case 'containsKey':
        return storage.containsKey(args['key']);
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Evita que google_fonts intente descargar tipografías durante los tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    storage = {};
    installStorage();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('AppFontSize', () {
    test('cada tamaño tiene su factor de escala', () {
      expect(AppFontSize.xsmall.scale, 0.80);
      expect(AppFontSize.small.scale, 0.90);
      expect(AppFontSize.normal.scale, 1.00);
      expect(AppFontSize.large.scale, 1.15);
      expect(AppFontSize.xlarge.scale, 1.30);
    });

    test('la escala crece de forma monótona', () {
      final scales = AppFontSize.values.map((e) => e.scale).toList();
      for (var i = 1; i < scales.length; i++) {
        expect(scales[i], greaterThan(scales[i - 1]));
      }
    });

    test('cada tamaño tiene su etiqueta en español', () {
      expect(AppFontSize.xsmall.label, 'Muy pequeño');
      expect(AppFontSize.small.label, 'Pequeño');
      expect(AppFontSize.normal.label, 'Normal');
      expect(AppFontSize.large.label, 'Grande');
      expect(AppFontSize.xlarge.label, 'Muy grande');
    });

    test('cada tamaño define el ratio del grid de libros', () {
      expect(AppFontSize.xsmall.gridAspectRatio, 0.52);
      expect(AppFontSize.small.gridAspectRatio, 0.50);
      expect(AppFontSize.normal.gridAspectRatio, 0.48);
      expect(AppFontSize.large.gridAspectRatio, 0.44);
      expect(AppFontSize.xlarge.gridAspectRatio, 0.44);
    });

    test('a más tamaño de letra, celdas más altas', () {
      expect(AppFontSize.xlarge.gridAspectRatio,
          lessThan(AppFontSize.xsmall.gridAspectRatio));
    });

    test('los tamaños grandes permiten una línea más de título', () {
      expect(AppFontSize.xsmall.gridMaxLines, 4);
      expect(AppFontSize.small.gridMaxLines, 4);
      expect(AppFontSize.normal.gridMaxLines, 4);
      expect(AppFontSize.large.gridMaxLines, 5);
      expect(AppFontSize.xlarge.gridMaxLines, 5);
    });

    test('todas las etiquetas son distintas y no están vacías', () {
      final labels = AppFontSize.values.map((e) => e.label).toSet();
      expect(labels, hasLength(AppFontSize.values.length));
      expect(labels.every((l) => l.isNotEmpty), isTrue);
    });
  });

  group('AppFont', () {
    test('cada tipografía tiene su nombre', () {
      expect(AppFont.raleway.label, 'Raleway');
      expect(AppFont.lora.label, 'Lora');
      expect(AppFont.merriweather.label, 'Merriweather');
      expect(AppFont.sourceSans.label, 'Source Sans');
      expect(AppFont.crimsonPro.label, 'Crimson Pro');
    });

    test('cada tipografía tiene su descripción', () {
      expect(AppFont.raleway.description, 'Sans-serif elegante');
      expect(AppFont.lora.description, 'Serif clásica');
      expect(AppFont.merriweather.description, 'Diseñada para pantalla');
      expect(AppFont.sourceSans.description, 'Sans-serif neutra');
      expect(AppFont.crimsonPro.description, 'Serif periodística');
    });

    test('todas devuelven un TextTheme aplicable', () {
      final base = ThemeData.light().textTheme;
      for (final font in AppFont.values) {
        expect(font.textTheme(base), isA<TextTheme>(),
            reason: 'falla ${font.name}');
      }
    });

    test('el TextTheme conserva la base sobre la que se aplica', () {
      final base = ThemeData.dark().textTheme;
      final theme = AppFont.lora.textTheme(base);

      expect(theme.bodyMedium, isNotNull);
    });

    test('todas devuelven un TextStyle con los valores indicados', () {
      for (final font in AppFont.values) {
        final style = font.style(
          color: const Color(0xFFC0392B),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        );

        expect(style.color, const Color(0xFFC0392B), reason: font.name);
        expect(style.fontSize, 15, reason: font.name);
        expect(style.fontWeight, FontWeight.w700, reason: font.name);
        expect(style.letterSpacing, 0.2, reason: font.name);
      }
    });

    test('el estilo admite que no se le pase ningún parámetro', () {
      for (final font in AppFont.values) {
        expect(font.style(), isA<TextStyle>(), reason: font.name);
      }
    });

    test('cada tipografía genera una familia distinta', () {
      final families =
          AppFont.values.map((f) => f.style().fontFamily).toSet();

      expect(families, hasLength(AppFont.values.length));
    });
  });

  group('Estado por defecto', () {
    test('arranca en claro, normal, Raleway y texto justificado', () {
      final notifier = ThemeNotifier();

      expect(notifier.themeMode, AppThemeMode.light);
      expect(notifier.isDark, isFalse);
      expect(notifier.fontSize, AppFontSize.normal);
      expect(notifier.font, AppFont.raleway);
      expect(notifier.refreshRate, AppRefreshRate.standard);
      expect(notifier.justifiedText, isTrue);
    });
  });

  group('initialize', () {
    test('mantiene los valores por defecto si no hay nada guardado', () async {
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.themeMode, AppThemeMode.light);
      expect(notifier.fontSize, AppFontSize.normal);
      expect(notifier.font, AppFont.raleway);
      expect(notifier.refreshRate, AppRefreshRate.standard);
      expect(notifier.justifiedText, isTrue);
    });

    test('restaura todas las preferencias guardadas', () async {
      storage
        ..['dlg_theme_mode'] = 'dark'
        ..['dlg_font_size'] = 'large'
        ..['dlg_font'] = 'lora'
        ..['dlg_refresh_rate'] = 'high'
        ..['dlg_justified_text'] = 'false';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.themeMode, AppThemeMode.dark);
      expect(notifier.isDark, isTrue);
      expect(notifier.fontSize, AppFontSize.large);
      expect(notifier.font, AppFont.lora);
      expect(notifier.refreshRate, AppRefreshRate.high);
      expect(notifier.justifiedText, isFalse);
    });

    test('cae en oscuro si el tema guardado no se reconoce', () async {
      storage['dlg_theme_mode'] = 'sepia';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.themeMode, AppThemeMode.dark);
    });

    test('cae en normal si el tamaño guardado no se reconoce', () async {
      storage['dlg_font_size'] = 'gigante';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.fontSize, AppFontSize.normal);
    });

    test('cae en Raleway si la tipografía guardada no se reconoce', () async {
      storage['dlg_font'] = 'comic-sans';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.font, AppFont.raleway);
    });

    test('cualquier valor distinto de "high" es tasa estándar', () async {
      storage['dlg_refresh_rate'] = 'lo-que-sea';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.refreshRate, AppRefreshRate.standard);
    });

    test('solo "true" activa el texto justificado', () async {
      storage['dlg_justified_text'] = 'quizá';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.justifiedText, isFalse);
    });

    test('restaura el texto justificado guardado como "true"', () async {
      storage['dlg_justified_text'] = 'true';
      final notifier = ThemeNotifier();

      await notifier.initialize();

      expect(notifier.justifiedText, isTrue);
    });

    test('notifica a los oyentes al terminar', () async {
      final notifier = ThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.initialize();

      expect(notified, isTrue);
    });

    test('restaura cada tema guardado', () async {
      for (final mode in AppThemeMode.values) {
        storage['dlg_theme_mode'] = mode.name;
        final notifier = ThemeNotifier();
        await notifier.initialize();

        expect(notifier.themeMode, mode);
      }
    });

    test('restaura cada tamaño de letra guardado', () async {
      for (final size in AppFontSize.values) {
        storage['dlg_font_size'] = size.name;
        final notifier = ThemeNotifier();
        await notifier.initialize();

        expect(notifier.fontSize, size);
      }
    });

    test('restaura cada tipografía guardada', () async {
      for (final font in AppFont.values) {
        storage['dlg_font'] = font.name;
        final notifier = ThemeNotifier();
        await notifier.initialize();

        expect(notifier.font, font);
      }
    });
  });

  group('setTheme', () {
    test('cambia el tema, lo persiste y notifica', () async {
      final notifier = ThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.setTheme(AppThemeMode.dark);

      expect(notifier.themeMode, AppThemeMode.dark);
      expect(notifier.isDark, isTrue);
      expect(storage['dlg_theme_mode'], 'dark');
      expect(notified, isTrue);
    });

    test('vuelve al tema claro', () async {
      final notifier = ThemeNotifier();
      await notifier.setTheme(AppThemeMode.dark);

      await notifier.setTheme(AppThemeMode.light);

      expect(notifier.isDark, isFalse);
      expect(storage['dlg_theme_mode'], 'light');
    });
  });

  group('setFontSize', () {
    test('cambia el tamaño, lo persiste y notifica', () async {
      final notifier = ThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.setFontSize(AppFontSize.xlarge);

      expect(notifier.fontSize, AppFontSize.xlarge);
      expect(storage['dlg_font_size'], 'xlarge');
      expect(notified, isTrue);
    });

    test('persiste cualquiera de los tamaños', () async {
      final notifier = ThemeNotifier();

      for (final size in AppFontSize.values) {
        await notifier.setFontSize(size);

        expect(notifier.fontSize, size);
        expect(storage['dlg_font_size'], size.name);
      }
    });
  });

  group('setFont', () {
    test('cambia la tipografía, la persiste y notifica', () async {
      final notifier = ThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.setFont(AppFont.merriweather);

      expect(notifier.font, AppFont.merriweather);
      expect(storage['dlg_font'], 'merriweather');
      expect(notified, isTrue);
    });

    test('persiste cualquiera de las tipografías', () async {
      final notifier = ThemeNotifier();

      for (final font in AppFont.values) {
        await notifier.setFont(font);

        expect(notifier.font, font);
        expect(storage['dlg_font'], font.name);
      }
    });
  });

  group('setRefreshRate', () {
    test('guarda "high" para la tasa alta', () async {
      final notifier = ThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.setRefreshRate(AppRefreshRate.high);

      expect(notifier.refreshRate, AppRefreshRate.high);
      expect(storage['dlg_refresh_rate'], 'high');
      expect(notified, isTrue);
    });

    test('guarda "standard" para la tasa estándar', () async {
      final notifier = ThemeNotifier();
      await notifier.setRefreshRate(AppRefreshRate.high);

      await notifier.setRefreshRate(AppRefreshRate.standard);

      expect(notifier.refreshRate, AppRefreshRate.standard);
      expect(storage['dlg_refresh_rate'], 'standard');
    });
  });

  group('setJustifiedText', () {
    test('desactiva el texto justificado y lo persiste', () async {
      final notifier = ThemeNotifier();
      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.setJustifiedText(false);

      expect(notifier.justifiedText, isFalse);
      expect(storage['dlg_justified_text'], 'false');
      expect(notified, isTrue);
    });

    test('vuelve a activarlo', () async {
      final notifier = ThemeNotifier();
      await notifier.setJustifiedText(false);

      await notifier.setJustifiedText(true);

      expect(notifier.justifiedText, isTrue);
      expect(storage['dlg_justified_text'], 'true');
    });
  });

  group('Persistencia entre sesiones', () {
    test('las preferencias elegidas se recuperan al reiniciar', () async {
      final primera = ThemeNotifier();
      await primera.setTheme(AppThemeMode.dark);
      await primera.setFontSize(AppFontSize.large);
      await primera.setFont(AppFont.crimsonPro);
      await primera.setJustifiedText(false);
      await primera.setRefreshRate(AppRefreshRate.high);

      final segunda = ThemeNotifier();
      await segunda.initialize();

      expect(segunda.themeMode, AppThemeMode.dark);
      expect(segunda.fontSize, AppFontSize.large);
      expect(segunda.font, AppFont.crimsonPro);
      expect(segunda.justifiedText, isFalse);
      expect(segunda.refreshRate, AppRefreshRate.high);
    });
  });
}
