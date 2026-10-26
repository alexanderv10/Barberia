import { ForbiddenException, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';

export function jwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32 || /replace-with|change[_-]?me/i.test(secret)) {
    throw new Error('Configura JWT_SECRET con un secreto aleatorio de al menos 32 caracteres; no uses el ejemplo.');
  }
  return secret;
}

export function corsOrigins(): string[] {
  const entries = (process.env.CORS_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
  if (!entries.length) throw new Error('Configura CORS_ORIGINS con los orígenes exactos de la web.');
  for (const origin of entries) {
    const url = new URL(origin);
    if (!['http:', 'https:'].includes(url.protocol) || url.origin !== origin) {
      throw new Error('Cada CORS_ORIGINS debe ser un origen HTTP(S) exacto, sin comodines, rutas ni barra final.');
    }
  }
  return [...new Set(entries)];
}

export function configureApp(app: NestExpressApplication): void {
  const allowed = new Set(corsOrigins());
  app.use(helmet());
  app.useBodyParser('json', { limit: '16kb' });
  app.setGlobalPrefix('api');
  app.enableCors({
    // Native Android/iOS and server-to-server requests have no Origin. JWT still protects private routes.
    origin(origin, callback) {
      if (!origin || allowed.has(origin)) callback(null, true);
      else callback(new ForbiddenException('Origen web no autorizado.'), false);
    },
    methods: ['GET', 'POST', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type'],
    credentials: false,
    maxAge: 600,
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true, forbidUnknownValues: true }));
}
