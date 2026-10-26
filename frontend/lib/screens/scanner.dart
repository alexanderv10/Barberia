import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/api.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ScannerScreen extends StatefulWidget {
  final Store store;
  const ScannerScreen({super.key, required this.store});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final input = TextEditingController();
  MobileScannerController? camera;
  bool busy = false;
  Json? result;
  String? error, scanned;
  @override
  void dispose() {
    input.dispose();
    camera?.dispose();
    super.dispose();
  }

  Future<void> scan(String token) async {
    if (busy || token.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final r = await widget.store.scan(token);
      if (mounted) {
        await camera?.stop();
        if (mounted) {
          setState(() {
            result = r;
            scanned = token;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> complete(Json a) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          a['isReward'] == true ? 'Canjear corte gratis' : 'Completar servicio',
        ),
        content: Text(
          '¿Confirmas que ${a['service']['name']} ha finalizado? Esta acción registra la visita y actualiza la tarjeta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.complete(scanned!, a['id']);
      if (mounted) {
        toast(context, 'Servicio completado. Tarjeta actualizada.');
        setState(() => result = null);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Una visita, un sello',
        'Escanea la tarjeta del cliente para finalizar su servicio.',
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (camera == null)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Icon(
                      Icons.qr_code_scanner,
                      size: 100,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () =>
                          setState(() => camera = MobileScannerController()),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Activar cámara'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Permite el acceso a la cámara. En web se requiere HTTPS o localhost.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 290,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MobileScanner(
                    controller: camera,
                    onDetect: (capture) {
                      if (result == null && !busy) {
                        final token = capture.barcodes.firstOrNull?.rawValue;
                        if (token != null) scan(token);
                      }
                    },
                    errorBuilder: (context, error) => const Center(
                      child: Text(
                        'No se pudo acceder a la cámara. Revisa los permisos o ingresa el código.',
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => camera?.start(),
                child: const Text('Reactivar cámara'),
              ),
            ],
            const Divider(),
            const SizedBox(height: 18),
            const Text(
              'También puedes pegar el contenido del QR',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: input,
              decoration: const InputDecoration(
                hintText: 'Código de la tarjeta',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => scan(input.text.trim()),
                  child: Text(busy ? 'Validando…' : 'Validar código'),
                ),
                if (widget.store.demo)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            input.text = 'BARBERIA-DEMO-SIN-VALOR';
                            scan(input.text);
                          },
                    child: const Text('Usar QR de ejemplo'),
                  ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      if (result != null) ...[
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result!['client']['name'],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${result!['currentStamps']} / 10 sellos',
                style: const TextStyle(color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              if ((result!['appointments'] as List).isEmpty)
                const EmptyState(
                  'Sin servicios para completar',
                  'El cliente necesita una cita pendiente que ya haya comenzado.',
                )
              else
                for (final a in result!['appointments'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${a['service']['name']} · ${dayLabel(a['startsAt'])} ${timeLabel(a['startsAt'])}',
                        ),
                        FilledButton(
                          onPressed: busy ? null : () => complete(Json.from(a)),
                          child: Text(
                            a['isReward'] == true
                                ? 'Canjear y completar'
                                : 'Completar servicio',
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    ],
  );
}
