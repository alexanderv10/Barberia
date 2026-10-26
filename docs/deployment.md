# Despliegue

## Estado de la entrega

Validado localmente: migraciones en PostgreSQL 17, build TypeScript, pruebas de horario, integración HTTP con PostgreSQL, análisis y pruebas de widgets Flutter, build Flutter Web y revisión visual en navegador.

No publicado: backend, web, App Store y Google Play. Ya se generó e instaló una APK de depuración en Android; la firma de producción sigue pendiente. iOS requiere un equipo macOS con Xcode. Falta confirmar el flujo completo del escáner con cámara física.

La base actual ya está en Supabase; API y web siguen locales. La recuperación de contraseña y verificación de correo están implementadas. Configura el remitente SMTP y `APP_WEB_URL` HTTPS antes de publicar; consulta [correo de cuentas](account-email.md).

## API y PostgreSQL

1. Provisiona PostgreSQL con `btree_gist` disponible y una base exclusiva para la aplicación.
2. Define `DATABASE_URL`, un `JWT_SECRET` aleatorio, `CORS_ORIGINS` con dominios exactos de la web, `SHOP_TIMEZONE=America/Guayaquil`, `NODE_ENV=production` y el puerto. Usa secretos del proveedor; no reutilices la contraseña del ejemplo ni `SEED_PASSWORD`.
3. Construye `backend/Dockerfile`. Al iniciar ejecuta las migraciones y la API. La imagen incluye herramientas de Prisma para aplicarlas.
4. Publica detrás de HTTPS con proxy y healthcheck `/api/health`. Ajusta el manejo de IP del proxy y almacenamiento compartido de límites si escalas a múltiples instancias. El limitador actual es local a cada proceso.
5. Habilita copias de seguridad, restauración probada, monitoreo de errores y rotación de secretos. La rotación de `JWT_SECRET` invalida sesiones y QR vigentes.

Para comprobar el contenedor en desarrollo (con `.env` ya configurado):

```powershell
docker compose --profile app up --build -d
```

El Compose provisto es local; no es una configuración de hosting público. Incluye PostgreSQL, API con healthcheck y web estática en Nginx. Los tres puertos se exponen únicamente en loopback y los contenedores tienen reinicio `unless-stopped`. La web requiere `frontend/build/web` previamente compilado. En producción usa una red privada y credenciales propias.

### Crear administrador sin seed

En una terminal administrativa dentro de `backend`, define temporalmente `ADMIN_EMAIL`, `ADMIN_NAME` y `ADMIN_PASSWORD`, y ejecuta:

```powershell
npm.cmd run admin:create
```

La contraseña debe tener entre 12 y 72 bytes. El comando crea una cuenta nueva, no sobrescribe ni promueve usuarios existentes. Elimina las variables al terminar. Desde el panel de administrador se crean barberos y servicios.

## Web

```powershell
Set-Location frontend
flutter pub get
flutter build web --release --csp --dart-define=API_URL=https://api.tu-dominio.com/api
```

Publica `frontend/build/web` en un hosting estático con HTTPS y fallback de rutas a `index.html`. Configura el dominio en CORS. El script `scripts/preview.mjs` es para pruebas locales.

La lectura de QR en navegador necesita cámara y un contexto HTTPS o localhost. El cliente puede usar su QR sin otorgar permiso de cámara; el permiso se pide al activar el escáner del barbero. Consulta la [configuración del escáner](https://pub.dev/packages/mobile_scanner).

## Android

1. Revisa y acepta personalmente las licencias pendientes con `flutter doctor --android-licenses`.
2. Define el identificador definitivo de la app, nombre e íconos.
3. Crea un keystore de publicación y configura `signingConfigs` y `key.properties` fuera del control de versiones. La plantilla generada usa firma de debug: reemplázala antes de publicar.
4. Configura API HTTPS y genera `flutter build appbundle --release --dart-define=API_URL=https://api.tu-dominio.com/api`.
5. Valida reservas, permisos de cámara, escaneo, reconexión y vencimiento de sesión en dispositivos reales antes de subir a Play Console.

## iOS

1. En macOS instala Flutter, Xcode y sus herramientas. Abre el proyecto Runner y configura equipo de firma, Bundle ID y perfiles.
2. La explicación del permiso de cámara está en `ios/Runner/Info.plist`. Verifica que cumpla la identidad final del negocio.
3. Usa API HTTPS; no habilites excepciones globales de transporte.
4. Genera `flutter build ipa --release --dart-define=API_URL=https://api.tu-dominio.com/api`, valida en TestFlight y tramita la publicación desde App Store Connect.

## Decisiones para la siguiente iteración

Confirmar identidad visual, tarifas, horario real y qué servicios canjean el beneficio. La implementación inicial limita la tarjeta a diez sellos y pausa la acumulación hasta el canje. Para más sucursales o husos horarios, separar la configuración por local y adaptar la presentación horaria del frontend, que actualmente usa UTC−5.

Antes de uso público, concretar política de cancelación, privacidad y retención de datos del negocio. Recuperación y verificación de correo ya están implementadas; falta configurar un remitente real y decidir si el negocio exigirá verificar el correo antes de reservar. No se incluyen cobros en línea ni recordatorios de citas por correo/push.
