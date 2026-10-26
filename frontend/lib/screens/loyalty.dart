import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/api.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'booking.dart';

class StampCard extends StatelessWidget {
  final Store store;
  final bool compact;
  const StampCard({super.key, required this.store, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final count = store.card['currentStamps'] as int;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.loyalty_outlined,
                color: Color(0xFFB6D2C4),
                size: 20,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'CLUB BARBERÍA',
                  style: TextStyle(
                    color: Color(0xFFB6D2C4),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Text(
                '$count / 10',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            count == 10
                ? 'Tu próximo corte\nva por nuestra cuenta.'
                : 'Tu lealtad tiene\nsu recompensa.',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 25 : 32,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (_, size) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                10,
                (i) => Container(
                  width: (size.maxWidth - 40) / 5,
                  height: compact ? 40 : 52,
                  decoration: BoxDecoration(
                    color: i < count
                        ? const Color(0xFFD4E8DE)
                        : Colors.white.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      i == 9 ? Icons.card_giftcard : Icons.content_cut,
                      size: 20,
                      color: i < count
                          ? AppColors.accent
                          : const Color(0xFF74858C),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            count == 10
                ? '¡Ya tienes un corte clásico gratis disponible!'
                : 'Te faltan ${10 - count} visitas para tu corte gratis.',
            style: const TextStyle(color: Color(0xFFCFD9DC), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LoyaltyScreen extends StatefulWidget {
  final Store store;
  const LoyaltyScreen({super.key, required this.store});
  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  String? token, error;
  DateTime? expires;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(minutes: 4), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      token = null;
      error = null;
    });
    try {
      final t = await widget.store.qr();
      if (mounted) {
        setState(() {
          token = t;
          expires = DateTime.now().add(const Duration(minutes: 5));
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Mi tarjeta de sellos',
          'Cada visita cuenta. Cada buen corte también.',
        ),
        LayoutBuilder(
          builder: (_, size) {
            final card = Column(
              children: [
                StampCard(store: store),
                const SizedBox(height: 20),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Así de sencillo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '1. Reserva y disfruta tu servicio.\n2. Muestra este QR a tu barbero al terminar.\n3. Acumula 10 sellos y canjea un corte clásico gratis.',
                        style: TextStyle(height: 2, color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Un sello por cita completada. El corte de regalo no genera sello. Al llegar a 10, canjea tu beneficio para seguir acumulando.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      if (store.card['currentStamps'] == 10) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => openBooking(
                            context,
                            store,
                            service: store.services
                                .where((s) => s['rewardEligible'] == true)
                                .firstOrNull,
                          ),
                          child: const Text('Reservar mi corte gratis'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
            final qr = Panel(
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, color: AppColors.accent),
                  const SizedBox(height: 12),
                  Text(
                    'Tu pase personal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Muéstralo al finalizar tu servicio.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  if (token != null)
                    QrImageView(
                      data: token!,
                      size: 235,
                      backgroundColor: Colors.white,
                    )
                  else if (error == null)
                    const SizedBox(
                      height: 235,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  Text(
                    store.user!['name'],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    store.demo
                        ? 'QR de demostración · sin valor comercial'
                        : expires == null
                        ? 'Preparando tu código…'
                        : 'Válido hasta ${expires!.hour.toString().padLeft(2, '0')}:${expires!.minute.toString().padLeft(2, '0')} · se renueva automáticamente',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar QR'),
                  ),
                ],
              ),
            );
            return size.maxWidth > 780
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: card),
                      const SizedBox(width: 24),
                      Expanded(child: qr),
                    ],
                  )
                : Column(children: [card, const SizedBox(height: 24), qr]);
          },
        ),
        const SizedBox(height: 28),
        const SectionTitle(
          'Últimos movimientos',
          'El registro de tus recompensas.',
        ),
        Panel(
          child: (store.card['events'] as List).isEmpty
              ? const EmptyState(
                  'Tu historia empieza aquí',
                  'Tus sellos y canjes aparecerán después de cada visita.',
                  icon: Icons.history,
                )
              : Column(
                  children: (store.card['events'] as List)
                      .map(
                        (e) => ListTile(
                          leading: Icon(
                            e['type'] == 'EARNED'
                                ? Icons.add_task
                                : Icons.card_giftcard,
                            color: AppColors.accent,
                          ),
                          title: Text(
                            e['type'] == 'EARNED'
                                ? 'Visita completada · +1 sello'
                                : 'Corte gratis canjeado',
                          ),
                          trailing: Text(dayLabel(e['createdAt'])),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
