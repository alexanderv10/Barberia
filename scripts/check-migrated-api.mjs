// Read-only API smoke checks (login creates a token but does not change records).
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { parse } = require('dotenv');
try {
  const env = parse(await readFile(new URL('../backend/.env', import.meta.url), 'utf8'));
  if (!env.SEED_PASSWORD) throw new Error('NO_DEMO_PASSWORD');
  const base = 'http://127.0.0.1:3000/api';
  const health = await fetch(`${base}/health`);
  if (!health.ok) throw new Error('HEALTH_FAILED');
  const web = await fetch('http://127.0.0.1:8080/');
  if (!web.ok) throw new Error('WEB_FAILED');
  const roles = [];
  for (const [email, expected] of [['cliente@barberia.local', 'CLIENT'], ['mateo@barberia.local', 'BARBER'], ['admin@barberia.local', 'ADMIN']]) {
    const response = await fetch(`${base}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: env.SEED_PASSWORD }) });
    if (!response.ok) throw new Error(`LOGIN_${expected}_FAILED`);
    const session = await response.json();
    if (session.user?.role !== expected || !session.accessToken) throw new Error('SESSION_FAILED');
    const headers = { Authorization: `Bearer ${session.accessToken}` };
    const identity = await fetch(`${base}/auth/me`, { headers });
    if (!identity.ok || typeof (await identity.json()).emailVerified !== 'boolean') throw new Error('ACCOUNT_EMAIL_SCHEMA_FAILED');
    const appointments = await fetch(`${base}/appointments`, { headers });
    if (!appointments.ok) throw new Error('APPOINTMENTS_FAILED');
    if (expected === 'CLIENT') {
      for (const path of ['/stamps/card', '/stamps/qr']) {
        if (!(await fetch(`${base}${path}`, { headers })).ok) throw new Error('LOYALTY_FAILED');
      }
    }
    roles.push(expected);
  }
  console.log(JSON.stringify({ success: true, databaseHealth: true, web: true, loginRoles: roles, clientCardAndQr: true }));
} catch (error) {
  const code = error?.code || error?.message;
  console.error(JSON.stringify({ success: false, code: typeof code === 'string' && /^[A-Z0-9_]+$/.test(code) ? code : 'SMOKE_CHECK_FAILED' }));
  process.exitCode = 1;
}
