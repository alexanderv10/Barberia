# Barbería

Aplicación de reservas y fidelización: **Flutter (Android, iOS y Web) → NestJS REST → PostgreSQL + Prisma**.

Esta entrega es un MVP integrado para desarrollo local. Incluye cuentas de cliente/barbero/administrador, reservas, confirmación y cancelación, agenda, tarjeta de diez sellos, QR temporal, escáner y administración de servicios/equipo. La publicación en hosting y tiendas no se ha realizado.

La instalación actual tiene la **base de datos en Supabase**; la API NestJS y Flutter siguen ejecutándose localmente. Consulta [la conexión, el respaldo y la recuperación](docs/supabase.md). Las instrucciones desde cero de abajo describen una instalación con PostgreSQL local.

Incluye [recuperación de contraseña y verificación de correo](docs/account-email.md), con envío SMTP real o buzón local de pruebas. Para configurar un Gmail remitente utiliza `scripts/configure-gmail.ps1`; sus credenciales permanecen fuera de Git.

## Ver la aplicación

Si el login muestra un error de conexión, comprueba que la API esté encendida. Con dependencias y compilaciones ya preparadas, puedes iniciar PostgreSQL, API y web en segundo plano desde la raíz:

```powershell
.\scripts\start-local.ps1
```

Necesita Docker Desktop abierto. Compila la imagen de la API y arranca PostgreSQL, API y web en contenedores que permanecen activos al terminar el chat o cerrar la terminal. Puedes consultar errores con `docker compose --profile app logs --tail 30` y detenerlos con `docker compose --profile app stop`. Si vas a usar el arranque manual de abajo, detén antes los contenedores `api` y `web` para liberar los puertos: `docker compose --profile app stop api web`.

Con el servidor de vista previa iniciado, abre **http://localhost:8080**. El inicio es público: muestra servicios, precios, horarios, equipo y datos de contacto, sin consultar citas ni tarjetas personales. Desde **Iniciar sesión** puedes acceder a tu cuenta o explorar **Demo cliente** y **Demo barbero**. La franja amarilla identifica la demostración: utiliza datos en memoria y no guarda reservas reales.

Al pulsar **Reservar una cita** o elegir un servicio sin sesión, se solicita iniciar sesión o registrarse. Después del acceso como cliente se abre el formulario de reserva, conservando el servicio seleccionado. Al cerrar sesión se regresa al inicio público. Los sellos, QR y citas solo aparecen dentro de la cuenta.

Configura `SHOP_NAME`, `SHOP_ADDRESS` y `SHOP_PHONE` en `backend/.env` y reinicia la API para mostrar los datos reales del negocio. La dirección y el contacto vacíos se presentan como **por confirmar**. Esta información también está disponible en el inicio del cliente autenticado.

En una instalación nueva de desarrollo, `db:seed` permite crear las siguientes cuentas de ejemplo. No se crean automáticamente y pueden haberse eliminado en una instalación ya configurada:

| Perfil | Correo |
| --- | --- |
| Cliente | cliente@barberia.local |
| Barbero | mateo@barberia.local |
| Barbero | lucas@barberia.local |
| Administrador | admin@barberia.local |

La contraseña es el valor de `SEED_PASSWORD` usado al crear las cuentas. El ejemplo de configuración deja ese valor vacío para que elijas uno propio en una instalación nueva. El registro público siempre crea un **CLIENT**. El seed es explícito, no cambia cuentas existentes y está bloqueado cuando `NODE_ENV=production`.

## Ejecutar desde cero (PowerShell)

Requisitos: Node.js 24, Flutter estable compatible con Dart 3.11, Docker Desktop en ejecución.

Desde la raíz:

```powershell
Copy-Item .env.example .env
Copy-Item backend/.env.example backend/.env
```

Antes de iniciar PostgreSQL, configura las credenciales en `.env` de la raíz (`POSTGRES_PASSWORD` y `DOCKER_DATABASE_URL`), y en `backend/.env` (`DATABASE_URL` para localhost, `JWT_SECRET` aleatorio de al menos 32 caracteres, `CORS_ORIGINS` y `SEED_PASSWORD` para las cuentas de desarrollo). Después ejecuta `docker compose up -d db`. No subas estos archivos a Git. Si ya existen, consérvalos y no los sobrescribas.

API (primera terminal):

```powershell
Set-Location backend
npm.cmd ci
npm.cmd run db:generate
npm.cmd run db:migrate
npm.cmd run db:seed
npm.cmd run build
npm.cmd start
```

Frontend (segunda terminal, desde la raíz):

```powershell
Set-Location frontend
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_URL=http://localhost:3000/api
```

Para revisar un build web sin modo de desarrollo:

```powershell
Set-Location frontend
flutter build web --release --csp --dart-define=API_URL=http://localhost:3000/api
Set-Location ..
node scripts/preview.mjs
```

La API responde en `http://localhost:3000/api`; `GET /api/health` comprueba conexión a PostgreSQL. CORS permite los orígenes de `CORS_ORIGINS`.

### Android / iOS

Las carpetas nativas y permisos de cámara están generados. En el emulador Android usa `--dart-define=API_URL=http://10.0.2.2:3000/api`. El manifiesto **debug** permite HTTP local; release debe usar HTTPS. Para un teléfono físico usa una API accesible desde el dispositivo y el permiso de red correspondiente. iOS requiere macOS/Xcode y una API HTTPS. Revisa [despliegue](docs/deployment.md).

## Cambiar los colores

`frontend/lib/theme.dart` concentra `AppColors` y el tema Material. Paleta provisional: blanco, gris oscuro y verde suave. Los tonos de apoyo ilustrativos están en las pantallas de acceso, inicio y tarjeta. Al definir la identidad final, actualiza también el manifiesto web y los íconos nativos.

## Reglas de esta versión

- Un local, USD, hora comercial `America/Guayaquil` (UTC−5), lunes–sábado de 09:00 a 19:00. Franjas de inicio cada 30 minutos, con duración real por servicio y máximo 60 días de anticipación. El cliente ve siempre la hora de Ecuador, aunque su dispositivo esté en otra zona.
- Reservar ocupa inmediatamente el horario. El barbero asignado o el administrador puede **aceptar** la cita; se registra `acceptedAt` manteniendo el estado `PENDING` hasta completarla o cancelarla.
- No se permiten traslapes para el barbero **ni para el cliente**. Las restricciones SQL cubren citas pendientes y completadas; las canceladas liberan el horario. Los intervalos adyacentes sí se permiten.
- Precios y duración quedan fijados al reservar mediante `priceCents`, `startsAt` y `endsAt`. Editar el catálogo no cambia esas condiciones de citas existentes.
- El cliente tiene una tarjeta única. Su QR firmado identifica la tarjeta y vence en cinco minutos; la pantalla lo renueva cada cuatro minutos. El token de acceso no sirve como QR y viceversa.
- Solo el barbero asignado o el administrador completa un servicio, después de validar el QR del cliente y de que la cita haya comenzado. No hay un endpoint para sumar sellos arbitrariamente.
- Una cita pagada completada genera **un sello**, hasta el límite de diez. Con diez, el beneficio queda disponible y se pausa la acumulación hasta canjearlo. Solo se permite una reserva de regalo pendiente por cliente.
- El regalo se reserva eligiendo un servicio elegible y activando **Usar mi corte gratis**. Los diez sellos se descuentan al completar ese servicio, no al reservarlo; cancelar conserva el beneficio. El regalo no genera sello.
- Completar, actualizar tarjeta y registrar movimiento ocurre en una transacción serializable. `StampEvent.appointmentId` es único y los bloqueos de concurrencia se reintentan. El historial registra quién realizó el movimiento.
- La agenda muestra hasta las 500 citas más recientes por ámbito de acceso. Usa filtros de estado, fecha y nombre.
- Las sesiones duran ocho horas y se conservan en memoria, sin almacenamiento persistente del JWT. Al recargar el navegador se solicita iniciar sesión nuevamente.

## Pruebas

Backend:

```powershell
Set-Location backend
npm.cmd test
npm.cmd run build
npm.cmd audit --audit-level=high
```

Integración con PostgreSQL separado (desde la raíz, una vez):

```powershell
docker compose exec -T db createdb -U barberia barberia_test
Set-Location backend
$env:DATABASE_URL = 'postgresql://barberia:CHANGE_ME@localhost:5432/barberia_test?schema=public'
$env:TEST_DATABASE_URL = $env:DATABASE_URL
npm.cmd run db:migrate
npm.cmd run test:integration
Remove-Item Env:DATABASE_URL
Remove-Item Env:TEST_DATABASE_URL
```

La integración exige una base cuyo nombre termine en `_test`. Crea y elimina únicamente sus propias entidades. Verifica JWT, protección de roles, aceptación de citas, administración, cinco carreras de reservas, restricciones SQL, QR expirado, duplicación de sellos, canje y cancelación.

Flutter:

```powershell
Set-Location frontend
flutter analyze
flutter test
flutter build web --release --csp
```

Las pruebas de widgets cubren navegación móvil, tarjeta, formulario de reserva y validación/completado mediante QR de demostración en escritorio. El acceso a cámara real requiere comprobación en dispositivos.

## Estructura

```text
backend/
  prisma/                 Esquema, migraciones SQL y seed explícito
  src/auth/               Registro, login y perfil con JWT
  src/users/              Directorio y creación de barberos
  src/appointments/       Disponibilidad, reservas, aceptación y cancelación
  src/stamps/             Tarjeta, QR, escaneo y completado con sellos/canje
  src/services/           Catálogo y administración
  test/                   Reglas de horario e integración con PostgreSQL
frontend/
  lib/data/               Cliente REST, sesión y demostración
  lib/screens/            Acceso, inicio, reservas, agenda, sellos, escáner y administración
  lib/theme.dart          Paleta y tema
docs/                     Contrato API y despliegue
compose.yaml              PostgreSQL y perfil opcional de API en contenedor
```

Documentación: [API](docs/api.md) · [Despliegue y pendientes](docs/deployment.md).

Seguridad: [revisión de los siete controles, pruebas y pendiente de RLS](docs/security-review.md). Compila la web con `flutter build web --release --csp`; las cabeceras se mantienen en `scripts/security-headers.json`.
