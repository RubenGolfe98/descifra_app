enum SessionStatus { unknown, guest, loggedIn }

class AuthState {
  final SessionStatus status;
  final String? cookies;       // sesión WooCommerce (nunca usuario/contraseña)
  final String? userEmail;
  final String? userDisplayName;
  final bool isSubscriber;

  const AuthState({
    required this.status,
    this.cookies,
    this.userEmail,
    this.userDisplayName,
    this.isSubscriber = false,
  });

  const AuthState.unknown() : this(status: SessionStatus.unknown);
  const AuthState.guest()   : this(status: SessionStatus.guest);

  bool get isLoggedIn  => status == SessionStatus.loggedIn;
  bool get isGuest     => status == SessionStatus.guest;
  bool get hasDecided  => status != SessionStatus.unknown;
}