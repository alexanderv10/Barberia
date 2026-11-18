import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barberia/main.dart';
import 'test_helpers.dart';

void main() {
  testWidgets('cliente puede explorar demo, tarjeta y reserva a ancho móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = testStore();
    await tester.pumpWidget(BarberiaApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('EXPLORA LA EXPERIENCIA'), findsNothing);
    expect(find.text('Demo cliente'), findsNothing);
    expect(find.text('Demo barbero'), findsNothing);
    store.enterDemo();
    await tester.pumpAndSettle();
    expect(find.textContaining('MODO DEMOSTRACIÓN'), findsOneWidget);
    expect(find.text('Hola, Alex 👋'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.loyalty_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Mi tarjeta de sellos'), findsOneWidget);
    expect(find.text('7 / 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nueva cita'));
    await tester.pumpAndSettle();
    expect(find.text('Reserva tu momento'), findsOneWidget);
    expect(find.text('Confirmar cita'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('barbero valida QR demo y completa una cita', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = testStore()..enterDemo(asStaff: true);
    await tester.pumpWidget(BarberiaApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Aceptar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar QR de ejemplo'));
    await tester.pumpAndSettle();
    expect(find.text('7 / 10 sellos'), findsOneWidget);
    await tester.ensureVisible(find.text('Completar servicio'));
    await tester.tap(find.text('Completar servicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar QR de ejemplo'));
    await tester.pumpAndSettle();
    expect(find.text('8 / 10 sellos'), findsOneWidget);
    expect(find.text('Sin servicios para completar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
