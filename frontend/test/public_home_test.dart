import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barberia/main.dart';
import 'test_helpers.dart';

void main() {
  testWidgets(
    'inicio público no consulta datos privados y permite volver del acceso',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      await tester.pumpWidget(
        BarberiaApp(store: testStore(requests: requests)),
      );
      await tester.pumpAndSettle();
      expect(requests.toSet(), {'shop', 'services', 'users/barbers'});
      expect(find.text('Hola, Alex 👋'), findsNothing);
      expect(find.text('Tu próxima visita'), findsNothing);
      expect(find.text('7 / 10'), findsNothing);
      await tester.ensureVisible(find.text('Corte clásico'));
      expect(find.text('\$12.00'), findsOneWidget);
      await tester.tap(find.byTooltip('Reservar Corte clásico'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Inicia sesión o crea tu cuenta para continuar con tu reserva.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Volver a la barbería'));
      await tester.pumpAndSettle();
      expect(find.text('Ver servicios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'login retoma reserva elegida y logout vuelve al inicio público',
    (tester) async {
      await tester.pumpWidget(BarberiaApp(store: testStore()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Reservar Corte clásico'));
      await tester.tap(find.byTooltip('Reservar Corte clásico'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'cliente@ejemplo.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'UnaClave2026!',
      );
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Reserva tu momento'), findsOneWidget);
      expect(find.textContaining('Corte clásico ·'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Alex 👋'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.person_outline).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Ver servicios'), findsOneWidget);
      expect(find.text('Hola, Alex 👋'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fallo del catálogo mantiene inicio público y permite reintentar',
    (tester) async {
      await tester.pumpWidget(BarberiaApp(store: testStore(unavailable: true)));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Tu próxima visita'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
