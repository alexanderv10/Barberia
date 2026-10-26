# API REST

Prefijo `/api`. JSON. Usa `Authorization: Bearer <accessToken>` excepto en registro, login, health, información comercial, catálogo activo y directorio público de barberos. Los identificadores son UUID. Los errores tienen el formato HTTP de NestJS con `statusCode`, `message` y `error`.

| Método | Ruta | Acceso | Resultado |
| --- | --- | --- | --- |
| GET | /health | Público | Comprueba API y PostgreSQL |
| GET | /shop | Público | Nombre, descripción, horarios, zona, dirección y teléfono del negocio |
| POST | /auth/register | Público | Crea cliente + tarjeta y devuelve sesión |
| POST | /auth/login | Público | Devuelve sesión JWT |
| GET | /auth/me | Sesión | Perfil sin datos de contraseña |
| GET | /users/barbers | Público | Barberos activos (solo id y nombre; no correos) |
| POST | /users/barbers | ADMIN | Crea cuenta BARBER |
| GET | /services | Público | Catálogo activo |
| GET | /services/manage | ADMIN | Catálogo incluyendo inactivos |
| POST | /services | ADMIN | Crea servicio |
| PATCH | /services/:id | ADMIN | Actualiza todos los campos de servicio |
| GET | /appointments/availability | Sesión | Franjas libres para fecha, servicio y barbero |
| GET | /appointments | Sesión | Cliente: sus citas; barbero: su agenda; admin: todas |
| POST | /appointments | CLIENT | Reserva sin traslapes |
| PATCH | /appointments/:id/accept | BARBER asignado / ADMIN | Registra aceptación de cita pendiente |
| PATCH | /appointments/:id/cancel | Propietario / BARBER asignado / ADMIN | Cancela cita pendiente |
| GET | /stamps/card | CLIENT | Tarjeta, beneficio y últimos 20 movimientos |
| GET | /stamps/qr | CLIENT | QR firmado, `expiresIn: 300` |
| POST | /stamps/scan | BARBER / ADMIN | Valida QR y muestra citas que puede completar |
| POST | /stamps/complete | BARBER asignado / ADMIN | Completa cita y otorga sello o canjea beneficio |

## Cuerpos

Registro (`name` solo en registro) y login:

```json
{"name":"Alex Moreno","email":"alex@example.com","password":"UnaClaveSegura2026!"}
```

La creación de un barbero usa esos tres campos. No acepta roles aportados por el cliente. Las contraseñas usan bcrypt con coste 12 y límite de 72 bytes UTF-8. Login/registro: diez solicitudes por minuto y dirección IP. Por IP y endpoint, escanear QR permite 30/minuto, completar visitas 20/minuto, healthcheck 60/minuto y las demás rutas 120/minuto.

Sesión:

```json
{"accessToken":"...","user":{"id":"uuid","name":"Alex Moreno","email":"alex@example.com","role":"CLIENT"}}
```

Disponibilidad:

```text
GET /api/appointments/availability?barberId=<uuid>&serviceId=<uuid>&date=2026-10-26
```

Devuelve `{"timezone":"America/Guayaquil","slots":["2026-10-26T14:00:00.000Z"]}`. La consulta también excluye conflictos del cliente autenticado. La reserva revalida dentro de una transacción; una franja consultada no se retiene.

Reserva:

```json
{"barberId":"uuid","serviceId":"uuid","startsAt":"2026-10-26T14:00:00.000Z","isReward":false}
```

`startsAt` debe incluir `Z` o desplazamiento explícito. El servidor calcula fin y precio; rechaza campos extra. `isReward` es opcional.

Crear/editar servicio (todos los campos requeridos):

```json
{"name":"Corte clásico","description":"Corte y acabado","durationMin":30,"priceCents":1200,"rewardEligible":true,"active":true}
```

Escanear y completar:

```json
{"qrToken":"token-firmado-de-la-tarjeta"}
```

```json
{"qrToken":"token-firmado-de-la-tarjeta","appointmentId":"uuid"}
```

Completar devuelve `currentStamps`, `rewardAvailable`, `redeemed` y `stampAwarded`. Si el contador ya está en diez y el servicio es pagado, se completa sin sumar más; el beneficio existente se conserva.

## Errores esperados

- `400`: entrada inválida, fecha fuera de horario, QR inválido/expirado o beneficio no disponible.
- `401`: sesión ausente, expirada o cuenta inactiva.
- `403`: rol o propiedad incorrectos.
- `404`: tarjeta, cita o servicio inexistente.
- `409`: horario ocupado, canje pendiente duplicado, correo existente o cita ya procesada. Refresca antes de reintentar.
- `429`: límite de solicitudes excedido.

## Integridad

`User` tiene una `LoyaltyCard` por cliente. `Appointment` enlaza cliente, barbero y servicio; `StampEvent` enlaza tarjeta, cita y operador. El historial de sellos no expone contraseñas ni JWT.

Las migraciones incluyen restricciones `CHECK`, dos exclusiones GiST para intervalos `[inicio, fin)` y un índice parcial para el único regalo pendiente. Deben aplicarse con `prisma migrate deploy`; **no sustituyas las migraciones por `prisma db push`**, que no representa las restricciones personalizadas del esquema SQL. La implementación sigue el soporte de [rangos y exclusiones de PostgreSQL](https://www.postgresql.org/docs/17/rangetypes.html) y las [migraciones personalizadas de Prisma](https://www.prisma.io/docs/orm/v7/prisma-migrate/workflows/customizing-migrations).
