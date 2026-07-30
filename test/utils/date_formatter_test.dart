import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/utils/date_formatter.dart';

void main() {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  group('short', () {
    test('devuelve "Hoy" para la fecha actual', () {
      expect(DateFormatter.short(DateTime.now()), 'Hoy');
    });

    test('devuelve "Hoy" a primera hora del día', () {
      expect(DateFormatter.short(hoy), 'Hoy');
    });

    test('devuelve "Hoy" a última hora del día', () {
      final casiMedianoche = hoy.add(const Duration(
        hours: 23,
        minutes: 59,
        seconds: 59,
      ));

      expect(DateFormatter.short(casiMedianoche), 'Hoy');
    });

    test('devuelve "Ayer" para el día anterior', () {
      expect(
        DateFormatter.short(hoy.subtract(const Duration(days: 1))),
        'Ayer',
      );
    });

    test('devuelve "Ayer" aunque hayan pasado pocas horas', () {
      // Ayer a las 23:00 son menos de 24 horas si ahora es de madrugada,
      // pero sigue siendo el día natural anterior.
      final ayerDeNoche =
          hoy.subtract(const Duration(days: 1)).add(const Duration(hours: 23));

      expect(DateFormatter.short(ayerDeNoche), 'Ayer');
    });

    test('devuelve día y mes abreviado a partir de anteayer', () {
      final anteayer = hoy.subtract(const Duration(days: 2));
      final esperado =
          '${anteayer.day} ${_abreviado(anteayer.month)}';

      expect(DateFormatter.short(anteayer), esperado);
    });

    test('no incluye el año en el formato corto', () {
      expect(DateFormatter.short(DateTime(2020, 3, 15)), '15 mar');
    });

    test('abrevia correctamente los doce meses', () {
      const esperados = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];

      for (var mes = 1; mes <= 12; mes++) {
        expect(
          DateFormatter.short(DateTime(2020, mes, 10)),
          '10 ${esperados[mes - 1]}',
          reason: 'falla el mes $mes',
        );
      }
    });

    test('una fecha futura no se considera "Hoy"', () {
      final manana = hoy.add(const Duration(days: 1));
      final esperado = '${manana.day} ${_abreviado(manana.month)}';

      expect(DateFormatter.short(manana), esperado);
    });

    test('compara por día natural, no por horas transcurridas', () {
      // Justo un minuto después de medianoche, la diferencia con las 23:59
      // de ayer es de un minuto, pero son días distintos.
      final ayerTarde = hoy
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 23, minutes: 59));

      expect(DateFormatter.short(ayerTarde), 'Ayer');
    });
  });

  group('medium', () {
    test('incluye día, mes abreviado y año', () {
      expect(DateFormatter.medium(DateTime(2026, 4, 21)), '21 abr 2026');
    });

    test('no aplica ningún caso especial para hoy', () {
      final esperado = '${hoy.day} ${_abreviado(hoy.month)} ${hoy.year}';

      expect(DateFormatter.medium(DateTime.now()), esperado);
    });

    test('no rellena el día con ceros', () {
      expect(DateFormatter.medium(DateTime(2026, 1, 5)), '5 ene 2026');
    });

    test('abrevia correctamente los doce meses', () {
      const esperados = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];

      for (var mes = 1; mes <= 12; mes++) {
        expect(
          DateFormatter.medium(DateTime(2026, mes, 1)),
          '1 ${esperados[mes - 1]} 2026',
          reason: 'falla el mes $mes',
        );
      }
    });

    test('funciona con fechas antiguas', () {
      expect(DateFormatter.medium(DateTime(1999, 12, 31)), '31 dic 1999');
    });

    test('ignora la hora de la fecha', () {
      expect(
        DateFormatter.medium(DateTime(2026, 4, 21, 18, 30)),
        '21 abr 2026',
      );
    });
  });

  group('long', () {
    test('devuelve "Hoy" para la fecha actual', () {
      expect(DateFormatter.long(DateTime.now()), 'Hoy');
    });

    test('devuelve "Hoy" a primera hora del día', () {
      expect(DateFormatter.long(hoy), 'Hoy');
    });

    test('devuelve "Hoy" a última hora del día', () {
      final casiMedianoche = hoy.add(const Duration(hours: 23, minutes: 59));

      expect(DateFormatter.long(casiMedianoche), 'Hoy');
    });

    test('escribe el mes completo para otras fechas', () {
      expect(
        DateFormatter.long(DateTime(2026, 4, 21)),
        '21 de abril de 2026',
      );
    });

    test('no tiene caso especial para ayer', () {
      final ayer = hoy.subtract(const Duration(days: 1));
      final esperado = '${ayer.day} de ${_completo(ayer.month)} de ${ayer.year}';

      expect(DateFormatter.long(ayer), esperado);
    });

    test('distingue el mismo día de otro año', () {
      final otroAno = DateTime(hoy.year - 1, hoy.month, hoy.day);
      final esperado =
          '${otroAno.day} de ${_completo(otroAno.month)} de ${otroAno.year}';

      expect(DateFormatter.long(otroAno), esperado);
    });

    test('escribe correctamente los doce meses', () {
      const esperados = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
      ];

      for (var mes = 1; mes <= 12; mes++) {
        expect(
          DateFormatter.long(DateTime(2020, mes, 15)),
          '15 de ${esperados[mes - 1]} de 2020',
          reason: 'falla el mes $mes',
        );
      }
    });

    test('funciona con fechas futuras', () {
      expect(
        DateFormatter.long(DateTime(2099, 1, 1)),
        '1 de enero de 2099',
      );
    });
  });

  group('Coherencia entre formatos', () {
    test('short y long coinciden en el día de hoy', () {
      final ahora = DateTime.now();

      expect(DateFormatter.short(ahora), 'Hoy');
      expect(DateFormatter.long(ahora), 'Hoy');
    });

    test('medium nunca devuelve texto relativo', () {
      expect(DateFormatter.medium(DateTime.now()), isNot('Hoy'));
      expect(
        DateFormatter.medium(hoy.subtract(const Duration(days: 1))),
        isNot('Ayer'),
      );
    });

    test('los tres formatos coinciden en el día del mes', () {
      final fecha = DateTime(2026, 6, 9);

      expect(DateFormatter.short(fecha), startsWith('9 '));
      expect(DateFormatter.medium(fecha), startsWith('9 '));
      expect(DateFormatter.long(fecha), startsWith('9 de '));
    });
  });
}

// ─── Ayudas ───────────────────────────────────────────────────────────────────

String _abreviado(int mes) => const [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ][mes - 1];

String _completo(int mes) => const [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ][mes - 1];
