import 'package:flutter/material.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home.dart';

class PublicHome extends StatefulWidget {
  final Store store;
  const PublicHome({super.key, required this.store});
  @override
  State<PublicHome> createState() => _PublicHomeState();
}

class _PublicHomeState extends State<PublicHome> {
  bool loading = true;
  String? error;
  final servicesKey = GlobalKey();
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
      await widget.store.loadPublic();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No pudimos cargar el catálogo. Vuelve a intentarlo en un momento.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void catalog() {
    final target = servicesKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
      );
    }
  }

  Widget info(IconData icon, String title, String detail) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accent),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(detail, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Brand(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => store.requestLogin(),
                    icon: const Icon(Icons.person_outline, size: 19),
                    label: const Text('Iniciar sesión'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'TU ESTILO, A TU RITMO',
                            style: TextStyle(
                              color: AppColors.accent,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            store.shop['name'] ?? 'Tu barbería, contigo.',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            store.shop['description'] ??
                                'Un espacio para cuidarte. Un momento para ti.',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 28),
                          LayoutBuilder(
                            builder: (_, size) {
                              final hero = Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(
                                  size.maxWidth < 500 ? 26 : 36,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EFEB),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'UN BUEN LOOK EMPIEZA AQUÍ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.accent,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Text(
                                      'Haz tiempo\npara tu estilo.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                            fontSize: size.maxWidth < 500
                                                ? 37
                                                : 46,
                                            height: 1.12,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Conoce nuestros servicios, encuentra tu barbero\ny elige el próximo momento para cuidarte.',
                                      style: TextStyle(
                                        color: Color(0xFF62746C),
                                        height: 1.8,
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () =>
                                              store.requestLogin(booking: true),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text(
                                            'Reservar una cita',
                                          ),
                                        ),
                                        OutlinedButton(
                                          onPressed: catalog,
                                          child: const Text('Ver servicios'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      store.shop['hours'] ??
                                          'Lunes a sábado · 09:00 a 19:00',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              final club = Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(30),
                                decoration: BoxDecoration(
                                  color: AppColors.ink,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.loyalty_outlined,
                                      color: Color(0xFFB6D2C4),
                                      size: 30,
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'CLUB BARBERÍA',
                                      style: TextStyle(
                                        color: Color(0xFFB6D2C4),
                                        fontSize: 10,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Cada visita\ntiene recompensa.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        height: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'Acumula 10 sellos y disfruta un corte clásico gratis.\nIngresa a tu cuenta para consultar tu tarjeta, tus citas y tus beneficios.',
                                      style: TextStyle(
                                        color: Color(0xFFCFD9DC),
                                        height: 1.8,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextButton(
                                      onPressed: () => store.requestLogin(),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFD4E8DE,
                                        ),
                                      ),
                                      child: const Text('Entrar a mi cuenta →'),
                                    ),
                                  ],
                                ),
                              );
                              return size.maxWidth > 800
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 5, child: hero),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 4, child: club),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        hero,
                                        const SizedBox(height: 22),
                                        club,
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 32),
                          LayoutBuilder(
                            builder: (_, size) {
                              final items = [
                                info(
                                  Icons.schedule,
                                  'Horario de atención',
                                  store.shop['hours'] ??
                                      'Lunes a sábado · 09:00 a 19:00',
                                ),
                                info(
                                  Icons.location_on_outlined,
                                  'Dónde encontrarnos',
                                  store.shop['address'] ??
                                      'Dirección por confirmar.',
                                ),
                                info(
                                  Icons.phone_outlined,
                                  'Contacto',
                                  store.shop['phone'] ??
                                      'Datos de contacto por confirmar.',
                                ),
                              ];
                              return size.maxWidth > 800
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (
                                          var i = 0;
                                          i < items.length;
                                          i++
                                        ) ...[
                                          if (i > 0) const SizedBox(width: 18),
                                          Expanded(child: items[i]),
                                        ],
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final item in items) ...[
                                          item,
                                          const SizedBox(height: 14),
                                        ],
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 32),
                          SectionTitle(
                            key: servicesKey,
                            'Nuestros servicios',
                            'Conoce los precios y elige tu próximo look.',
                          ),
                          if (loading)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (error != null)
                            Panel(
                              child: Column(
                                children: [
                                  Text(error!),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: load,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            )
                          else if (store.services.isEmpty)
                            const Panel(
                              child: EmptyState(
                                'Catálogo en preparación',
                                'Pronto podrás consultar nuestros servicios.',
                              ),
                            )
                          else
                            ServiceGrid(
                              store: store,
                              onReserve: (service) => store.requestLogin(
                                booking: true,
                                service: service,
                              ),
                            ),
                          const SizedBox(height: 32),
                          const SectionTitle(
                            'Nuestro equipo',
                            'Profesionales que cuidan cada detalle.',
                          ),
                          if (!loading &&
                              error == null &&
                              store.barbers.isEmpty)
                            const Text(
                              'Pronto conocerás a nuestro equipo.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: store.barbers
                                .map(
                                  (b) => SizedBox(
                                    width: 260,
                                    child: Panel(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.soft,
                                            child: Text(
                                              (b['name'] as String).substring(
                                                0,
                                                1,
                                              ),
                                              style: const TextStyle(
                                                color: AppColors.accent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b['name'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const Text(
                                                  'Barbero',
                                                  style: TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 36),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Consulta nuestros servicios sin registrarte. Tu cuenta guarda tus citas y recompensas.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
