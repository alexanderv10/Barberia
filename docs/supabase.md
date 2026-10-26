# Base de datos en Supabase

La instalación actual usa **Flutter → API NestJS local → PostgreSQL en Supabase**. La web y la API siguen en la computadora; solo la base se trasladó. Se conserva la autenticación JWT de NestJS, junto con las cuentas y sus contraseñas existentes. Los usuarios de la aplicación están en `public.User`, no en Supabase Auth.

## Conexión

Se utiliza el Session pooler en el puerto 5432, compatible con IPv4. Tanto `DATABASE_URL` en `backend/.env` como `DOCKER_DATABASE_URL` en el `.env` de la raíz apuntan a Supabase. Las contraseñas están únicamente en los archivos locales excluidos de Git.

Prisma usa `sslmode=require`, `sslaccept=strict` y `sslcert=certs/supabase-ca.crt`. La ruta del certificado se resuelve desde `backend/prisma`; ese certificado público se incluye en la imagen de la API. Se descargó desde Database Settings del proyecto. No es una clave privada. Al renovar el certificado, reemplaza el archivo y reconstruye la imagen.

La Data API de Supabase debe permanecer desactivada para esta configuración. Flutter consulta exclusivamente la API NestJS. RLS queda pendiente por decisión del proyecto; esta migración no configura políticas ni Supabase Auth.

## Transferencia realizada

Se respaldó la base original en formato `pg_dump` y se aplicaron las tres migraciones de Prisma sobre el destino vacío. Después se copiaron los cinco modelos en una transacción, manteniendo IDs, fechas, hashes de contraseñas, tarjetas y citas. Se verificó la igualdad del contenido completo de cada tabla mediante SHA-256 y la presencia de seis restricciones, incluidas las exclusiones de horarios.

Resultado inicial: 5 usuarios, 3 servicios, 2 tarjetas, 2 citas y 0 movimientos de sellos. Se probaron el inicio de sesión de los tres roles, la consulta de citas, la tarjeta del cliente y su QR, usando la API conectada a Supabase.

Los respaldos y los informes están en `artifacts/supabase-migration/`, excluido de Git. Contienen información sensible y deben conservarse localmente. La base PostgreSQL local y su volumen se mantuvieron como respaldo; no se sincronizan con Supabase.

Los scripts `prepare-supabase.ps1`, `check-supabase.mjs`, `migrate-supabase.mjs` y `activate-supabase.mjs` documentan la transferencia de esta instalación. Los dos últimos son de una sola ejecución: rechazan destinos ocupados o sobrescrituras de respaldos. No los vuelvas a ejecutar sobre una instalación ya migrada. No hace falta ejecutar el seed.

## Arranque y comprobación

Desde la raíz, con Docker Desktop abierto:

```powershell
.\scripts\start-local.ps1
node scripts/check-migrated-api.mjs
```

La comprobación utiliza la contraseña de demostración configurada localmente y no imprime contraseñas ni tokens. Si cambias esas contraseñas, comprueba el acceso manualmente con las cuentas actualizadas.

La web continúa en `http://localhost:8080` y la API en `http://localhost:3000/api`. La APK existente sigue usando esa API; por USB requiere mantener `adb reverse tcp:3000 tcp:3000`. Con esta configuración, la computadora y la API deben estar encendidas para usar la aplicación.

## Volver a la base local

Volver atrás recupera el estado previo a la transferencia: las nuevas operaciones realizadas en Supabase no aparecerán automáticamente en la base local. Detén primero la API, restaura las configuraciones guardadas y vuelve a iniciarla:

```powershell
docker compose --profile app stop api
Copy-Item -LiteralPath artifacts/supabase-migration/backend-before-supabase.env -Destination backend/.env
Copy-Item -LiteralPath artifacts/supabase-migration/compose-before-supabase.env -Destination .env
docker compose --profile app up -d --wait
```

Referencias: [conexión PostgreSQL y SSL](https://supabase.com/docs/guides/database/connecting-to-postgres), [Prisma con Supabase](https://supabase.com/docs/guides/database/prisma).
