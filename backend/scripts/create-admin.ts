import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { hash } from 'bcryptjs';
import { normalizeText, safeTextPattern } from '../src/common/input';

const db = new PrismaClient();
async function main() {
  const { ADMIN_EMAIL: email, ADMIN_NAME: name, ADMIN_PASSWORD: password } = process.env;
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !name || !password || password.length < 12 || Buffer.byteLength(password) > 72) throw new Error('Define ADMIN_EMAIL, ADMIN_NAME y ADMIN_PASSWORD (12–72 bytes).');
  const normalizedName = normalizeText(name) as string;
  if (normalizedName.length < 2 || normalizedName.length > 100 || !safeTextPattern.test(normalizedName)) throw new Error('Nombre de administrador inválido.');
  await db.user.create({ data: { name: normalizedName, email: email.trim().toLowerCase(), passwordHash: await hash(password, 12), role: 'ADMIN' } });
  console.log('Administrador creado. No se modificaron cuentas existentes.');
}
main().catch(() => { console.error('No se creó el administrador. Revisa los datos y que el correo no exista.'); process.exitCode = 1; }).finally(() => db.$disconnect());
