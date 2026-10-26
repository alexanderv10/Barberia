import { Body, Controller, Get, Injectable, Module, Post, ConflictException, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtService } from '@nestjs/jwt';
import { IsEmail, IsString, MinLength, MaxLength, Matches } from 'class-validator';
import { User } from '@prisma/client';
import { AccountTokensService } from './account-tokens.service';
import { AccountMailService } from './account-mail.service';
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
class EmailDto { @EmailInput() @IsEmail() @MaxLength(254) email!: string; }
class TokenDto { @IsString() @Matches(/^[a-f0-9]{64}$/) token!: string; }
class ResetDto extends TokenDto { @IsString() @MinLength(10) @MaxLength(72) password!: string; }
@Injectable()
export class AuthService {
  constructor(private readonly db: PrismaService, private readonly jwt: JwtService, private readonly accounts: AccountTokensService) {}
  private session(user: User) {
    return { accessToken: this.jwt.sign({ sub: user.id, type: 'access', ver: user.sessionVersion }), user: { id: user.id, name: user.name, email: user.email, role: user.role, emailVerified: user.emailVerifiedAt !== null } };
  }
  async register(dto: RegisterDto) {
    if (Buffer.byteLength(dto.password, 'utf8') > 72) throw new BadRequestException('La contraseña no puede superar 72 bytes UTF-8.');
    if (dto.name.trim().length < 2) throw new BadRequestException('Ingresa un nombre válido.');
    const passwordHash = await hash(dto.password, 12);
    let user: User;
    try {
      user = await this.db.user.create({ data: { name: dto.name.trim(), email: dto.email.trim().toLowerCase(), passwordHash, card: { create: {} } } });
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') throw new ConflictException('Este correo ya tiene una cuenta.');
      throw e;
    }
    const verificationEmailSent = await this.accounts.issue(user.id, 'VERIFY_EMAIL');
    return { ...this.session(user), verificationEmailSent };
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
  constructor(private readonly auth: AuthService, private readonly accounts: AccountTokensService) {}
  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('register') register(@Body() dto: RegisterDto) { return this.auth.register(dto); }
  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('login') login(@Body() dto: LoginDto) { return this.auth.login(dto); }
  @Get('me') me(@CurrentUser() user: Actor) { const { id, name, email, role, emailVerifiedAt } = user; return { id, name, email, role, emailVerified: !!emailVerifiedAt }; }
  @Public() @Throttle({ default: { limit: 5, ttl: 60000 } }) @Post('password/forgot') forgot(@Body() dto: EmailDto) { return this.accounts.requestReset(dto.email); }
  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('password/reset') reset(@Body() dto: ResetDto) { return this.accounts.reset(dto.token, dto.password); }
  @Public() @Throttle({ default: { limit: 10, ttl: 60000 } }) @Post('email/verify') verify(@Body() dto: TokenDto) { return this.accounts.verify(dto.token); }
  @Throttle({ default: { limit: 3, ttl: 60000 } }) @Post('email/resend') async resend(@CurrentUser() user: Actor) {
    const sent = await this.accounts.issue(user.id, 'VERIFY_EMAIL');
    return { sent, message: sent ? 'Enviamos un enlace a tu correo. Revisa también spam.' : 'Si no recibiste un correo, espera un minuto antes de reintentar. Si persiste, contacta con la barbería.' };
  }
}
@Module({ controllers: [AuthController], providers: [AuthService, AccountTokensService, AccountMailService] })
export class AuthModule {}
