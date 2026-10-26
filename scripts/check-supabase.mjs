// Read-only connectivity check. Never log connection URLs or database passwords.
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { PrismaClient } = require('@prisma/client');
const { parse } = require('dotenv');
let db;
try {
  const env = parse(await readFile(new URL('../artifacts/supabase-migration/.env', import.meta.url), 'utf8'));
  const url = new URL(env.SUPABASE_DATABASE_URL);
  if (!url.hostname.endsWith('.pooler.supabase.com') || url.port !== '5432' || url.pathname !== '/postgres') throw new Error('Invalid target');
  const certificate = fileURLToPath(new URL('../artifacts/supabase-migration/prod-ca-2021.crt', import.meta.url));
  await readFile(certificate);
  url.searchParams.set('sslcert', certificate);
  url.searchParams.set('sslaccept', 'strict');
  db = new PrismaClient({ datasources: { db: { url: url.toString() } } });
  await db.$connect();
  const result = await db.$queryRaw`SELECT current_database() AS database, current_setting('server_version') AS version`;
  const extensions = await db.$queryRaw`SELECT extname FROM pg_extension WHERE extname = 'btree_gist'`;
  const tables = await db.$queryRaw`SELECT count(*)::int AS count FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('User','Service','Appointment','LoyaltyCard','StampEvent','_prisma_migrations')`;
  console.log(JSON.stringify({ connected: true, database: result[0].database, version: result[0].version, applicationTablesPresent: tables[0].count, btreeGistInstalled: extensions.length > 0 }));
} catch (error) {
  const code = typeof error?.errorCode === 'string' ? error.errorCode : typeof error?.code === 'string' ? error.code : 'CHECK_FAILED';
  const hints = { ENOENT: 'Ejecuta primero scripts/prepare-supabase.ps1.', P1000: 'Revisa la contraseña y el usuario.', P1001: 'No se pudo alcanzar el servidor; revisa la red y el estado del proyecto.', P1011: 'Revisa el certificado TLS de la conexión.', P1017: 'El servidor cerró la conexión.' };
  console.error(JSON.stringify({ connected: false, code: /^[A-Z0-9_]+$/.test(code) ? code : 'CHECK_FAILED', message: hints[code] || 'No se pudo completar la comprobación; no se han modificado datos.' }));
  process.exitCode = 1;
} finally {
  await db?.$disconnect();
}
