import 'reflect-metadata';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AccountMailService } from '../../src/auth/account-mail.service';
import { AccountTokensService } from '../../src/auth/account-tokens.service';
import { configureApp } from '../../src/common/configure-app';

test('correo de cuenta: propósito, caducidad, concurrencia y revocación de sesiones', async t => {
  if (!process.env.TEST_DATABASE_URL || !new URL(process.env.TEST_DATABASE_URL).pathname.endsWith('_test')) throw new Error('Se requiere una base aislada _test.');
  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
  process.env.JWT_SECRET = 'integration-account-only-secret-more-than-32-characters';
  process.env.CORS_ORIGINS = 'http://localhost:8080';
  const { AppModule } = await import('../../src/app.module');
  const db = new PrismaClient();
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { logger: false, bodyParser: false });
  const delivered: { purpose: string; token: string }[] = [];
  app.get(AccountMailService).send = async (_to, purpose, token) => { delivered.push({ purpose, token }); };
  configureApp(app);
  await app.listen(0, '127.0.0.1');
  const base = `${await app.getUrl()}/api`;
  const email = `${randomUUID()}@account.test`;
  let userId = '', access = '';
  const request = async (path: string, body?: unknown, jwt?: string) => {
    const response = await fetch(`${base}/${path}`, { method: body === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}) }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    return { status: response.status, data: await response.json() as any };
  };
  const digest = (raw: string) => createHash('sha256').update(raw).digest('hex');
  const token = async (purpose: 'VERIFY_EMAIL' | 'RESET_PASSWORD', expiresAt = new Date(Date.now() + 60000)) => {
    const raw = randomBytes(32).toString('hex');
    await db.accountToken.create({ data: { userId, purpose, tokenHash: digest(raw), expiresAt } });
    return raw;
  };
  try {
    await t.test('registro envía verificación y guarda solo hash', async () => {
      const registered = await request('auth/register', { name: 'Cuenta Prueba', email, password: 'OriginalPassword2026!' });
      assert.equal(registered.status, 201);
      userId = registered.data.user.id; access = registered.data.accessToken;
      assert.equal(registered.data.user.emailVerified, false);
      assert.equal(registered.data.verificationEmailSent, true);
      assert.equal(delivered.length, 1);
      assert.equal(delivered[0].purpose, 'VERIFY_EMAIL');
      const stored = await db.accountToken.findFirstOrThrow({ where: { userId } });
      assert.equal(stored.tokenHash, digest(delivered[0].token));
      assert(!JSON.stringify(registered.data).includes(delivered[0].token));
      assert(stored.expiresAt.getTime() > Date.now() + 23 * 3600000);
    });
    await t.test('reenviar respeta cooldown sin invalidar el enlace enviado', async () => {
      const result = await request('auth/email/resend', {}, access);
      assert.equal(result.status, 201); assert.equal(result.data.sent, false);
      assert.equal(delivered.length, 1);
      assert.equal((await db.accountToken.findFirstOrThrow({ where: { userId } })).usedAt, null);
    });
    await t.test('rechaza propósito incorrecto, enlaces vencidos y entradas extra', async () => {
      assert.equal((await request('auth/password/reset', { token: delivered[0].token, password: 'ChangedPassword2026!' })).status, 400);
      const expired = await token('VERIFY_EMAIL', new Date(Date.now() - 1000));
      assert.equal((await request('auth/email/verify', { token: expired })).status, 400);
      assert.equal((await request('auth/email/verify', { token: delivered[0].token, userId })).status, 400);
    });
    await t.test('un enlace de verificación solo se consume una vez incluso en paralelo', async () => {
      const result = await Promise.all([request('auth/email/verify', { token: delivered[0].token }), request('auth/email/verify', { token: delivered[0].token })]);
      assert.deepEqual(result.map(r => r.status).sort(), [201, 400]);
      assert.equal((await request('auth/me', undefined, access)).data.emailVerified, true);
    });
    await t.test('el límite de cinco correos por hora no se elude esperando el cooldown', async () => {
      await db.accountToken.createMany({ data: Array.from({ length: 5 }, () => ({
        userId, purpose: 'RESET_PASSWORD' as const, tokenHash: digest(randomBytes(32).toString('hex')),
        createdAt: new Date(Date.now() - 120000), expiresAt: new Date(Date.now() + 60000), usedAt: new Date(),
      })) });
      const before = delivered.length;
      assert.equal(await app.get(AccountTokensService).issue(userId, 'RESET_PASSWORD'), false);
      assert.equal(delivered.length, before);
      await db.accountToken.deleteMany({ where: { userId, purpose: 'RESET_PASSWORD' } });
    });
    await t.test('recuperación responde igual para cuentas existentes y ausentes; limita correos por cuenta', async () => {
      const unknown = await request('auth/password/forgot', { email: `${randomUUID()}@missing.test` });
      const known = await request('auth/password/forgot', { email });
      assert.equal(known.status, 201); assert.deepEqual(known, unknown);
      assert.equal(delivered.at(-1)!.purpose, 'RESET_PASSWORD');
      const before = delivered.length;
      assert.equal((await request('auth/password/forgot', { email })).status, 201);
      assert.equal(delivered.length, before);
    });
    await t.test('reset concurrente: un ganador, nueva clave y sesiones antiguas revocadas', async () => {
      const raw = delivered.at(-1)!.token;
      const password = 'ChangedPassword2026!';
      const result = await Promise.all([request('auth/password/reset', { token: raw, password }), request('auth/password/reset', { token: raw, password })]);
      assert.deepEqual(result.map(r => r.status).sort(), [201, 400]);
      assert.equal((await request('auth/me', undefined, access)).status, 401);
      assert.equal((await request('auth/login', { email, password: 'OriginalPassword2026!' })).status, 401);
      const login = await request('auth/login', { email, password });
      assert.equal(login.status, 201);
      assert.equal((await request('auth/me', undefined, login.data.accessToken)).status, 200);
      assert.equal((await db.user.findUniqueOrThrow({ where: { id: userId } })).sessionVersion, 1);
      assert.equal(await db.accountToken.count({ where: { userId, usedAt: null } }), 0);
    });
    await t.test('reset inválido o vencido no cambia la contraseña y rechaza más de 72 bytes', async () => {
      const expired = await token('RESET_PASSWORD', new Date(Date.now() - 1000));
      assert.equal((await request('auth/password/reset', { token: expired, password: 'AnotherPassword2026!' })).status, 400);
      const valid = await token('RESET_PASSWORD');
      assert.equal((await request('auth/password/reset', { token: valid, password: 'é'.repeat(40) })).status, 400);
      assert.equal((await db.user.findUniqueOrThrow({ where: { id: userId } })).sessionVersion, 1);
    });
    await t.test('fallo de envío no revela la cuenta ni conserva un enlace inutilizable', async () => {
      await db.accountToken.deleteMany({ where: { userId, purpose: 'RESET_PASSWORD' } });
      app.get(AccountMailService).send = async () => { throw new Error('SIMULATED_SMTP_FAILURE'); };
      const result = await request('auth/password/forgot', { email });
      assert.equal(result.status, 201);
      assert.equal(await db.accountToken.count({ where: { userId, purpose: 'RESET_PASSWORD' } }), 0);
    });
  } finally {
    if (userId) {
      await db.loyaltyCard.deleteMany({ where: { clientId: userId } });
      await db.user.delete({ where: { id: userId } });
    }
    await app.close(); await db.$disconnect();
  }
});
