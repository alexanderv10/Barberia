import 'reflect-metadata';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { configureApp } from '../../src/common/configure-app';
import { DateTime } from 'luxon';

test('API y concurrencia contra PostgreSQL real', async t => {
  if (!process.env.TEST_DATABASE_URL || !new URL(process.env.TEST_DATABASE_URL).pathname.endsWith('_test')) throw new Error('Usa TEST_DATABASE_URL con una base terminada en _test.');
  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
  process.env.JWT_SECRET = 'integration-only-secret-with-more-than-32-characters';
  process.env.CORS_ORIGINS = 'http://localhost:8080';
  const { AppModule } = await import('../../src/app.module');
  const db = new PrismaClient();
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { logger: ['error'], bodyParser: false });
  configureApp(app);
  await app.listen(0, '127.0.0.1');
  const base = `${await app.getUrl()}/api`;
  const runId = randomUUID();
  const ids: string[] = [];
  let serviceId = '';
  const request = async (path: string, token?: string, body?: unknown, method = body ? 'POST' : 'GET') => {
    const res = await fetch(`${base}/${path}`, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
    return { status: res.status, data: await res.json() as any };
  };
  try {
    const register = await request('auth/register', undefined, { name: 'Integration Client', email: `${runId}@test.local`, password: 'Integration2026!' });
    assert.equal(register.status, 201);
    ids.push(register.data.user.id);
    const client = register.data.accessToken;
    const userId = register.data.user.id;
    const barber = await db.user.create({ data: { name: 'Test Barber', email: `${runId}-barber@test.local`, role: 'BARBER', passwordHash: 'not-a-login-hash' } });
    const outsider = await db.user.create({ data: { name: 'Other Barber', email: `${runId}-other@test.local`, role: 'BARBER', passwordHash: 'not-a-login-hash' } });
    ids.push(barber.id, outsider.id);
    const { JwtService } = await import('@nestjs/jwt');
    const jwt = app.get(JwtService);
    const barberToken = jwt.sign({ sub: barber.id, type: 'access' });
    const otherToken = jwt.sign({ sub: outsider.id, type: 'access' });
    const admin = await db.user.create({ data: { name: 'Test Admin', email: `${runId}-admin@test.local`, role: 'ADMIN', passwordHash: 'not-a-login-hash' } });
    ids.push(admin.id);
    const adminToken = jwt.sign({ sub: admin.id, type: 'access' });
    const service = await db.service.create({ data: { name: 'Test cut', description: 'test', durationMin: 30, priceCents: 1200, rewardEligible: true } });
    serviceId = service.id;
    let day = DateTime.now().setZone('America/Guayaquil').plus({ days: 1 }).startOf('day');
    if (day.weekday === 7) day = day.plus({ days: 1 });
    const body = { barberId: barber.id, serviceId, startsAt: day.set({ hour: 10 }).toUTC().toISO() };

    await t.test('inicio público muestra catálogo y equipo sin exponer datos personales', async () => {
      assert.equal((await request('shop')).status, 200);
      const catalog = await request('services');
      assert.equal(catalog.status, 200);
      assert(catalog.data.every((s: any) => s.active === true));
      const team = await request('users/barbers');
      assert.equal(team.status, 200);
      assert(team.data.some((b: any) => b.id === barber.id));
      assert(team.data.every((b: any) => Object.keys(b).sort().join(',') === 'id,name'));
      for (const route of ['appointments', 'stamps/card', 'stamps/qr', 'auth/me', 'services/manage']) assert.equal((await request(route)).status, 401);
      assert.equal((await request('appointments', undefined, body)).status, 401);
    });

    await t.test('requiere JWT y rechaza escalamiento de rol', async () => {
      assert.equal((await request('appointments')).status, 401);
      assert.equal((await request('auth/register', undefined, { name: 'Bad', email: 'bad@test.local', password: 'Integration2026!', role: 'ADMIN' })).status, 400);
      assert.equal((await request('services', client, { ...service, id: undefined })).status, 403);
    });
    await t.test('CORS acepta solo orígenes configurados y conserva acceso nativo sin Origin', async () => {
      const allowed = await fetch(`${base}/shop`, { headers: { Origin: 'http://localhost:8080' } });
      assert.equal(allowed.status, 200);
      assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:8080');
      assert.equal(allowed.headers.get('x-content-type-options'), 'nosniff');
      const denied = await fetch(`${base}/shop`, { headers: { Origin: 'https://untrusted.example' } });
      assert.equal(denied.status, 403);
      assert.equal(denied.headers.get('access-control-allow-origin'), null);
      const preflight = await fetch(`${base}/auth/login`, { method: 'OPTIONS', headers: { Origin: 'http://localhost:8080', 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type' } });
      assert.equal(preflight.status, 204);
      assert.equal((await request('auth/me', client)).status, 200);
    });
    await t.test('valida tipos, rechaza HTML y normaliza texto antes de persistir', async () => {
      const dto = { name: "  Corte   O'Connor  ", description: '  Atención para Jose\u0301\r\ncon detalle.  ', durationMin: 30, priceCents: 1200, rewardEligible: true, active: true };
      for (const invalid of [
        { ...dto, name: '<script>alert(1)</script>' },
        { ...dto, description: '<img src=x onerror=alert(1)>' },
        { ...dto, name: 'Nombre\u0000oculto' },
        { ...dto, priceCents: '1200' },
        { ...dto, description: null },
        { ...dto, role: 'ADMIN' },
      ]) assert.equal((await request(`services/${serviceId}`, adminToken, invalid, 'PATCH')).status, 400);
      const updated = await request(`services/${serviceId}`, adminToken, dto, 'PATCH');
      assert.equal(updated.status, 200);
      const saved = await db.service.findUniqueOrThrow({ where: { id: serviceId } });
      assert.equal(saved.name, "Corte O'Connor");
      assert.equal(saved.description, 'Atención para José\ncon detalle.');
      const oversized = await fetch(`${base}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: 'x'.repeat(17000), password: 'Integration2026!' }) });
      assert.equal(oversized.status, 413);
    });
    await t.test('un cliente no lista ni cancela las citas de otro cliente', async () => {
      const secondClient = await db.user.create({ data: { name: 'Another Client', email: `${runId}-private@test.local`, passwordHash: 'not-a-login-hash', card: { create: {} } } });
      ids.push(secondClient.id);
      const foreign = await db.appointment.create({ data: { clientId: secondClient.id, barberId: outsider.id, serviceId, startsAt: day.set({ hour: 9 }).toJSDate(), endsAt: day.set({ hour: 9, minute: 30 }).toJSDate(), priceCents: 1200 } });
      const listed = await request('appointments', client);
      assert(!listed.data.some((a: any) => a.id === foreign.id));
      assert.equal((await request(`appointments/${foreign.id}/cancel`, client, undefined, 'PATCH')).status, 403);
      const privateCard = await request('stamps/card', client);
      assert.equal(privateCard.data.clientId, userId);
      assert.notEqual(privateCard.data.clientId, secondClient.id);
    });
    await t.test('dos reservas simultáneas: solo una gana', async () => {
      for (const hour of [10, 11, 14, 15, 16]) {
        const candidate = { ...body, startsAt: day.set({ hour }).toUTC().toISO() };
        const result = await Promise.all([request('appointments', client, candidate), request('appointments', client, candidate)]);
        assert.deepEqual(result.map(r => r.status).sort(), [201, 409]);
      }
    });
    await t.test('solo el barbero asignado o administrador acepta la cita', async () => {
      const a = await db.appointment.findFirstOrThrow({ where: { clientId: userId, startsAt: new Date(body.startsAt!) } });
      assert.equal((await request(`appointments/${a.id}/accept`, client, undefined, 'PATCH')).status, 403);
      assert.equal((await request(`appointments/${a.id}/accept`, otherToken, undefined, 'PATCH')).status, 403);
      assert.equal((await request(`appointments/${a.id}/accept`, barberToken, undefined, 'PATCH')).status, 200);
      assert((await db.appointment.findUniqueOrThrow({ where: { id: a.id } })).acceptedAt);
    });
    await t.test('administración de catálogo y equipo requiere ADMIN', async () => {
      assert.equal((await request('services/manage', client)).status, 403);
      assert.equal((await request('services/manage', adminToken)).status, 200);
      const member = { name: 'New Barber', email: `${runId}-new@test.local`, password: 'Integration2026!' };
      assert.equal((await request('users/barbers', barberToken, member)).status, 403);
      const created = await request('users/barbers', adminToken, member);
      assert.equal(created.status, 201);
      ids.push(created.data.id);
      assert.equal(created.data.passwordHash, undefined);
      assert.equal(created.data.role, 'BARBER');
      const update = { name: 'Test cut updated', description: 'updated', durationMin: 30, priceCents: 1400, rewardEligible: true, active: true };
      assert.equal((await request(`services/${serviceId}`, barberToken, update, 'PATCH')).status, 403);
      assert.equal((await request(`services/${serviceId}`, adminToken, update, 'PATCH')).status, 200);
    });
    await t.test('respeta duración y permite citas adyacentes', async () => {
      assert.equal((await request('appointments', client, { ...body, startsAt: day.set({ hour: 10, minute: 30 }).toUTC().toISO() })).status, 201);
      assert.equal((await request('appointments', client, { ...body, startsAt: day.set({ hour: 10, minute: 15 }).toUTC().toISO() })).status, 400);
      const free = await request(`appointments/availability?barberId=${barber.id}&serviceId=${serviceId}&date=${day.toISODate()}`, client);
      assert.equal(free.status, 200);
      assert(!free.data.slots.includes(body.startsAt));
    });
    await t.test('PostgreSQL impide traslapes incluso fuera de la API', async () => {
      await assert.rejects(() => db.appointment.create({ data: { clientId: userId, barberId: barber.id, serviceId, startsAt: day.set({ hour: 10 }).toJSDate(), endsAt: day.set({ hour: 11 }).toJSDate(), priceCents: 1200 } }));
    });
    const qr = (await request('stamps/qr', client)).data.qrToken;
    const past = await db.appointment.create({ data: { clientId: userId, barberId: barber.id, serviceId, startsAt: new Date(Date.now() - 7200000), endsAt: new Date(Date.now() - 5400000), priceCents: 1200 } });
    await t.test('rechaza QR expirado, token de sesión y barbero ajeno', async () => {
      assert.equal((await request('stamps/scan', barberToken, { qrToken: client })).status, 400);
      assert.equal((await request('stamps/scan', barberToken, { qrToken: jwt.sign({ sub: userId, type: 'loyalty' }, { expiresIn: -1 }) })).status, 400);
      assert.equal((await request('stamps/complete', otherToken, { qrToken: qr, appointmentId: past.id })).status, 403);
      assert.equal((await request('stamps/complete', client, { qrToken: qr, appointmentId: past.id })).status, 403);
      assert.equal((await request('stamps/scan', otherToken, { qrToken: qr })).status, 403);
      assert.equal((await request('stamps/scan', barberToken, { qrToken: qr })).status, 201);
    });
    await t.test('completar dos veces en paralelo otorga exactamente un sello', async () => {
      const result = await Promise.all([request('stamps/complete', barberToken, { qrToken: qr, appointmentId: past.id }), request('stamps/complete', barberToken, { qrToken: qr, appointmentId: past.id })]);
      assert.deepEqual(result.map(r => r.status).sort(), [201, 409]);
      assert.equal((await request('stamps/card', client)).data.currentStamps, 1);
      assert.equal(await db.stampEvent.count({ where: { appointmentId: past.id } }), 1);
    });
    await t.test('10 sellos habilitan un solo canje y al completarlo reinician el contador', async () => {
      await db.loyaltyCard.update({ where: { clientId: userId }, data: { currentStamps: 9, lifetimeStamps: 9 } });
      const second = await db.appointment.create({ data: { clientId: userId, barberId: barber.id, serviceId, startsAt: new Date(Date.now() - 14400000), endsAt: new Date(Date.now() - 12600000), priceCents: 1200 } });
      const tenth = await request('stamps/complete', barberToken, { qrToken: qr, appointmentId: second.id });
      assert.equal(tenth.data.currentStamps, 10);
      assert.equal(tenth.data.rewardAvailable, true);
      const reward = await request('appointments', client, { ...body, startsAt: day.set({ hour: 12 }).toUTC().toISO(), isReward: true });
      assert.equal(reward.status, 201);
      assert.equal(reward.data.priceCents, 0);
      assert.equal((await request('appointments', client, { ...body, startsAt: day.set({ hour: 13 }).toUTC().toISO(), isReward: true })).status, 409);
      await db.appointment.update({ where: { id: reward.data.id }, data: { startsAt: new Date(Date.now() - 21600000), endsAt: new Date(Date.now() - 19800000) } });
      const redeemed = await request('stamps/complete', barberToken, { qrToken: qr, appointmentId: reward.data.id });
      assert.equal(redeemed.status, 201);
      assert.equal(redeemed.data.currentStamps, 0);
      assert.equal(redeemed.data.redeemed, true);
      assert.equal(redeemed.data.stampAwarded, false);
    });
    await t.test('cancelar libera horario sin alterar sellos', async () => {
      const appt = await db.appointment.findFirstOrThrow({ where: { clientId: userId, startsAt: new Date(body.startsAt!) } });
      assert.equal((await request(`appointments/${appt.id}/cancel`, client, undefined, 'PATCH')).status, 200);
      assert.equal((await request('appointments', client, body)).status, 201);
      assert.equal((await request('stamps/card', client)).data.currentStamps, 0);
    });
    await t.test('rate limiting limita login y endpoints públicos', async () => {
      const loginStatuses: number[] = [];
      for (let i = 0; i < 11; i++) loginStatuses.push((await request('auth/login', undefined, { email: 'absent@test.local', password: 'Integration2026!' })).status);
      assert.equal(loginStatuses[0], 401);
      assert.equal(loginStatuses.at(-1), 429);
      const statuses: number[] = [];
      for (let i = 0; i < 122; i++) statuses.push((await request('shop')).status);
      assert(statuses.includes(200));
      assert.equal(statuses.at(-1), 429);
      assert.equal((await request('health')).status, 200);
      let healthStatus = 200;
      for (let i = 0; i < 61; i++) healthStatus = (await request('health')).status;
      assert.equal(healthStatus, 429);
    });
  } finally {
    await db.stampEvent.deleteMany({ where: { actorId: { in: ids } } });
    await db.appointment.deleteMany({ where: { clientId: { in: ids } } });
    await db.loyaltyCard.deleteMany({ where: { clientId: { in: ids } } });
    await db.user.deleteMany({ where: { id: { in: ids } } });
    if (serviceId) await db.service.delete({ where: { id: serviceId } });
    await app.close(); await db.$disconnect();
  }
});

