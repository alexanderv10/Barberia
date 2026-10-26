import { Body, Controller, Get, Injectable, Module, Post, Patch, Param, Query, BadRequestException, ForbiddenException, NotFoundException, ConflictException, ParseUUIDPipe } from '@nestjs/common';
import { IsBoolean, IsISO8601, IsOptional, IsUUID, Matches, MaxLength } from 'class-validator';
import { DateTime } from 'luxon';
import { PrismaService } from '../prisma/prisma.service';
import { Actor, CurrentUser, Roles } from '../common/security';
import { overlap, shopZone, validSlot } from './schedule';

class BookDto {
  @IsUUID() barberId!: string;
  @IsUUID() serviceId!: string;
  @IsISO8601({ strict: true }) @MaxLength(40) startsAt!: string;
  @IsOptional() @IsBoolean() isReward = false;
}
class AvailabilityDto {
  @IsUUID() barberId!: string;
  @IsUUID() serviceId!: string;
  @Matches(/^\d{4}-\d{2}-\d{2}$/) @IsISO8601({ strict: true }) date!: string;
}
export const appointmentInclude = { service: true, barber: { select: { id: true, name: true } }, client: { select: { id: true, name: true } } } as const;
@Injectable()
export class AppointmentsService {
  constructor(private readonly db: PrismaService) {}
  async availability(query: AvailabilityDto, actor: Actor) {
    const day = DateTime.fromISO(query.date, { zone: shopZone() }).startOf('day');
    if (!day.isValid) throw new BadRequestException('Fecha inválida.');
    const [service, barber, appointments] = await Promise.all([
      this.db.service.findFirst({ where: { id: query.serviceId, active: true } }),
      this.db.user.findFirst({ where: { id: query.barberId, active: true, role: 'BARBER' } }),
      this.db.appointment.findMany({ where: { OR: [{ barberId: query.barberId }, { clientId: actor.id }], status: { not: 'CANCELLED' }, startsAt: { lt: day.plus({ days: 1 }).toJSDate() }, endsAt: { gt: day.toJSDate() } } }),
    ]);
    if (!service || !barber) throw new NotFoundException('Servicio o barbero no disponible.');
    const slots: string[] = [];
    for (let t = day.set({ hour: 9 }); t.hour < 19; t = t.plus({ minutes: 30 })) {
      const end = t.plus({ minutes: service.durationMin });
      if (validSlot(t, service.durationMin) && !appointments.some(a => overlap(t.toJSDate(), end.toJSDate(), a.startsAt, a.endsAt))) slots.push(t.toUTC().toISO()!);
    }
    return { timezone: shopZone(), slots };
  }
  list(actor: Actor) {
    return this.db.appointment.findMany({ where: actor.role === 'CLIENT' ? { clientId: actor.id } : actor.role === 'BARBER' ? { barberId: actor.id } : {}, include: appointmentInclude, orderBy: { startsAt: 'desc' }, take: 500 });
  }
  async book(dto: BookDto, actor: Actor) {
    return this.db.atomic(async tx => {
      const [service, barber, card] = await Promise.all([
        tx.service.findFirst({ where: { id: dto.serviceId, active: true } }),
        tx.user.findFirst({ where: { id: dto.barberId, role: 'BARBER', active: true } }),
        tx.loyaltyCard.findUnique({ where: { clientId: actor.id } }),
      ]);
      if (!service || !barber) throw new BadRequestException('Servicio o barbero no disponible.');
      const start = DateTime.fromISO(dto.startsAt, { setZone: true });
      if (!/(Z|[+-]\d{2}:\d{2})$/.test(dto.startsAt) || !validSlot(start, service.durationMin)) throw new BadRequestException('Horario inválido. Atendemos de lunes a sábado de 09:00 a 19:00. Reserva hasta 60 días antes.');
      if (dto.isReward && (!service.rewardEligible || card?.currentStamps !== 10)) throw new BadRequestException('Necesitas 10 sellos y un servicio de corte elegible.');
      const endsAt = start.plus({ minutes: service.durationMin }).toJSDate();
      const collision = await tx.appointment.findFirst({ where: { OR: [{ barberId: dto.barberId }, { clientId: actor.id }], status: { not: 'CANCELLED' }, startsAt: { lt: endsAt }, endsAt: { gt: start.toJSDate() } } });
      if (collision) throw new ConflictException('Este horario acaba de ocuparse. Elige otro.');
      return tx.appointment.create({ data: { clientId: actor.id, barberId: dto.barberId, serviceId: dto.serviceId, startsAt: start.toJSDate(), endsAt, priceCents: dto.isReward ? 0 : service.priceCents, isReward: dto.isReward }, include: appointmentInclude });
    });
  }
  async cancel(id: string, actor: Actor) {
    return this.db.atomic(async tx => {
      const appointment = await tx.appointment.findUnique({ where: { id } });
      if (!appointment) throw new NotFoundException('Cita no encontrada.');
      if (actor.role !== 'ADMIN' && appointment[actor.role === 'CLIENT' ? 'clientId' : 'barberId'] !== actor.id) throw new ForbiddenException();
      if (appointment.status !== 'PENDING') throw new ConflictException('La cita ya fue procesada.');
      return tx.appointment.update({ where: { id }, data: { status: 'CANCELLED' }, include: appointmentInclude });
    });
  }
  async accept(id: string, actor: Actor) {
    return this.db.atomic(async tx => {
      const appointment = await tx.appointment.findUnique({ where: { id } });
      if (!appointment) throw new NotFoundException('Cita no encontrada.');
      if (actor.role !== 'ADMIN' && appointment.barberId !== actor.id) throw new ForbiddenException();
      if (appointment.status !== 'PENDING' || appointment.acceptedAt) throw new ConflictException('La cita ya fue procesada.');
      return tx.appointment.update({ where: { id }, data: { acceptedAt: new Date() }, include: appointmentInclude });
    });
  }
}
@Controller('appointments')
class AppointmentsController {
  constructor(private readonly appointments: AppointmentsService) {}
  @Get('availability') availability(@Query() query: AvailabilityDto, @CurrentUser() actor: Actor) { return this.appointments.availability(query, actor); }
  @Get() list(@CurrentUser() actor: Actor) { return this.appointments.list(actor); }
  @Roles('CLIENT') @Post() book(@Body() dto: BookDto, @CurrentUser() actor: Actor) { return this.appointments.book(dto, actor); }
  @Patch(':id/cancel') cancel(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() actor: Actor) { return this.appointments.cancel(id, actor); }
  @Roles('BARBER', 'ADMIN') @Patch(':id/accept') accept(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() actor: Actor) { return this.appointments.accept(id, actor); }
}
@Module({ controllers: [AppointmentsController], providers: [AppointmentsService] })
export class AppointmentsModule {}
