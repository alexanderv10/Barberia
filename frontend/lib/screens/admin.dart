import 'package:flutter/material.dart';
import '../data/api.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class AdminTools extends StatelessWidget {
  final Store store;
  const AdminTools({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Administración', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ServiceEditor(store: store),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo servicio'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => BarberEditor(store: store),
                ),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Añadir barbero'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final s in store.services)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s['name']),
              subtitle: Text(
                '${money(s['priceCents'])} · ${s['durationMin']} min · ${s['active'] == false ? 'Inactivo' : 'Activo'}',
              ),
              trailing: IconButton(
                tooltip: 'Editar servicio',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ServiceEditor(store: store, service: s),
                ),
              ),
            ),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            'Equipo · ${store.barbers.length} barberos activos',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: store.barbers
                .map(
                  (b) => Chip(
                    avatar: const Icon(Icons.person_outline, size: 17),
                    label: Text(b['name']),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

class ServiceEditor extends StatefulWidget {
  final Store store;
  final Json? service;
  const ServiceEditor({super.key, required this.store, this.service});
  @override
  State<ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<ServiceEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, description, duration, price;
  late bool eligible, active;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final s = widget.service;
    name = TextEditingController(text: s?['name']);
    description = TextEditingController(text: s?['description']);
    duration = TextEditingController(text: '${s?['durationMin'] ?? 30}');
    price = TextEditingController(
      text: ((s?['priceCents'] ?? 0) / 100).toStringAsFixed(2),
    );
    eligible = s?['rewardEligible'] ?? false;
    active = s?['active'] ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    duration.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveService({
        'name': name.text.trim(),
        'description': description.text.trim(),
        'durationMin': int.parse(duration.text),
        'priceCents': (double.parse(price.text.replaceAll(',', '.')) * 100)
            .round(),
        'rewardEligible': eligible,
        'active': active,
      }, id: widget.service?['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.service == null ? 'Nuevo servicio' : 'Editar servicio'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Ingresa un nombre.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duración en minutos',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 15 || n > 240
                      ? 'Usa entre 15 y 240 minutos.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Precio en USD'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return n == null || !n.isFinite || n < 0 || n > 10000
                      ? 'Precio inválido.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Elegible como corte gratis'),
                value: eligible,
                onChanged: busy ? null : (v) => setState(() => eligible = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible para reservas'),
                value: active,
                onChanged: busy ? null : (v) => setState(() => active = v),
              ),
              const Text(
                'Los cambios no modifican horarios ni precios de citas ya reservadas.',
                style: TextStyle(fontSize: 11),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
}

class BarberEditor extends StatefulWidget {
  final Store store;
  const BarberEditor({super.key, required this.store});
  @override
  State<BarberEditor> createState() => _BarberEditorState();
}

class _BarberEditorState extends State<BarberEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.createBarber({
        'name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Añadir barbero'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v?.trim().length ?? 0) < 2 ? 'Ingresa el nombre.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
              validator: (v) =>
                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                  ? 'Correo inválido.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña de acceso',
              ),
              validator: (v) => (v?.length ?? 0) < 10 || v!.length > 72
                  ? 'Entre 10 y 72 caracteres.'
                  : null,
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Creando…' : 'Crear barbero'),
      ),
    ],
  );
}
