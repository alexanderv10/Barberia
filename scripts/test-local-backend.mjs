// Always tests a separate LOCAL database, even when the app points to Supabase.
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { parse } = require('dotenv');
const env = parse(await readFile(new URL('../.env', import.meta.url), 'utf8'));
const url = new URL('postgresql://barberia@127.0.0.1:5432/barberia_test?schema=public');
url.password = env.POSTGRES_PASSWORD;
const cwd = fileURLToPath(new URL('../backend/', import.meta.url));
const testEnv = { ...process.env, DATABASE_URL: url.toString(), TEST_DATABASE_URL: url.toString(), MAIL_MODE: 'disabled' };
const migrated = spawnSync(process.execPath, ['node_modules/prisma/build/index.js', 'migrate', 'deploy'], { cwd, env: testEnv, encoding: 'utf8', windowsHide: true });
if (migrated.status !== 0) {
  console.error('No se pudo migrar la base local de pruebas; no se ha usado Supabase.');
  process.exit(1);
}
const tested = spawnSync(process.execPath, ['-r', 'ts-node/register', '--test', 'test/integration/*.test.ts'], { cwd, env: testEnv, stdio: 'inherit', windowsHide: true });
process.exitCode = tested.status ?? 1;
