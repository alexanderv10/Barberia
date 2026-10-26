import { Body, Controller, Get, Module, Post, BadRequestException, ConflictException } from '@nestjs/common';
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';
import { hash } from 'bcryptjs';
import { Public, Roles } from '../common/security';
import { PrismaService } from '../prisma/prisma.service';
import { EmailInput, PlainText, SafeText } from '../common/input';

class BarberDto {
  @PlainText() @SafeText() @IsString() @MinLength(2) @MaxLength(100) name!: string;
  @EmailInput() @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(10) @MaxLength(72) password!: string;
}

@Controller('users')
class UsersController {
  constructor(private readonly db: PrismaService) {}
  @Public() @Get('barbers') barbers() {
    return this.db.user.findMany({ where: { role: 'BARBER', active: true }, select: { id: true, name: true }, orderBy: { name: 'asc' } });
  }
  @Roles('ADMIN') @Post('barbers') async create(@Body() dto: BarberDto) {
    if (Buffer.byteLength(dto.password, 'utf8') > 72 || dto.name.trim().length < 2) throw new BadRequestException('Revisa el nombre y la longitud de la contraseña.');
    try {
      return await this.db.user.create({ data: { name: dto.name.trim(), email: dto.email.trim().toLowerCase(), passwordHash: await hash(dto.password, 12), role: 'BARBER' }, select: { id: true, name: true, email: true, role: true } });
    } catch (e) { if ((e as { code?: string }).code === 'P2002') throw new ConflictException('El correo ya está registrado.'); throw e; }
  }
}
@Module({ controllers: [UsersController] })
export class UsersModule {}
