// Configure Mailpit only if no real SMTP sender has been configured.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../backend/package.json', import.meta.url));
const { parse } = require('dotenv');
const file = new URL('../backend/.env', import.meta.url);
let text = await readFile(file, 'utf8');
const env = parse(text);
if (env.MAIL_MODE === 'smtp' || env.SMTP_PASSWORD) {
  console.log('Se conserva la configuración SMTP existente.');
} else {
  const directory = new URL('../artifacts/account-email/', import.meta.url);
  await mkdir(directory, { recursive: true });
  try { await writeFile(new URL('backend-before-mail.env', directory), text, { flag: 'wx' }); }
  catch (error) { if (error.code !== 'EEXIST') throw error; }
  for (const [key, value] of Object.entries({ APP_WEB_URL: env.APP_WEB_URL || 'http://localhost:8080', MAIL_MODE: 'local', MAIL_FROM: 'barberia@example.test', SMTP_HOST: 'mailpit', SMTP_PORT: '1025' })) {
    const line = `${key}=${value}`;
    const pattern = new RegExp(`^${key}=.*$`, 'm');
    text = pattern.test(text) ? text.replace(pattern, () => line) : `${text.trimEnd()}\n${line}\n`;
  }
  await writeFile(file, text);
  console.log('Correo de prueba configurado: buzón local http://localhost:8025 (sin envío externo).');
}
