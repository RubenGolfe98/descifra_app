enum SessionStatus { unknown, guest, loggedIn }

class MembershipInfo {
  final String name;
  final String status;
  final String? expiresAt;
  final String? newsletterHtml; // Contenido del último boletín

  const MembershipInfo({
    required this.name,
    required this.status,
    this.expiresAt,
    this.newsletterHtml,
  });

  bool get isActive =>
      status.toLowerCase().contains('activo') ||
      status.toLowerCase().contains('active');

  /// True si el plan incluye newsletter (básico o superior)
  bool get hasNewsletter => newsletterHtml != null && newsletterHtml!.trim().isNotEmpty;
}

class AuthState {
  final SessionStatus status;
  final String? cookies;
  final String? userEmail;
  final String? userDisplayName;
  final bool isSubscriber;
  final MembershipInfo? membership;

  const AuthState({
    required this.status,
    this.cookies,
    this.userEmail,
    this.userDisplayName,
    this.isSubscriber = false,
    this.membership,
  });

  const AuthState.unknown() : this(status: SessionStatus.unknown);
  const AuthState.guest()   : this(status: SessionStatus.guest);

  bool get isLoggedIn => status == SessionStatus.loggedIn;
  bool get isGuest    => status == SessionStatus.guest;
  bool get hasDecided => status != SessionStatus.unknown;
}