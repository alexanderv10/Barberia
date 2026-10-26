// Administrative CLI only. Back up all application rows before deleting test data.
// Never expose this operation through a public API or log passwords/tokens.
import { mkdir, open, readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { createHash, randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { PrismaClient } = require('@prisma/client');
const { parse } = require('dotenv');
const models = ['user', 'service', 'appointment', 'loyaltyCard', 'stampEvent', 'accountToken'];
const digest = value => createHash('sha256').update(value).digest('hex');
let db, stage = 'configuration';
try {
  const args = process.argv.slice(2);
  const emailIndex = args.indexOf('--admin-email');
  const email = args[emailIndex + 1]?.trim().toLowerCase();
  if (!args.includes('--confirm-reset') || emailIndex < 0 || !email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('EXPLICIT_RESET_AND_ADMIN_EMAIL_REQUIRED');
  const env = parse(await readFile(new URL('../backend/.env', import.meta.url), 'utf8'));
  const url = new URL(env.DATABASE_URL);
  if (!['postgresql:', 'postgres:'].includes(url.protocol)) throw new Error('INVALID_DATABASE');
  db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
  await db.$connect();
  const directory = new URL('../artifacts/account-reset/', import.meta.url);
  await mkdir(directory, { recursive: true });
  let backupPath;
  const result = await db.$transaction(async tx => {
    stage = 'locking';
    // Protect the backup and cleanup from concurrent API writes. No table or migration is dropped.
    await tx.$executeRawUnsafe('LOCK TABLE "User", "Service", "Appointment", "LoyaltyCard", "StampEvent", "AccountToken" IN EXCLUSIVE MODE');
    const admin = await tx.user.findUnique({ where: { email } });
    if (!admin) throw new Error('ADMIN_ACCOUNT_MUST_ALREADY_EXIST');
    stage = 'backup';
    const data = {};
    for (const model of models) data[model] = await tx[model].findMany({ orderBy: { id: 'asc' } });
    const content = JSON.stringify({ createdAt: new Date().toISOString(), data });
    const backup = new URL(`before-reset-${randomUUID()}.json`, directory);
    const handle = await open(backup, 'wx', 0o600);
    try { await handle.writeFile(content, 'utf8'); await handle.sync(); } finally { await handle.close(); }
    if (digest(await readFile(backup)) !== digest(content)) throw new Error('BACKUP_VERIFICATION_FAILED');
    await writeFile(new URL(`${backup.href}.sha256`), `${digest(content)}\n`, { flag: 'wx', mode: 0o600 });
    backupPath = fileURLToPath(backup);
    console.log(JSON.stringify({ backupSaved: true, before: Object.fromEntries(models.map(model => [model, data[model].length])) }));
    stage = 'cleanup';
    await tx.accountToken.deleteMany();
    await tx.stampEvent.deleteMany();
    await tx.appointment.deleteMany();
    await tx.loyaltyCard.deleteMany();
    await tx.user.deleteMany({ where: { id: { not: admin.id } } });
    const updated = await tx.user.update({ where: { id: admin.id }, data: { role: 'ADMIN', active: true, sessionVersion: { increment: 1 } } });
    stage = 'verification';
    if (updated.passwordHash !== admin.passwordHash || updated.email !== email || updated.role !== 'ADMIN' || updated.emailVerifiedAt?.getTime() !== admin.emailVerifiedAt?.getTime()) throw new Error('ADMIN_STATE_MISMATCH');
    const counts = {};
    for (const model of models) counts[model] = await tx[model].count();
    if (counts.user !== 1 || ['appointment', 'loyaltyCard', 'stampEvent', 'accountToken'].some(model => counts[model] !== 0)) throw new Error('CLEANUP_INCOMPLETE');
    const services = await tx.service.findMany({ orderBy: { id: 'asc' } });
    if (digest(JSON.stringify(services)) !== digest(JSON.stringify(data.service))) throw new Error('CATALOG_CHANGED');
    return counts;
  }, { maxWait: 10000, timeout: 60000 });
  console.log(JSON.stringify({ success: true, adminEmail: email, passwordPreserved: true, existingSessionsRevoked: true, counts: result, backupPath }));
} catch (error) {
  const code = error?.code || error?.errorCode || error?.message;
  console.error(JSON.stringify({ success: false, stage, code: typeof code === 'string' && /^[A-Z0-9_]+$/.test(code) ? code : 'RESET_FAILED', transactionRolledBack: true }));
  process.exitCode = 1;
} finally { await db?.$disconnect(); }
