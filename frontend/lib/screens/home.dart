import 'package:flutter/material.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'agenda.dart';
import 'booking.dart';
import 'loyalty.dart';

class HomeScreen extends StatelessWidget {
  final Store store;
  final ValueChanged<int> navigate;
  const HomeScreen({super.key, required this.store, required this.navigate});
  @override
  Widget build(BuildContext context) {
    final pending =
        store.appointments.where((a) => a['status'] == 'PENDING').toList()
          ..sort((a, b) => a['startsAt'].compareTo(b['startsAt']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TU ESTILO, A TU RITMO',
          style: TextStyle(
            color: AppColors.accent,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hola, ${store.user!['name'].split(' ').first} 👋',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Un espacio para cuidarte. Un momento para ti.',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (_, size) {
            final welcome = Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EFEB),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                            const SizedBox(height: 16),
                            Text(
                              'Haz tiempo\npara tu estilo.',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(fontSize: 37, height: 1.12),
                            ),
                          ],
                        ),
                      ),
                      if (size.maxWidth > 540)
                        Container(
                          width: 105,
                          height: 125,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(55),
                          ),
                          child: Transform.rotate(
                            angle: -.5,
                            child: const Icon(
                              Icons.content_cut,
                              size: 62,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tu barbero favorito, a un par de toques.\nElige tu servicio y nosotros nos encargamos del resto.',
                    style: TextStyle(color: Color(0xFF62746C), height: 1.8),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: store.services.isEmpty || store.barbers.isEmpty
                        ? null
                        : () => openBooking(context, store),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Reservar una cita'),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Lun – Sáb  ·  09:00 – 19:00  ·  Ecuador',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            );
            final loyalty = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StampCard(store: store, compact: true),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => navigate(2),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text('Ver mi tarjeta y QR'),
                ),
              ],
            );
            return size.maxWidth > 850
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: welcome),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: loyalty),
                    ],
                  )
                : Column(
                    children: [welcome, const SizedBox(height: 22), loyalty],
                  );
          },
        ),
        const SizedBox(height: 30),
        SectionTitle(
          'Tu próxima visita',
          'Nos vemos pronto en la silla.',
          action: TextButton(
            onPressed: () => navigate(1),
            child: const Text('Ver todas'),
          ),
        ),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: pending.isEmpty
              ? const EmptyState(
                  'Tu próxima visita te espera',
                  'Elige un servicio y encuentra el mejor horario para ti.',
                )
              : AppointmentTile(appointment: pending.first, store: store),
        ),
        const SizedBox(height: 30),
        SectionTitle(
          'Encuentra tu servicio',
          'El cuidado está en los detalles.',
          action: TextButton(
            onPressed: () => navigate(3),
            child: const Text('Ver catálogo'),
          ),
        ),
        ServiceGrid(store: store),
        const SizedBox(height: 30),
        const SectionTitle(
          'Visítanos',
          'La información de tu barbería, siempre a mano.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.shop['name'] ?? 'Barbería',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Text(store.shop['hours'] ?? 'Lunes a sábado · 09:00 a 19:00'),
              const SizedBox(height: 8),
              Text(store.shop['address'] ?? 'Dirección por confirmar.'),
              Text(store.shop['phone'] ?? 'Datos de contacto por confirmar.'),
              const SizedBox(height: 18),
              const Text(
                'Nuestro equipo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: store.barbers
                    .map(
                      (b) => Chip(
                        label: Text(b['name']),
                        avatar: const Icon(Icons.person_outline, size: 17),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ServiceGrid extends StatelessWidget {
  final Store store;
  final void Function(Map<String, dynamic>)? onReserve;
  const ServiceGrid({super.key, required this.store, this.onReserve});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final cols = constraints.maxWidth > 900
          ? 3
          : constraints.maxWidth > 550
          ? 2
          : 1;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: store.services.asMap().entries.map((entry) {
          final s = entry.value;
          return SizedBox(
            width: (constraints.maxWidth - (cols - 1) * 18) / cols,
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          [
                            Icons.content_cut,
                            Icons.face_retouching_natural,
                            Icons.auto_awesome,
                          ][entry.key % 3],
                          size: 24,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${s['durationMin']} min',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    s['name'],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: Text(
                      s['description'],
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '\$${(s['priceCents'] / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (!store.staff)
                        IconButton(
                          onPressed: () => onReserve != null
                              ? onReserve!(s)
                              : openBooking(context, store, service: s),
                          icon: const Icon(
                            Icons.arrow_forward,
                            color: AppColors.accent,
                          ),
                          tooltip: 'Reservar ${s['name']}',
                        ),
                    ],
                  ),
                  if (s['rewardEligible'] == true)
                    const Text(
                      'Disponible como corte de regalo',
                      style: TextStyle(color: AppColors.accent, fontSize: 10),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}
