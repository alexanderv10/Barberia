import { Controller, Get, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { Throttle, ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { jwtSecret } from './common/configure-app';
import { AuthGuard, Public } from './common/security';
import { PrismaModule, PrismaService } from './prisma/prisma.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ServicesModule } from './services/services.module';
import { AppointmentsModule } from './appointments/appointments.module';
import { StampsModule } from './stamps/stamps.module';

@Controller('health')
class HealthController {
  constructor(private readonly db: PrismaService) {}
  @Public() @Throttle({ default: { limit: 60, ttl: 60000 } }) @Get() async health() { await this.db.$queryRaw`SELECT 1`; return { status: 'ok' }; }
}
@Controller('shop')
class ShopController {
  @Public() @Get() info() {
    return {
      name: process.env.SHOP_NAME || 'Barbería',
      description: 'Un espacio para cuidarte. Un momento para ti.',
      hours: 'Lunes a sábado · 09:00 a 19:00',
      timezone: process.env.SHOP_TIMEZONE || 'America/Guayaquil',
      address: process.env.SHOP_ADDRESS || null,
      phone: process.env.SHOP_PHONE || null,
    };
  }
}
@Module({
  imports: [PrismaModule, JwtModule.registerAsync({ global: true, useFactory: () => ({ secret: jwtSecret(), signOptions: { expiresIn: '8h', algorithm: 'HS256' } }) }), ThrottlerModule.forRoot([{ ttl: 60000, limit: 120 }]), AuthModule, UsersModule, ServicesModule, AppointmentsModule, StampsModule],
  controllers: [HealthController, ShopController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }, { provide: APP_GUARD, useClass: AuthGuard }],
})
export class AppModule {}
