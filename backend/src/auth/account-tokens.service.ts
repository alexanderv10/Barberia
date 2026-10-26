import { BadRequestException, Injectable } from '@nestjs/common';
import { AccountTokenPurpose } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { hash } from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { AccountMailService } from './account-mail.service';

const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');
const invalidLink = () => new BadRequestException('El enlace es inválido, ya se utilizó o venció. Solicita uno nuevo.');

@Injectable()
export class AccountTokensService {
  constructor(private readonly db: PrismaService, private readonly mail: AccountMailService) {}

  async issue(userId: string, purpose: AccountTokenPurpose): Promise<boolean> {
    const token = randomBytes(32).toString('hex');
    const now = new Date();
    const issued = await this.db.$transaction(async tx => {
      // Serialize issuance per account, including concurrent resend requests.
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId}::uuid FOR UPDATE`;
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user?.active || (purpose === 'VERIFY_EMAIL' && user.emailVerifiedAt)) return null;
      const recent = await tx.accountToken.count({ where: { userId, purpose, createdAt: { gt: new Date(now.getTime() - 3600000) } } });
      const latest = await tx.accountToken.findFirst({ where: { userId, purpose }, orderBy: { createdAt: 'desc' } });
      if (recent >= 5 || (latest && latest.createdAt.getTime() > now.getTime() - 60000)) return null;
      await tx.accountToken.updateMany({ where: { userId, purpose, usedAt: null }, data: { usedAt: now } });
      const saved = await tx.accountToken.create({ data: { userId, purpose, tokenHash: tokenHash(token), expiresAt: new Date(now.getTime() + (purpose === 'VERIFY_EMAIL' ? 86400000 : 1800000)) } });
      return { id: saved.id, email: user.email };
    }, { maxWait: 10000, timeout: 15000 });
    if (!issued) return false;
    try {
      await this.mail.send(issued.email, purpose, token);
      return true;
    } catch {
      await this.db.accountToken.deleteMany({ where: { id: issued.id } });
      this.mail.reportFailure();
      return false;
    }
  }

  async requestReset(email: string) {
    const user = await this.db.user.findUnique({ where: { email } });
    if (user?.active) await this.issue(user.id, 'RESET_PASSWORD');
    // Same status and body whether the account exists, is inactive or delivery fails.
    return { message: 'Si existe una cuenta activa con ese correo, recibirás un enlace para restablecer tu contraseña. Revisa también spam.' };
  }

  async verify(token: string) {
    await this.consume(token, 'VERIFY_EMAIL');
    return { message: 'Tu correo electrónico quedó verificado. Ya puedes volver a tu cuenta.' };
  }

  async reset(token: string, password: string) {
    if (Buffer.byteLength(password, 'utf8') > 72) throw new BadRequestException('La contraseña no puede superar 72 bytes UTF-8.');
    // Reject invalid links before doing the costly password hash; consume rechecks atomically.
    const saved = await this.db.accountToken.findUnique({ where: { tokenHash: tokenHash(token) } });
    if (!saved || saved.purpose !== 'RESET_PASSWORD' || saved.usedAt || saved.expiresAt <= new Date()) throw invalidLink();
    await this.consume(token, 'RESET_PASSWORD', await hash(password, 12));
    return { message: 'Contraseña actualizada. Inicia sesión con tu nueva contraseña; las sesiones anteriores se cerraron.' };
  }

  private async consume(token: string, purpose: AccountTokenPurpose, passwordHash?: string) {
    await this.db.$transaction(async tx => {
      const saved = await tx.accountToken.findUnique({ where: { tokenHash: tokenHash(token) } });
      if (!saved || saved.purpose !== purpose) throw invalidLink();
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${saved.userId}::uuid FOR UPDATE`;
      const user = await tx.user.findUnique({ where: { id: saved.userId } });
      const now = new Date();
      if (!user?.active) throw invalidLink();
      const consumed = await tx.accountToken.updateMany({ where: { id: saved.id, purpose, usedAt: null, expiresAt: { gt: now } }, data: { usedAt: now } });
      if (consumed.count !== 1) throw invalidLink();
      if (purpose === 'VERIFY_EMAIL') {
        await tx.user.update({ where: { id: user.id }, data: { emailVerifiedAt: user.emailVerifiedAt || now } });
      } else {
        await tx.user.update({ where: { id: user.id }, data: { passwordHash: passwordHash!, sessionVersion: { increment: 1 } } });
        await tx.accountToken.updateMany({ where: { userId: user.id, usedAt: null }, data: { usedAt: now } });
      }
    }, { maxWait: 10000, timeout: 15000 });
  }
}
