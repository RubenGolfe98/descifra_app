import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/auth_exception.dart';

void main() {
  group('AuthException', () {
    test('almacena el mensaje', () {
      const e = AuthException('Credenciales inválidas');
      expect(e.message, 'Credenciales inválidas');
    });

    test('toString devuelve el mensaje', () {
      const e = AuthException('Error de red');
      expect(e.toString(), 'Error de red');
    });

    test('implementa Exception', () {
      const e = AuthException('test');
      expect(e, isA<Exception>());
    });
  });
}
