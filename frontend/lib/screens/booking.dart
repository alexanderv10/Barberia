import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> openBooking(BuildContext context, Store store, {Json? service}) =>
    showDialog(
      context: context,
      builder: (_) => BookingDialog(store: store, initial: service),
    );

class BookingDialog extends StatefulWidget {
  final Store store;
  final Json? initial;
  const BookingDialog({super.key, required this.store, this.initial});
  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  Json? service, barber;
  late DateTime date;
  List<String> slots = [];
  String? selected, error;
  bool loading = false, saving = false, reward = false;
  int requestId = 0;
  @override
  void initState() {
    super.initState();
    date = shopDate(DateTime.now().toUtc().toIso8601String());
    service = widget.initial ?? widget.store.services.firstOrNull;
    barber = widget.store.barbers.firstOrNull;
    loadSlots();
  }

  Future<void> loadSlots() async {
    if (service == null || barber == null) return;
    final id = ++requestId;
    setState(() {
      loading = true;
      selected = null;
      error = null;
      slots = [];
    });
    try {
      final result = await widget.store.slots(
        barber!['id'],
        service!['id'],
        date,
      );
      if (mounted && id == requestId) setState(() => slots = result);
    } catch (e) {
      if (mounted && id == requestId) setState(() => error = e.toString());
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.book(service!, barber!, selected!, reward);
      if (mounted) {
        toast(
          context,
          widget.store.demo
              ? 'Reserva de demostración guardada.'
              : '¡Tu cita está reservada!',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        await loadSlots();
        if (mounted) setState(() => error = e.toString());
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Expanded(child: Text('Reserva tu momento')),
        IconButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
        ),
      ],
    ),
    content: SizedBox(
      width: 490,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '1. ELIGE TU SERVICIO',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: service?['id'],
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Servicio'),
              items: widget.store.services
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id'],
                      child: Text('${s['name']} · ${money(s['priceCents'])}'),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (id) {
                      service = widget.store.services.firstWhere(
                        (s) => s['id'] == id,
                      );
                      reward = false;
                      loadSlots();
                    },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: barber?['id'],
              decoration: const InputDecoration(labelText: 'Tu barbero'),
              items: widget.store.barbers
                  .map(
                    (b) => DropdownMenuItem<String>(
                      value: b['id'],
                      child: Text(b['name']),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (id) {
                      barber = widget.store.barbers.firstWhere(
                        (b) => b['id'] == id,
                      );
                      loadSlots();
                    },
            ),
            const SizedBox(height: 24),
            const Text(
              '2. ENCUENTRA TU HORARIO',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final now = shopDate(
                        DateTime.now().toUtc().toIso8601String(),
                      );
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: now.add(const Duration(days: 60)),
                      );
                      if (chosen != null) {
                        date = chosen;
                        await loadSlots();
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${date.day}/${date.month}/${date.year}'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hora de la barbería · Ecuador (UTC−5)',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (slots.isEmpty)
              const Text(
                'No hay horarios disponibles. Prueba otra fecha o barbero.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots
                    .map(
                      (s) => ChoiceChip(
                        label: Text(timeLabel(s)),
                        selected: selected == s,
                        onSelected: saving
                            ? null
                            : (_) => setState(() => selected = s),
                      ),
                    )
                    .toList(),
              ),
            if (widget.store.card['currentStamps'] == 10 &&
                service?['rewardEligible'] == true) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar mi corte gratis'),
                subtitle: const Text(
                  'Los 10 sellos se canjean al finalizar el servicio.',
                ),
                value: reward,
                onChanged: saving
                    ? null
                    : (v) => setState(() => reward = v ?? false),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    service == null
                        ? 'Selecciona un servicio'
                        : '${service!['durationMin']} min · ${reward ? 'Gratis' : money(service!['priceCents'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton(
                  onPressed: selected == null || saving || loading
                      ? null
                      : save,
                  child: Text(saving ? 'Reservando…' : 'Confirmar cita'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
