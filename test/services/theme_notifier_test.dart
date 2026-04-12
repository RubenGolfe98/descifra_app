import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/services/theme_notifier.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock flutter_secure_storage para tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        if (call.method == 'write') return null;
        if (call.method == 'read') return null;
        if (call.method == 'readAll') return {};
        if (call.method == 'delete') return null;
        return null;
      },
    );
  });

  group('AppFontSize', () {
    test('scale values are correct', () {
      expect(AppFontSize.xsmall.scale, 0.80);
      expect(AppFontSize.small.scale, 0.90);
      expect(AppFontSize.normal.scale, 1.00);
      expect(AppFontSize.large.scale, 1.15);
      expect(AppFontSize.xlarge.scale, 1.30);
    });

    test('label values are correct', () {
      expect(AppFontSize.xsmall.label, 'Muy pequeño');
      expect(AppFontSize.small.label, 'Pequeño');
      expect(AppFontSize.normal.label, 'Normal');
      expect(AppFontSize.large.label, 'Grande');
      expect(AppFontSize.xlarge.label, 'Muy grande');
    });

    test('has 5 values', () {
      expect(AppFontSize.values.length, 5);
    });

    test('scales are in ascending order', () {
      final scales = AppFontSize.values.map((e) => e.scale).toList();
      for (int i = 1; i < scales.length; i++) {
        expect(scales[i], greaterThan(scales[i - 1]));
      }
    });
  });

  group('AppFont', () {
    test('has 5 values', () {
      expect(AppFont.values.length, 5);
    });

    test('all fonts have non-empty labels', () {
      for (final font in AppFont.values) {
        expect(font.label, isNotEmpty);
      }
    });

    test('all fonts have non-empty descriptions', () {
      for (final font in AppFont.values) {
        expect(font.description, isNotEmpty);
      }
    });

    test('label values are correct', () {
      expect(AppFont.raleway.label, 'Raleway');
      expect(AppFont.lora.label, 'Lora');
      expect(AppFont.merriweather.label, 'Merriweather');
      expect(AppFont.sourceSans.label, 'Source Sans');
      expect(AppFont.crimsonPro.label, 'Crimson Pro');
    });

    test('all font labels are unique', () {
      final labels = AppFont.values.map((f) => f.label).toList();
      expect(labels.toSet().length, labels.length);
    });
  });

  group('AppThemeMode', () {
    test('has 2 values', () {
      expect(AppThemeMode.values.length, 2);
    });

    test('contains dark and light', () {
      expect(AppThemeMode.values, contains(AppThemeMode.dark));
      expect(AppThemeMode.values, contains(AppThemeMode.light));
    });
  });

  group('ThemeNotifier', () {
    test('default values are correct', () {
      final notifier = ThemeNotifier();
      expect(notifier.themeMode, AppThemeMode.dark);
      expect(notifier.fontSize, AppFontSize.normal);
      expect(notifier.font, AppFont.raleway);
      expect(notifier.isDark, true);
    });

    test('isDark returns false for light mode', () async {
      final notifier = ThemeNotifier();
      await notifier.setTheme(AppThemeMode.light);
      expect(notifier.isDark, false);
    });

    test('setTheme updates themeMode', () async {
      final notifier = ThemeNotifier();
      await notifier.setTheme(AppThemeMode.light);
      expect(notifier.themeMode, AppThemeMode.light);
    });

    test('setFontSize updates fontSize', () async {
      final notifier = ThemeNotifier();
      await notifier.setFontSize(AppFontSize.large);
      expect(notifier.fontSize, AppFontSize.large);
    });

    test('setFont updates font', () async {
      final notifier = ThemeNotifier();
      await notifier.setFont(AppFont.lora);
      expect(notifier.font, AppFont.lora);
    });

    test('notifies listeners on theme change', () async {
      final notifier = ThemeNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);
      await notifier.setTheme(AppThemeMode.light);
      expect(notified, true);
    });

    test('notifies listeners on font size change', () async {
      final notifier = ThemeNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);
      await notifier.setFontSize(AppFontSize.xlarge);
      expect(notified, true);
    });

    test('notifies listeners on font change', () async {
      final notifier = ThemeNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);
      await notifier.setFont(AppFont.merriweather);
      expect(notified, true);
    });
  });
}