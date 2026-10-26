import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { hash } from 'bcryptjs';

const db = new PrismaClient();
async function seed() {
  if (process.env.NODE_ENV === 'production') throw new Error('El seed de demostración no se ejecuta en producción.');
  if (!process.env.SEED_PASSWORD || process.env.SEED_PASSWORD.length < 10 || Buffer.byteLength(process.env.SEED_PASSWORD) > 72) throw new Error('Configura SEED_PASSWORD (mínimo 10 caracteres y máximo 72 bytes).');
  const passwordHash = await hash(process.env.SEED_PASSWORD, 12);
  for (const [name, email, role] of [
    ['Administrador', 'admin@barberia.local', 'ADMIN'],
    ['Mateo Rivera', 'mateo@barberia.local', 'BARBER'],
    ['Lucas Torres', 'lucas@barberia.local', 'BARBER'],
    ['Alex Moreno', 'cliente@barberia.local', 'CLIENT'],
  ] as const) {
    await db.user.upsert({ where: { email }, update: {}, create: { name, email, role, passwordHash, ...(role === 'CLIENT' ? { card: { create: {} } } : {}) } });
  }
  for (const service of [
    { id: '11111111-1111-4111-8111-111111111111', name: 'Corte clásico', description: 'Tu estilo de siempre, con un acabado impecable.', durationMin: 30, priceCents: 1200, rewardEligible: true },
    { id: '22222222-2222-4222-8222-222222222222', name: 'Diseño de barba', description: 'Perfilado, definición y cuidado en cada detalle.', durationMin: 30, priceCents: 800, rewardEligible: false },
    { id: '33333333-3333-4333-8333-333333333333', name: 'Corte + barba', description: 'La experiencia completa para renovar tu look.', durationMin: 60, priceCents: 1800, rewardEligible: false },
  ]) await db.service.upsert({ where: { id: service.id }, update: {}, create: service });
  console.log('Catálogo y cuentas de desarrollo creados.');
}
seed().finally(() => db.$disconnect());
