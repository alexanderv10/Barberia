// Switch the local API only after a successful, verified transfer. Keep rollback copies ignored by Git.
import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { parse } = require('dotenv');
try {
  const report = JSON.parse(await readFile(new URL('../artifacts/supabase-migration/verification.json', import.meta.url), 'utf8'));
  if (report.migrations !== 3 || report.constraints?.length !== 6) throw new Error('UNVERIFIED_TRANSFER');
  const prepared = parse(await readFile(new URL('../artifacts/supabase-migration/.env', import.meta.url), 'utf8'));
  const url = new URL(prepared.SUPABASE_DATABASE_URL);
  if (!url.hostname.endsWith('.pooler.supabase.com') || url.port !== '5432' || url.pathname !== '/postgres') throw new Error('INVALID_TARGET');
  await mkdir(new URL('../backend/prisma/certs/', import.meta.url), { recursive: true });
  await copyFile(new URL('../artifacts/supabase-migration/prod-ca-2021.crt', import.meta.url), new URL('../backend/prisma/certs/supabase-ca.crt', import.meta.url));
  url.searchParams.set('sslcert', 'certs/supabase-ca.crt');
  url.searchParams.set('sslaccept', 'strict');
  const changes = [
    { path: '../backend/.env', key: 'DATABASE_URL', backup: 'backend-before-supabase.env' },
    { path: '../.env', key: 'DOCKER_DATABASE_URL', backup: 'compose-before-supabase.env' },
  ];
  // Back up both files before changing either file. Existing backups are never overwritten.
  const files = [];
  for (const change of changes) {
    const original = await readFile(new URL(change.path, import.meta.url), 'utf8');
    if (!new RegExp(`^${change.key}=`, 'm').test(original)) throw new Error('MISSING_ENV_KEY');
    await writeFile(new URL(`../artifacts/supabase-migration/${change.backup}`, import.meta.url), original, { flag: 'wx' });
    files.push({ ...change, original });
  }
  for (const file of files) {
    const updated = file.original.replace(new RegExp(`^${file.key}=.*$`, 'm'), `${file.key}="${url.toString()}"`);
    await writeFile(new URL(file.path, import.meta.url), updated);
  }
  console.log(JSON.stringify({ configured: true, tlsVerification: 'strict', rollbackCopiesSaved: true }));
} catch (error) {
  const code = error?.code || error?.message;
  console.error(JSON.stringify({ configured: false, code: typeof code === 'string' && /^[A-Z0-9_]+$/.test(code) ? code : 'CONFIGURATION_FAILED' }));
  process.exitCode = 1;
}
