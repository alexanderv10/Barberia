import 'package:flutter/material.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_access.dart';

class LoginScreen extends StatefulWidget {
  final Store store;
  const LoginScreen({super.key, required this.store});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool register = false, busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.login(
        email.text,
        password.text,
        name: register ? name.text : null,
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, size) => Row(
        children: [
          if (size.maxWidth > 900)
            Expanded(
              child: Container(
                color: AppColors.ink,
                padding: const EdgeInsets.all(60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Brand(light: true),
                    const Spacer(),
                    const Icon(
                      Icons.content_cut,
                      color: Color(0xFFABC8BD),
                      size: 95,
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Un buen corte.\nUna buena costumbre.',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.12,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Reserva tu momento. Encuentra tu estilo.\nCada visita te acerca a tu próximo corte gratis.',
                      style: TextStyle(
                        color: Color(0xFFB4C1C5),
                        fontSize: 17,
                        height: 1.7,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'TU ESTILO, EN BUENAS MANOS.',
                      style: TextStyle(
                        color: Color(0xFFB4C1C5),
                        letterSpacing: 3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: busy ? null : widget.store.cancelLogin,
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Volver a la barbería'),
                        ),
                        const SizedBox(height: 20),
                        if (size.maxWidth <= 900) ...[
                          const Brand(),
                          const SizedBox(height: 44),
                        ],
                        const Text(
                          'BIENVENIDO A TU BARBERÍA',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          register
                              ? 'Tu próximo look\nempieza aquí.'
                              : 'Qué bueno\nverte de nuevo.',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(fontSize: 39),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          register
                              ? 'Crea tu cuenta para reservar y comenzar a sumar sellos.'
                              : widget.store.pendingReservation
                              ? 'Inicia sesión o crea tu cuenta para continuar con tu reserva.'
                              : 'Ingresa para reservar tu cita y ver tus beneficios.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 30),
                        if (register) ...[
                          TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                            ),
                            validator: (v) => (v?.trim().length ?? 0) < 2
                                ? 'Ingresa tu nombre.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) =>
                              v == null ||
                                  !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v.trim())
                              ? 'Ingresa un correo válido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          obscureText: obscure,
                          autofillHints: [
                            register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            helperText: register
                                ? 'Entre 10 y 72 caracteres.'
                                : null,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: 'Mostrar u ocultar contraseña',
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v?.length ?? 0) < 10 || v!.length > 72
                              ? 'Usa entre 10 y 72 caracteres.'
                              : null,
                          onFieldSubmitted: (_) => busy ? null : submit(),
                        ),
                        if (!register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AccountAccessScreen(
                                          store: widget.store,
                                          action: 'forgot',
                                        ),
                                      ),
                                    ),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: busy ? null : submit,
                            child: Text(
                              busy
                                  ? 'Conectando…'
                                  : register
                                  ? 'Crear mi cuenta'
                                  : 'Iniciar sesión',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    register = !register;
                                    error = null;
                                  }),
                            child: Text(
                              register
                                  ? 'Ya tengo cuenta · Iniciar sesión'
                                  : '¿Primera visita? Crea tu cuenta',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 14),
                        const Text(
                          'EXPLORA LA EXPERIENCIA',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => widget.store.enterDemo(),
                              child: const Text('Demo cliente'),
                            ),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => widget.store.enterDemo(asStaff: true),
                              child: const Text('Demo barbero'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'La demostración usa datos de ejemplo y no crea reservas reales.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
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
