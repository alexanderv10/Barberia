import { BadRequestException, Body, ConflictException, Controller, ForbiddenException, Get, Injectable, Module, NotFoundException, Post } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { IsString, IsUUID, MaxLength } from 'class-validator';
import { Throttle } from '@nestjs/throttler';
import { Actor, CurrentUser, Roles } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';

class ScanDto { @IsString() @MaxLength(2048) qrToken!: string; }
class CompleteDto extends ScanDto { @IsUUID() appointmentId!: string; }
@Injectable()
export class StampsService {
  constructor(private readonly db: PrismaService, private readonly jwt: JwtService) {}
  async card(actor: Actor) {
    const card = await this.db.loyaltyCard.findUnique({ where: { clientId: actor.id }, include: { events: { orderBy: { createdAt: 'desc' }, take: 20 } } });
    if (!card) throw new NotFoundException('Tarjeta no encontrada.');
    return { ...card, rewardAvailable: card.currentStamps === 10 };
  }
  async qr(actor: Actor) {
    const card = await this.card(actor);
    return { qrToken: this.jwt.sign({ sub: card.id, type: 'loyalty' }, { expiresIn: '5m' }), expiresIn: 300 };
  }
  private verify(token: string): string {
    try {
      const payload = this.jwt.verify(token, { algorithms: ['HS256'] });
      if (payload.type !== 'loyalty' || typeof payload.sub !== 'string') throw new Error();
      return payload.sub;
    } catch { throw new BadRequestException('El QR expiró o es inválido. Pide al cliente que lo actualice.'); }
  }
  async scan(token: string, actor: Actor) {
    const card = await this.db.loyaltyCard.findUnique({ where: { id: this.verify(token) }, include: { client: { select: { id: true, name: true } } } });
    if (!card) throw new NotFoundException('Tarjeta no encontrada.');
    const appointments = await this.db.appointment.findMany({ where: { clientId: card.clientId, status: 'PENDING', ...(actor.role === 'BARBER' ? { barberId: actor.id } : {}), startsAt: { lte: new Date() } }, include: { service: true }, orderBy: { startsAt: 'desc' }, take: 20 });
    if (actor.role === 'BARBER' && appointments.length === 0) throw new ForbiddenException('No tienes citas de este cliente disponibles para completar.');
    return { client: card.client, currentStamps: card.currentStamps, appointments };
  }
  async complete(dto: CompleteDto, actor: Actor) {
    const cardId = this.verify(dto.qrToken);
    return this.db.atomic(async tx => {
      const card = await tx.loyaltyCard.findUnique({ where: { id: cardId } });
      const appointment = await tx.appointment.findUnique({ where: { id: dto.appointmentId } });
      if (!card || !appointment || appointment.clientId !== card.clientId) throw new NotFoundException('La cita no corresponde a esta tarjeta.');
      if (actor.role !== 'ADMIN' && appointment.barberId !== actor.id) throw new ForbiddenException('Solo el barbero asignado puede completar la cita.');
      if (appointment.status !== 'PENDING') throw new ConflictException('La cita ya fue procesada.');
      if (appointment.startsAt > new Date()) throw new BadRequestException('La cita todavía no ha comenzado.');
      if (appointment.isReward && card.currentStamps !== 10) throw new ConflictException('El beneficio ya fue utilizado.');
      await tx.appointment.update({ where: { id: appointment.id }, data: { status: 'COMPLETED', completedAt: new Date() } });
      const award = !appointment.isReward && card.currentStamps < 10;
      if (appointment.isReward || award) {
        await tx.stampEvent.create({ data: { cardId, appointmentId: appointment.id, actorId: actor.id, type: appointment.isReward ? 'REDEEMED' : 'EARNED' } });
      }
      const updated = await tx.loyaltyCard.update({ where: { id: cardId }, data: appointment.isReward ? { currentStamps: 0 } : award ? { currentStamps: { increment: 1 }, lifetimeStamps: { increment: 1 } } : {} });
      return { currentStamps: updated.currentStamps, rewardAvailable: updated.currentStamps === 10, redeemed: appointment.isReward, stampAwarded: award };
    });
  }
}
@Controller('stamps')
class StampsController {
  constructor(private readonly stamps: StampsService) {}
  @Roles('CLIENT') @Get('card') card(@CurrentUser() actor: Actor) { return this.stamps.card(actor); }
  @Roles('CLIENT') @Get('qr') qr(@CurrentUser() actor: Actor) { return this.stamps.qr(actor); }
  @Roles('BARBER', 'ADMIN') @Throttle({ default: { limit: 30, ttl: 60000 } }) @Post('scan') scan(@Body() dto: ScanDto, @CurrentUser() actor: Actor) { return this.stamps.scan(dto.qrToken, actor); }
  @Roles('BARBER', 'ADMIN') @Throttle({ default: { limit: 20, ttl: 60000 } }) @Post('complete') complete(@Body() dto: CompleteDto, @CurrentUser() actor: Actor) { return this.stamps.complete(dto, actor); }
}
@Module({ controllers: [StampsController], providers: [StampsService] })
export class StampsModule {}
