import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/auth_state.dart';

void main() {
  group('MembershipInfo', () {
    test('isActive returns true for "activo"', () {
      final m = MembershipInfo(name: 'Premium', status: 'Activo');
      expect(m.isActive, true);
    });

    test('isActive returns true for "active"', () {
      final m = MembershipInfo(name: 'Premium', status: 'active');
      expect(m.isActive, true);
    });

    test('isActive is case insensitive', () {
      final m = MembershipInfo(name: 'Premium', status: 'ACTIVO');
      expect(m.isActive, true);
    });

    test('isActive returns false for inactive status', () {
      final m = MembershipInfo(name: 'Premium', status: 'Cancelado');
      expect(m.isActive, false);
    });

    test('expiresAt can be null', () {
      final m = MembershipInfo(name: 'Premium', status: 'Activo');
      expect(m.expiresAt, null);
    });

    test('expiresAt stores value correctly', () {
      final m = MembershipInfo(
        name: 'Premium',
        status: 'Activo',
        expiresAt: '21 de abril de 2026',
      );
      expect(m.expiresAt, '21 de abril de 2026');
    });
  });

  group('AuthState', () {
    test('unknown() factory sets correct status', () {
      const state = AuthState.unknown();
      expect(state.status, SessionStatus.unknown);
      expect(state.isLoggedIn, false);
      expect(state.isGuest, false);
      expect(state.hasDecided, false);
    });

    test('guest() factory sets correct status', () {
      const state = AuthState.guest();
      expect(state.status, SessionStatus.guest);
      expect(state.isLoggedIn, false);
      expect(state.isGuest, true);
      expect(state.hasDecided, true);
    });

    test('loggedIn state has correct getters', () {
      const state = AuthState(
        status: SessionStatus.loggedIn,
        cookies: 'abc123',
        userEmail: 'user@test.com',
        userDisplayName: 'Test User',
        isSubscriber: true,
      );
      expect(state.isLoggedIn, true);
      expect(state.isGuest, false);
      expect(state.hasDecided, true);
      expect(state.cookies, 'abc123');
      expect(state.userEmail, 'user@test.com');
      expect(state.isSubscriber, true);
    });

    test('default isSubscriber is false', () {
      const state = AuthState(status: SessionStatus.loggedIn);
      expect(state.isSubscriber, false);
    });

    test('membership can be null', () {
      const state = AuthState(status: SessionStatus.loggedIn);
      expect(state.membership, null);
    });

    test('membership stores MembershipInfo correctly', () {
      const membership = MembershipInfo(name: 'DLG Premium', status: 'Activo');
      const state = AuthState(
        status: SessionStatus.loggedIn,
        membership: membership,
      );
      expect(state.membership?.name, 'DLG Premium');
      expect(state.membership?.isActive, true);
    });
  });

  group('SessionStatus', () {
    test('has three values', () {
      expect(SessionStatus.values.length, 3);
    });
  });
}
