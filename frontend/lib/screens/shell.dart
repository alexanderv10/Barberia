import 'package:flutter/material.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home.dart';
import 'agenda.dart';
import 'loyalty.dart';
import 'scanner.dart';
import 'admin.dart';
import 'booking.dart';

class AppShell extends StatefulWidget {
  final Store store;
  const AppShell({super.key, required this.store});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int page = 0;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.store.refresh();
      if (mounted && widget.store.pendingReservation) {
        final s = widget.store;
        final selected = s.services
            .where((item) => item['id'] == s.pendingServiceId)
            .firstOrNull;
        s.pendingReservation = false;
        s.pendingServiceId = null;
        if (!s.staff && s.services.isNotEmpty && s.barbers.isNotEmpty) {
          setState(() => loading = false);
          await openBooking(context, s, service: selected);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void navigate(int p) => setState(() => page = p);
  List<(String, IconData)> get destinations => widget.store.staff
      ? [
          ('Agenda', Icons.calendar_month_outlined),
          ('Escanear QR', Icons.qr_code_scanner),
          ('Servicios', Icons.content_cut),
          ('Mi cuenta', Icons.person_outline),
        ]
      : [
          ('Inicio', Icons.grid_view_outlined),
          ('Mis citas', Icons.calendar_month_outlined),
          ('Mis sellos', Icons.loyalty_outlined),
          ('Servicios', Icons.content_cut),
          ('Mi cuenta', Icons.person_outline),
        ];
  Widget content() {
    final s = widget.store;
    if (page == destinations.length - 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Mi cuenta',
            'Tu espacio personal en la barbería.',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.soft,
                  child: Text(
                    s.user!['name'][0],
                    style: const TextStyle(
                      fontSize: 26,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  s.user!['name'],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  s.user!['email'],
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 15),
                Text(
                  'Perfil: ${{'CLIENT': 'Cliente', 'BARBER': 'Barbero', 'ADMIN': 'Administrador'}[s.user!['role']]}',
                ),
                const SizedBox(height: 26),
                OutlinedButton.icon(
                  onPressed: s.logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if ((!s.staff && page == 3) || (s.staff && page == 2)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Nuestros servicios',
            'Elige cómo quieres verte y sentirte.',
          ),
          if (s.admin) AdminTools(store: s),
          ServiceGrid(store: s),
          if (s.services.isEmpty)
            const EmptyState(
              'Catálogo en preparación',
              'Los servicios disponibles aparecerán aquí.',
            ),
        ],
      );
    }
    if (s.staff) {
      return page == 0 ? AgendaScreen(store: s) : ScannerScreen(store: s);
    }
    return switch (page) {
      0 => HomeScreen(store: s, navigate: navigate),
      1 => AgendaScreen(store: s),
      _ => LoyaltyScreen(store: s),
    };
  }

  Widget sideNav() => Container(
    width: 235,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 32, 22, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(),
        const SizedBox(height: 15),
        Text(
          widget.store.staff ? 'ESPACIO PROFESIONAL' : 'TU BARBERÍA, CONTIGO',
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.5,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 44),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 12),
          child: Text(
            'MI ESPACIO',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.6,
              color: AppColors.muted,
            ),
          ),
        ),
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: ListTile(
              dense: true,
              selected: page == i,
              selectedTileColor: AppColors.soft,
              selectedColor: AppColors.accent,
              textColor: AppColors.muted,
              iconColor: AppColors.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Icon(destinations[i].$2, size: 20),
              title: Text(
                destinations[i].$1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: page == i ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              onTap: () => navigate(i),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_border, color: AppColors.accent, size: 20),
              SizedBox(height: 10),
              Text(
                'Siempre es buen momento\npara un buen corte.',
                style: TextStyle(fontSize: 12, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.soft,
            child: Text(
              widget.store.user!['name'][0],
              style: const TextStyle(color: AppColors.accent),
            ),
          ),
          title: Text(
            widget.store.user!['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            widget.store.staff ? 'Profesional' : 'Miembro del club',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          trailing: IconButton(
            onPressed: widget.store.logout,
            icon: const Icon(Icons.logout, size: 17),
            tooltip: 'Cerrar sesión',
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 1000;
      return Scaffold(
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: page,
                onDestinationSelected: navigate,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: destinations
                    .map(
                      (d) =>
                          NavigationDestination(icon: Icon(d.$2), label: d.$1),
                    )
                    .toList(),
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (wide) sideNav(),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 77,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: AppColors.line),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: wide ? 38 : 20),
                      child: Row(
                        children: [
                          if (!wide)
                            const Brand()
                          else
                            Text(
                              destinations[page].$1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Spacer(),
                          if (wide)
                            const Text(
                              'Tu próximo buen corte empieza aquí',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: loading ? null : load,
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Actualizar',
                          ),
                          const SizedBox(width: 10),
                          const CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.soft,
                            child: Icon(
                              Icons.person_outline,
                              size: 19,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.store.demo)
                      Container(
                        width: double.infinity,
                        color: const Color(0xFFFFF3D9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
                        ),
                        child: const Text(
                          'MODO DEMOSTRACIÓN · Datos de ejemplo. Las acciones no crean reservas reales.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8C6A29),
                          ),
                        ),
                      ),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(error!, textAlign: TextAlign.center),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: load,
                                      child: const Text('Reintentar'),
                                    ),
                                    TextButton(
                                      onPressed: widget.store.logout,
                                      child: const Text('Volver a ingresar'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: load,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.all(wide ? 38 : 20),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1200,
                                    ),
                                    child: content(),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
