import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/store.dart';
import 'theme.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/public_home.dart';
import 'screens/account_access.dart';

void main() => runApp(const BarberiaApp());

class BarberiaApp extends StatefulWidget {
  final Store? store;
  const BarberiaApp({super.key, this.store});
  @override
  State<BarberiaApp> createState() => _BarberiaAppState();
}

class _BarberiaAppState extends State<BarberiaApp> {
  late final store = widget.store ?? Store();
  late Uri? actionLink = _readActionLink();
  Uri? _readActionLink() {
    final link = Uri.tryParse(Uri.base.fragment);
    if (link == null ||
        !['/account/verify', '/account/reset'].contains(link.path)) {
      return null;
    }
    return link;
  }

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
    // Handle account links explicitly; email tokens are in the fragment, never sent to the web server.
    initialRoute: '/',
    home: ListenableBuilder(
      listenable: store,
      builder: (context, _) => actionLink != null
          ? AccountAccessScreen(
              store: store,
              action: actionLink!.path.endsWith('/verify') ? 'verify' : 'reset',
              token: actionLink!.queryParameters['token'],
              onDone: () => setState(() => actionLink = null),
            )
          : store.user == null
          ? store.authRequested
                ? LoginScreen(store: store)
                : PublicHome(store: store)
          : AppShell(key: ValueKey(store.user!['role']), store: store),
    ),
  );
}
