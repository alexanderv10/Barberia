import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:barberia/data/api.dart';
import 'package:barberia/data/store.dart';
import 'package:barberia/screens/account_access.dart';
import 'package:barberia/screens/login.dart';

void main() {
  testWidgets(
    'recuperación desde login envía el correo y muestra respuesta neutral',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      final store = Store(
        api: Api(
          client: MockClient((request) async {
            expect(request.url.path, '/api/auth/password/forgot');
            bodies.add(jsonDecode(request.body));
            return http.Response(
              '{"message":"Si existe una cuenta, recibirás un enlace."}',
              201,
            );
          }),
        ),
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: LoginScreen(store: store)));
      await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'cliente@example.com');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();
      expect(bodies.single, {'email': 'cliente@example.com'});
      expect(
        find.text('Si existe una cuenta, recibirás un enlace.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reset valida confirmación y limpia la sesión tras guardar', (
    tester,
  ) async {
    var calls = 0;
    final store = Store(
      api: Api(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/auth/password/reset');
          expect(jsonDecode(request.body), {
            'token': 'a' * 64,
            'password': 'NewPassword2026!',
          });
          return http.Response('{"message":"Contraseña actualizada."}', 201);
        }),
      ),
    );
    store.user = {'id': 'old-session'};
    store.api.token = 'old-token';
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          store: store,
          action: 'reset',
          token: 'a' * 64,
          onDone: () {},
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'NewPassword2026!',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'DifferentPassword!',
    );
    await tester.ensureVisible(find.text('Guardar nueva contraseña'));
    await tester.tap(find.text('Guardar nueva contraseña'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'NewPassword2026!',
    );
    await tester.tap(find.text('Guardar nueva contraseña'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(store.user, isNull);
    expect(store.api.token, isNull);
    expect(find.text('Contraseña actualizada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abrir verificación no consume el enlace hasta confirmar', (
    tester,
  ) async {
    var calls = 0;
    final store = Store(
      api: Api(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/auth/email/verify');
          expect(jsonDecode(request.body), {'token': 'b' * 64});
          return http.Response('{"message":"Correo verificado."}', 201);
        }),
      ),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAccessScreen(
          store: store,
          action: 'verify',
          token: 'b' * 64,
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Verificar mi correo'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Correo verificado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
