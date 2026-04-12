import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/services/auth_notifier.dart';
import 'package:dlg_app/models/auth_state.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock flutter_secure_storage
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

  group('AuthNotifier', () {
    test('initial state is unknown with initializing true', () {
      final notifier = AuthNotifier();
      expect(notifier.state.status, SessionStatus.unknown);
      expect(notifier.initializing, true);
      expect(notifier.isLoading, false);
      expect(notifier.errorMessage, null);
      expect(notifier.restNonce, null);
    });

    test('clearError resets errorMessage', () {
      final notifier = AuthNotifier();
      notifier.clearError();
      expect(notifier.errorMessage, null);
    });

    test('continueAsGuest sets guest state', () async {
      final notifier = AuthNotifier();
      await notifier.continueAsGuest();
      expect(notifier.state.isGuest, true);
      expect(notifier.state.status, SessionStatus.guest);
    });

    test('notifies listeners on continueAsGuest', () async {
      final notifier = AuthNotifier();
      bool notified = false;
      notifier.addListener(() => notified = true);
      await notifier.continueAsGuest();
      expect(notified, true);
    });

    test('state getters are correct for guest', () async {
      final notifier = AuthNotifier();
      await notifier.continueAsGuest();
      expect(notifier.state.isGuest, true);
      expect(notifier.state.isLoggedIn, false);
      expect(notifier.state.hasDecided, true);
    });
  });
}