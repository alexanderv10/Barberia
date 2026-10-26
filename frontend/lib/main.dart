import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/store.dart';
import 'theme.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/public_home.dart';

void main() => runApp(const BarberiaApp());

class BarberiaApp extends StatefulWidget {
  final Store? store;
  const BarberiaApp({super.key, this.store});
  @override
  State<BarberiaApp> createState() => _BarberiaAppState();
}

class _BarberiaAppState extends State<BarberiaApp> {
  late final store = widget.store ?? Store();
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Barbería · Tu próximo buen corte',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('es'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('es')],
    home: ListenableBuilder(
      listenable: store,
      builder: (context, _) => store.user == null
          ? store.authRequested
                ? LoginScreen(store: store)
                : PublicHome(store: store)
          : AppShell(key: ValueKey(store.user!['role']), store: store),
    ),
  );
}
