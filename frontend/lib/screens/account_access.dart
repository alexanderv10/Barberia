import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AccountAccessScreen extends StatefulWidget {
  final Store store;
  final String action;
  final String? token;
  final VoidCallback? onDone;
  const AccountAccessScreen({
    super.key,
    required this.store,
    required this.action,
    this.token,
    this.onDone,
  });
  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class _AccountAccessScreenState extends State<AccountAccessScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, complete = false, obscure = true;
  String? error, message;
  bool get reset => widget.action == 'reset';
  bool get verify => widget.action == 'verify';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  void done() {
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.store.api.request(
        verify
            ? 'auth/email/verify'
            : reset
            ? 'auth/password/reset'
            : 'auth/password/forgot',
        method: 'POST',
        body: verify
            ? {'token': widget.token ?? ''}
            : reset
            ? {'token': widget.token ?? '', 'password': password.text}
            : {'email': email.text.trim()},
      );
      if (reset) widget.store.logout();
      if (verify && widget.store.user != null) {
        try {
          await widget.store.refreshIdentity();
        } catch (_) {
          /* Verification already succeeded. Refresh can be retried in My account. */
        }
      }
      if (mounted) {
        setState(() {
          message = result['message'];
          complete = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tu cuenta'),
      leading: IconButton(
        onPressed: busy ? null : done,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Brand(),
                const SizedBox(height: 32),
                Icon(
                  complete
                      ? Icons.check_circle_outline
                      : verify
                      ? Icons.mark_email_read_outlined
                      : Icons.lock_reset,
                  size: 52,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 22),
                Text(
                  complete
                      ? 'Todo listo'
                      : verify
                      ? 'Verifica tu correo'
                      : reset
                      ? 'Elige una nueva contraseña'
                      : 'Recupera tu cuenta',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  message ??
                      (verify
                          ? 'Confirma tu correo para asociarlo a tu cuenta de la barbería.'
                          : reset
                          ? 'Usa una contraseña de al menos 10 caracteres. Al guardarla, se cerrarán tus sesiones anteriores.'
                          : 'Ingresa el correo de tu cuenta y te enviaremos un enlace para cambiar tu contraseña.'),
                ),
                const SizedBox(height: 24),
                if (!complete && !verify && !reset)
                  TextFormField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Ingresa un correo válido.',
                  ),
                if (!complete && reset) ...[
                  TextFormField(
                    controller: password,
                    enabled: !busy,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      helperText: 'Mínimo 10 caracteres; máximo 72 bytes.',
                      suffixIcon: IconButton(
                        tooltip: 'Mostrar u ocultar contraseña',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) < 10 ||
                            utf8.encode(v ?? '').length > 72
                        ? 'Usa al menos 10 caracteres y hasta 72 bytes.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmation,
                    enabled: !busy,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirma la nueva contraseña',
                    ),
                    validator: (v) => v == password.text
                        ? null
                        : 'Las contraseñas no coinciden.',
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 18),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy
                      ? null
                      : complete
                      ? done
                      : submit,
                  child: Text(
                    busy
                        ? 'Procesando…'
                        : complete
                        ? 'Volver al inicio'
                        : verify
                        ? 'Verificar mi correo'
                        : reset
                        ? 'Guardar nueva contraseña'
                        : 'Enviar enlace',
                  ),
                ),
                if (!complete && (reset || verify))
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AccountAccessScreen(
                                  store: widget.store,
                                  action: 'forgot',
                                ),
                              ),
                            );
                          },
                    child: const Text('¿Necesitas recuperar el acceso?'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class EmailVerificationPanel extends StatefulWidget {
  final Store store;
  const EmailVerificationPanel({super.key, required this.store});
  @override
  State<EmailVerificationPanel> createState() => _EmailVerificationPanelState();
}

class _EmailVerificationPanelState extends State<EmailVerificationPanel> {
  bool busy = false;
  String? message;
  Future<void> run(bool resend) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (resend) {
        final result = await widget.store.api.request(
          'auth/email/resend',
          method: 'POST',
        );
        if (mounted) setState(() => message = result['message']);
      } else {
        await widget.store.refreshIdentity();
      }
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.store.user?['emailVerified'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        Text(
          verified ? 'Correo verificado' : 'Correo pendiente de verificación',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (!verified) ...[
          const SizedBox(height: 8),
          const Text(
            'Confirma tu dirección con el enlace que te enviamos. Si no llegó, revisa spam o solicita otro.',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy ? null : () => run(true),
                child: Text(
                  busy ? 'Procesando…' : 'Enviar enlace de verificación',
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => run(false),
                child: const Text('Ya verifiqué mi correo'),
              ),
            ],
          ),
        ],
        if (message != null) Text(message!),
      ],
    );
  }
}
