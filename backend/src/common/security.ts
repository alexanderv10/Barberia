import { CanActivate, ExecutionContext, Injectable, SetMetadata, UnauthorizedException, ForbiddenException, createParamDecorator } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface Actor { id: string; role: Role; name: string; email: string }
export const Public = () => SetMetadata('public', true);
export const Roles = (...roles: Role[]) => SetMetadata('roles', roles);
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): Actor => ctx.switchToHttp().getRequest().user);

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly jwt: JwtService, private readonly db: PrismaService) {}
  async canActivate(context: ExecutionContext) {
    if (this.reflector.getAllAndOverride('public', [context.getHandler(), context.getClass()])) return true;
    const req = context.switchToHttp().getRequest();
    const [kind, token] = (req.headers.authorization ?? '').split(' ');
    if (kind !== 'Bearer' || !token) throw new UnauthorizedException('Inicia sesión para continuar.');
    try {
      const claims = await this.jwt.verifyAsync(token, { algorithms: ['HS256'] });
      if (claims.type !== 'access') throw new Error('Invalid token purpose');
      const user = await this.db.user.findUnique({ where: { id: claims.sub }, select: { id: true, name: true, role: true, email: true, active: true } });
      if (!user?.active) throw new Error('Inactive user');
      req.user = user;
    } catch { throw new UnauthorizedException('Tu sesión expiró. Vuelve a ingresar.'); }
    const roles = this.reflector.getAllAndOverride<Role[]>('roles', [context.getHandler(), context.getClass()]);
    if (roles && !roles.includes(req.user.role)) throw new ForbiddenException('No tienes permiso para esta acción.');
    return true;
  }
}
