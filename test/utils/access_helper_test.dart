import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dlg_app/models/article.dart';
import 'package:dlg_app/models/auth_state.dart';
import 'package:dlg_app/services/auth_notifier.dart';
import 'package:dlg_app/services/auth_service.dart';
import 'package:dlg_app/services/theme_notifier.dart';
import 'package:dlg_app/utils/access_helper.dart';
import 'package:dlg_app/widgets/access_dialog.dart';

/// Doble de AuthService que no toca red ni almacenamiento.
class FakeAuthService extends AuthService {
  @override
  Future<AuthState> loadSavedSession() async => const AuthState.unknown();

  @override
  Future<bool> isMembershipStale() async => false;

  @override
  Future<NonceResult> getRestNonceWithStatus(String cookies) async =>
      const NonceResult(nonce: null, sessionExpired: false);

  @override
  Future<void> logout() async {}
}

/// AuthNotifier con el estado ya fijado, sin pasar por initialize().
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this._fixedState) : super(service: FakeAuthService());

  final AuthState _fixedState;

  @override
  AuthState get state => _fixedState;
}

// ─── Estados de sesión ────────────────────────────────────────────────────────

const _anonimo = AuthState.unknown();
const _invitado = AuthState.guest();

const _registradoSinSuscripcion = AuthState(
  status: SessionStatus.loggedIn,
  cookies: 'wordpress=abc',
  userEmail: 'lector@ejemplo.es',
  userDisplayName: 'Lector',
  isSubscriber: false,
);

// ─── Artículos ────────────────────────────────────────────────────────────────

Article buildArticle({bool isPremium = false, int id = 1}) => Article(
      id: id,
      date: DateTime(2026, 7, 1),
      title: 'Titular de prueba',
      description: 'Resumen',
      author: 'Autor',
      imageUrl: '',
      isPremium: isPremium,
      slug: 'titular-de-prueba',
    );

/// Monta un botón que invoca openArticle con el estado de sesión indicado.
Widget buildHarness({
  required AuthState authState,
  required Article article,
  VoidCallback? onJumpToProfile,
  bool withTabNavigator = true,
}) {
  Widget boton = Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => openArticle(context, article),
      child: const Text('Abrir'),
    ),
  );

  if (withTabNavigator) {
    boton = TabNavigator(
      jumpToProfile: onJumpToProfile ?? () {},
      child: boton,
    );
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthNotifier>.value(
        value: FakeAuthNotifier(authState),
      ),
      ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
    ],
    child: MaterialApp(home: Scaffold(body: boton)),
  );
}

void main() {
  group('Contenido exclusivo bloqueado', () {
    testWidgets('un anónimo ve el diálogo con la invitación a iniciar sesión',
        (tester) async {
      await tester.pumpWidget(buildHarness(
        authState: _anonimo,
        article: buildArticle(isPremium: true),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido exclusivo'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(
          find.textContaining('exclusivo para suscriptores'), findsOneWidget);
    });

    testWidgets('un invitado ve el mismo diálogo', (tester) async {
      await tester.pumpWidget(buildHarness(
        authState: _invitado,
        article: buildArticle(isPremium: true),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('un registrado sin suscripción ve el aviso de su plan',
        (tester) async {
      await tester.pumpWidget(buildHarness(
        authState: _registradoSinSuscripcion,
        article: buildArticle(isPremium: true),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido exclusivo'), findsOneWidget);
      expect(find.textContaining('Tu plan actual'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing,
          reason: 'ya tiene sesión iniciada');
    });

    testWidgets('no se navega al detalle del artículo', (tester) async {
      await tester.pumpWidget(buildHarness(
        authState: _anonimo,
        article: buildArticle(isPremium: true),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir'), findsOneWidget,
          reason: 'la pantalla de origen sigue visible');
    });

    testWidgets('el botón de cerrar descarta el diálogo', (tester) async {
      await tester.pumpWidget(buildHarness(
        authState: _anonimo,
        article: buildArticle(isPremium: true),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido exclusivo'), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });
  });

  group('Salto a la pestaña de perfil', () {
    testWidgets('iniciar sesión cierra el diálogo y salta al perfil',
        (tester) async {
      var saltos = 0;
      await tester.pumpWidget(buildHarness(
        authState: _anonimo,
        article: buildArticle(isPremium: true),
        onJumpToProfile: () => saltos++,
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(saltos, 1);
      expect(find.text('Contenido exclusivo'), findsNothing);
    });

    testWidgets('no falla si no hay TabNavigator por encima', (tester) async {
      await tester.pumpWidget(buildHarness(
        authState: _anonimo,
        article: buildArticle(isPremium: true),
        withTabNavigator: false,
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido exclusivo'), findsNothing);
    });
  });
}
