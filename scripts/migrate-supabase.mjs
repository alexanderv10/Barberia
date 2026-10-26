// One-time transfer from the local database to an empty Supabase application schema.
// Never logs connection strings, passwords, or individual records.
import { readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { PrismaClient } = require('@prisma/client');
const { parse } = require('dotenv');
const models = ['user', 'service', 'loyaltyCard', 'appointment', 'stampEvent'];
const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
let source, target, stage = 'configuration';
try {
  const local = parse(await readFile(new URL('../backend/.env', import.meta.url), 'utf8'));
  const remote = parse(await readFile(new URL('../artifacts/supabase-migration/.env', import.meta.url), 'utf8'));
  const sourceUrl = new URL(local.DATABASE_URL);
  const targetUrl = new URL(remote.SUPABASE_DATABASE_URL);
  if (!['localhost', '127.0.0.1'].includes(sourceUrl.hostname) || sourceUrl.pathname !== '/barberia') throw new Error('SOURCE_INVALID');
  if (!targetUrl.hostname.endsWith('.pooler.supabase.com') || targetUrl.port !== '5432' || targetUrl.pathname !== '/postgres') throw new Error('TARGET_INVALID');
  const certificate = fileURLToPath(new URL('../artifacts/supabase-migration/prod-ca-2021.crt', import.meta.url));
  await readFile(certificate);
  targetUrl.searchParams.set('sslcert', certificate);
  targetUrl.searchParams.set('sslaccept', 'strict');
  source = new PrismaClient({ datasources: { db: { url: sourceUrl.toString() } } });
  target = new PrismaClient({ datasources: { db: { url: targetUrl.toString() } } });
  await Promise.all([source.$connect(), target.$connect()]);

  stage = 'source_snapshot';
  const records = await source.$transaction(async tx => {
    const result = {};
    for (const model of models) result[model] = await tx[model].findMany({ orderBy: { id: 'asc' } });
    return result;
  }, { isolationLevel: 'RepeatableRead' });
  await writeFile(new URL('../artifacts/supabase-migration/source-records.json', import.meta.url), JSON.stringify(records), { flag: 'wx' });
  console.log(JSON.stringify({ stage, counts: Object.fromEntries(models.map(model => [model, records[model].length])) }));

  stage = 'empty_target_check';
  const tables = await target.$queryRaw`SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('User','Service','Appointment','LoyaltyCard','StampEvent','_prisma_migrations')`;
  if (tables.length !== 0) throw new Error('TARGET_NOT_EMPTY');

  stage = 'schema_migrations';
  const migrated = spawnSync(process.execPath, [fileURLToPath(new URL('../backend/node_modules/prisma/build/index.js', import.meta.url)), 'migrate', 'deploy'], {
    cwd: fileURLToPath(new URL('../backend/', import.meta.url)),
    env: { ...process.env, DATABASE_URL: targetUrl.toString() },
    encoding: 'utf8', timeout: 120000, windowsHide: true,
  });
  if (migrated.status !== 0) {
    const code = `${migrated.stdout || ''}\n${migrated.stderr || ''}`.match(/\bP\d{4}\b/)?.[0];
    throw new Error(code || 'MIGRATION_FAILED');
  }
  console.log(JSON.stringify({ stage, success: true }));

  stage = 'data_transfer';
  await target.$transaction(async tx => {
    for (const model of models) {
      if (await tx[model].count() !== 0) throw new Error('TARGET_NOT_EMPTY');
      if (records[model].length) await tx[model].createMany({ data: records[model] });
    }
  }, { timeout: 60000 });

  stage = 'verification';
  const report = {};
  for (const model of models) {
    const copied = await target[model].findMany({ orderBy: { id: 'asc' } });
    const current = await source[model].findMany({ orderBy: { id: 'asc' } });
    if (digest(copied) !== digest(records[model])) throw new Error('COPY_MISMATCH');
    if (digest(current) !== digest(records[model])) throw new Error('SOURCE_CHANGED');
    report[model] = { count: copied.length, sha256: digest(copied) };
  }
  const constraints = await target.$queryRaw`SELECT conname FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND conname IN ('barber_no_overlap','client_no_overlap','stamp_bounds','positive_interval','nonnegative_price','valid_service') ORDER BY conname`;
  if (constraints.length !== 6) throw new Error('CONSTRAINTS_MISSING');
  const migrations = await target.$queryRaw`SELECT count(*)::int AS count FROM "_prisma_migrations" WHERE finished_at IS NOT NULL AND rolled_back_at IS NULL`;
  if (migrations[0].count !== 3) throw new Error('MIGRATION_COUNT');
  await writeFile(new URL('../artifacts/supabase-migration/verification.json', import.meta.url), JSON.stringify({ verifiedAt: new Date().toISOString(), report, constraints: constraints.map(row => row.conname), migrations: migrations[0].count }, null, 2));
  console.log(JSON.stringify({ stage, success: true, counts: Object.fromEntries(models.map(model => [model, report[model].count])), constraints: constraints.length, migrations: migrations[0].count }));
} catch (error) {
  const code = error?.code || error?.errorCode || error?.message;
  console.error(JSON.stringify({ success: false, stage, code: typeof code === 'string' && /^[A-Z0-9_]+$/.test(code) ? code : 'TRANSFER_FAILED' }));
  process.exitCode = 1;
} finally {
  await Promise.allSettled([source?.$disconnect(), target?.$disconnect()]);
}
