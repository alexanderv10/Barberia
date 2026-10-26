import { Injectable, Logger } from '@nestjs/common';
import nodemailer, { Transporter } from 'nodemailer';
import { isEmail } from 'class-validator';

export function accountWebUrl(): URL {
  const url = new URL(process.env.APP_WEB_URL || 'http://localhost:8080');
  const local = ['localhost', '127.0.0.1'].includes(url.hostname);
  if (url.username || url.password || url.search || url.hash ||
      (url.protocol !== 'https:' && !(local && url.protocol === 'http:'))) {
    throw new Error('APP_WEB_URL debe ser HTTPS (HTTP solo para localhost), sin credenciales, consulta ni fragmento.');
  }
  return url;
}

@Injectable()
export class AccountMailService {
  private readonly logger = new Logger(AccountMailService.name);
  private transport?: Transporter;

  async send(to: string, purpose: 'VERIFY_EMAIL' | 'RESET_PASSWORD', token: string) {
    const mode = process.env.MAIL_MODE || 'disabled';
    if (!['smtp', 'local'].includes(mode)) throw new Error('MAIL_NOT_CONFIGURED');
    const host = process.env.SMTP_HOST || '';
    const port = Number(process.env.SMTP_PORT || (mode === 'local' ? 1025 : 587));
    const from = process.env.MAIL_FROM || (mode === 'local' ? 'barberia@example.test' : '');
    if (!isEmail(from) || !Number.isInteger(port) || port < 1 || port > 65535) throw new Error('MAIL_CONFIGURATION_INVALID');
    const local = ['127.0.0.1', 'localhost', 'mailpit'].includes(host);
    if (mode === 'local' && !local) throw new Error('LOCAL_MAIL_HOST_INVALID');
    if (mode === 'smtp' && (!host || !process.env.SMTP_USER || !process.env.SMTP_PASSWORD)) throw new Error('SMTP_CREDENTIALS_MISSING');
    if (!this.transport) {
      this.transport = nodemailer.createTransport({
        host, port, secure: mode === 'smtp' && port === 465,
        requireTLS: mode === 'smtp' && port !== 465,
        ...(mode === 'smtp' ? { auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASSWORD } } : {}),
        tls: { rejectUnauthorized: true, minVersion: 'TLSv1.2' },
        connectionTimeout: 5000, greetingTimeout: 5000, socketTimeout: 10000,
        disableFileAccess: true, disableUrlAccess: true,
      });
    }
    const verify = purpose === 'VERIFY_EMAIL';
    const url = accountWebUrl();
    url.hash = `/account/${verify ? 'verify' : 'reset'}?token=${token}`;
    const action = verify ? 'Verifica tu correo electrónico' : 'Restablece tu contraseña';
    const duration = verify ? '24 horas' : '30 minutos';
    // Plain text avoids HTML injection and loading tracking resources in email clients.
    await this.transport.sendMail({
      from: { name: 'Barbería', address: from }, to, subject: `${action} · Barbería`,
      text: `${action}\n\nAbre este enlace para continuar:\n${url.toString()}\n\nEl enlace vence en ${duration} y solo se puede usar una vez.\nSi no solicitaste este mensaje, puedes ignorarlo.`,
    });
  }

  reportFailure() {
    // Never include transport errors: they can contain SMTP credentials, recipients or action links.
    this.logger.warn('No se pudo enviar un correo de cuenta. Revisa la configuración SMTP y su disponibilidad.');
  }
}
