import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'booking.dart';

class AppointmentTile extends StatefulWidget {
  final Json appointment;
  final Store store;
  const AppointmentTile({
    super.key,
    required this.appointment,
    required this.store,
  });
  @override
  State<AppointmentTile> createState() => _AppointmentTileState();
}

class _AppointmentTileState extends State<AppointmentTile> {
  bool busy = false;
  Future<void> accept() async {
    setState(() => busy = true);
    try {
      await widget.store.accept(widget.appointment);
      if (mounted) toast(context, 'Cita aceptada.');
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: const Text('El horario quedará disponible para otra persona.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Conservar cita'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.cancel(widget.appointment);
      if (mounted) toast(context, 'Cita cancelada.');
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final status = a['status'];
    final label = {
      'PENDING': a['acceptedAt'] == null ? 'Pendiente' : 'Aceptada',
      'COMPLETED': 'Completada',
      'CANCELLED': 'Cancelada',
    }[status]!;
    final color = status == 'PENDING'
        ? const Color(0xFF9A762F)
        : status == 'COMPLETED'
        ? AppColors.accent
        : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  timeLabel(a['startsAt']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  dayLabel(a['startsAt']),
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['service']['name'],
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.store.staff
                      ? a['client']['name']
                      : 'Con ${a['barber']['name']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  '${a['isReward'] == true ? 'Corte de regalo' : money(a['priceCents'])} · ${DateTime.parse(a['endsAt']).difference(DateTime.parse(a['startsAt'])).inMinutes} min',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status == 'PENDING')
                TextButton(
                  onPressed: busy ? null : cancel,
                  child: Text(
                    busy ? 'Cancelando…' : 'Cancelar',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              if (status == 'PENDING' &&
                  widget.store.staff &&
                  a['acceptedAt'] == null)
                TextButton(
                  onPressed: busy ? null : accept,
                  child: const Text('Aceptar', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AgendaScreen extends StatefulWidget {
  final Store store;
  const AgendaScreen({super.key, required this.store});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  String filter = 'PENDING', search = '';
  DateTime? date;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final items =
        store.appointments
            .where(
              (a) =>
                  (filter == 'ALL' || a['status'] == filter) &&
                  ('${a['service']['name']} ${a['client']['name']} ${a['barber']['name']}'
                      .toLowerCase()
                      .contains(search.toLowerCase())) &&
                  (date == null ||
                      DateUtils.isSameDay(shopDate(a['startsAt']), date)),
            )
            .toList()
          ..sort((a, b) => a['startsAt'].compareTo(b['startsAt']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          store.staff ? 'Tu agenda, al día' : 'Mis citas',
          store.staff
              ? 'Organiza tus servicios y cuida cada visita.'
              : 'Todo listo para tu próximo buen corte.',
          action: !store.staff
              ? IconButton(
                  onPressed: () => openBooking(context, store),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Nueva cita',
                )
              : null,
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar por servicio o nombre',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in {
                    'PENDING': 'Pendientes',
                    'COMPLETED': 'Completadas',
                    'CANCELLED': 'Canceladas',
                    'ALL': 'Todas',
                  }.entries)
                    ChoiceChip(
                      label: Text(f.value),
                      selected: filter == f.key,
                      onSelected: (_) => setState(() => filter = f.key),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 17),
                    label: Text(
                      date == null
                          ? 'Filtrar fecha'
                          : '${date!.day}/${date!.month} · quitar',
                    ),
                    onPressed: () async {
                      if (date != null) {
                        setState(() => date = null);
                        return;
                      }
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (mounted && d != null) setState(() => date = d);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              if (items.isEmpty)
                const EmptyState(
                  'Sin citas por aquí',
                  'Las citas que coincidan con tus filtros aparecerán aquí.',
                )
              else
                for (final a in items)
                  AppointmentTile(
                    key: ValueKey(a['id']),
                    appointment: a,
                    store: store,
                  ),
            ],
          ),
        ),
        if (store.staff)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Para completar una cita, abre «Escanear QR» y valida la tarjeta del cliente.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
