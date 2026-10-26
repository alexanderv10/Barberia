// Full SMTP flow against a local _test database and local Mailpit. No real delivery.
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
require('reflect-metadata');
const { parse } = require('dotenv');
const { NestFactory } = require('@nestjs/core');
const { PrismaClient } = require('@prisma/client');
let app, db, userId;
try {
  const env = parse(await readFile(new URL('../.env', import.meta.url), 'utf8'));
  const url = new URL('postgresql://barberia@127.0.0.1:5432/barberia_test?schema=public');
  url.password = env.POSTGRES_PASSWORD;
  Object.assign(process.env, { DATABASE_URL: url.toString(), JWT_SECRET: 'local-smtp-test-only-with-more-than-32-characters', CORS_ORIGINS: 'http://localhost:8080', APP_WEB_URL: 'http://localhost:8080', MAIL_MODE: 'local', MAIL_FROM: 'barberia@example.test', SMTP_HOST: '127.0.0.1', SMTP_PORT: '1025' });
  const { AppModule } = require('../backend/dist/src/app.module.js');
  const { configureApp } = require('../backend/dist/src/common/configure-app.js');
  db = new PrismaClient();
  app = await NestFactory.create(AppModule, { logger: false, bodyParser: false });
  configureApp(app);
  await app.listen(0, '127.0.0.1');
  const base = `${await app.getUrl()}/api`;
  const email = `${randomUUID()}@smtp-test.example`;
  const request = async (path, body, jwt) => {
    const response = await fetch(`${base}/${path}`, { method: body ? 'POST' : 'GET', headers: { 'Content-Type': 'application/json', ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
    return { status: response.status, data: await response.json() };
  };
  const link = async action => {
    const listing = await (await fetch('http://127.0.0.1:8025/api/v1/messages')).json();
    const messages = listing.messages.filter(message => message.To.some(to => to.Address === email));
    for (const message of messages) {
      const detail = await (await fetch(`http://127.0.0.1:8025/api/v1/message/${message.ID}`)).json();
      const found = detail.Text.match(new RegExp(`http://localhost:8080/#/account/${action}\\?token=([a-f0-9]{64})`));
      if (found) return found[1];
    }
    throw new Error('MAIL_NOT_RECEIVED');
  };
  const registered = await request('auth/register', { name: 'Prueba SMTP', email, password: 'OriginalSmtpPassword2026!' });
  if (registered.status !== 201 || !registered.data.verificationEmailSent) throw new Error('REGISTRATION_MAIL_FAILED');
  userId = registered.data.user.id;
  const verifyToken = await link('verify');
  if ((await request('auth/email/verify', { token: verifyToken })).status !== 201) throw new Error('VERIFY_FAILED');
  const me = await request('auth/me', undefined, registered.data.accessToken);
  if (!me.data.emailVerified) throw new Error('VERIFY_STATUS_FAILED');
  if ((await request('auth/password/forgot', { email })).status !== 201) throw new Error('FORGOT_FAILED');
  const resetToken = await link('reset');
  if ((await request('auth/password/reset', { token: resetToken, password: 'UpdatedSmtpPassword2026!' })).status !== 201) throw new Error('RESET_FAILED');
  if ((await request('auth/me', undefined, registered.data.accessToken)).status !== 401) throw new Error('REVOCATION_FAILED');
  if ((await request('auth/login', { email, password: 'UpdatedSmtpPassword2026!' })).status !== 201) throw new Error('LOGIN_FAILED');
  console.log(JSON.stringify({ success: true, smtpDelivery: true, verificationLink: true, resetLink: true, sessionsRevoked: true, newPasswordLogin: true }));
} catch (error) {
  const code = error?.code || error?.message;
  console.error(JSON.stringify({ success: false, code: typeof code === 'string' && /^[A-Z0-9_]+$/.test(code) ? code : 'SMTP_FLOW_FAILED' }));
  process.exitCode = 1;
} finally {
  if (userId && db) {
    await db.loyaltyCard.deleteMany({ where: { clientId: userId } });
    await db.user.delete({ where: { id: userId } });
  }
  await app?.close(); await db?.$disconnect();
}
