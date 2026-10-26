import { Body, Controller, Get, Injectable, Module, Post, ConflictException, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtService } from '@nestjs/jwt';
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';
import { compare, hash } from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { Actor, CurrentUser, Public } from '../common/security';
import { EmailInput, PlainText, SafeText } from '../common/input';

class LoginDto {
  @EmailInput() @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(10) @MaxLength(72) password!: string;
}
class RegisterDto extends LoginDto {
  @PlainText() @SafeText() @IsString() @MinLength(2) @MaxLength(100) name!: string;
}
@Injectable()
export class AuthService {
  constructor(private readonly db: PrismaService, private readonly jwt: JwtService) {}
  private session(user: Actor) {
    return { accessToken: this.jwt.sign({ sub: user.id, type: 'access' }), user: { id: user.id, name: user.name, email: user.email, role: user.role } };
  }
  async register(dto: RegisterDto) {
    if (Buffer.byteLength(dto.password, 'utf8') > 72) throw new BadRequestException('La contraseña no puede superar 72 bytes UTF-8.');
    if (dto.name.trim().length < 2) throw new BadRequestException('Ingresa un nombre válido.');
    const passwordHash = await hash(dto.password, 12);
    try {
      const user = await this.db.user.create({ data: { name: dto.name.trim(), email: dto.email.trim().toLowerCase(), passwordHash, card: { create: {} } } });
      return this.session(user);
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') throw new ConflictException('Este correo ya tiene una cuenta.');
      throw e;
    }
  }
  async login(dto: LoginDto) {
    if (Buffer.byteLength(dto.password, 'utf8') > 72) throw new UnauthorizedException('Correo o contraseña incorrectos.');
    const user = await this.db.user.findUnique({ where: { email: dto.email.trim().toLowerCase() } });
    if (!user?.active || !(await compare(dto.password, user.passwordHash))) throw new UnauthorizedException('Correo o contraseña incorrectos.');
    return this.session(user);
  }
}
@Controller('auth')
class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('register') register(@Body() dto: RegisterDto) { return this.auth.register(dto); }
  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('login') login(@Body() dto: LoginDto) { return this.auth.login(dto); }
  @Get('me') me(@CurrentUser() user: Actor) { const { id, name, email, role } = user; return { id, name, email, role }; }
}
@Module({ controllers: [AuthController], providers: [AuthService] })
export class AuthModule {}
