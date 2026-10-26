# Recuperación de contraseña y verificación de correo

La autenticación sigue en NestJS, también con la base alojada en Supabase. No se utiliza Supabase Auth. La migración `202610250004_account_email` añade el estado de verificación, la versión de sesión y los tokens de cuenta; no cambia las contraseñas existentes ni marca direcciones como verificadas automáticamente.

## Uso

- En el acceso aparece **¿Olvidaste tu contraseña?**. Envía un enlace que permite elegir y confirmar una nueva contraseña. Al completarlo se invalidan las sesiones JWT previas y los demás enlaces de esa cuenta.
- El registro envía automáticamente un enlace de verificación. **Mi cuenta** muestra el estado y permite reenviar el mensaje y actualizar el estado después de verificarlo. Al registrarse se informa si el correo no pudo enviarse.
- Abrir un enlace de verificación muestra una pantalla de confirmación; una petición GET o un analizador de enlaces de correo no consume el token.
- La verificación registra la propiedad del correo, pero en esta entrega no bloquea reservas ni el acceso de cuentas pendientes. Esto conserva el funcionamiento de las cuentas de demostración. Si el negocio decide hacerla obligatoria, debe aplicarse también en el backend.
- Las direcciones de demostración `@barberia.local` no son buzones reales. Para comprobar recepción por Gmail, registra una cuenta con un correo real. No cambies directamente un email en la BD sin invalidar su verificación y sus enlaces.

## Buzón local de pruebas

Con `MAIL_MODE=local`, los mensajes se capturan en Mailpit y **no salen a Internet**. Con Docker Desktop abierto, inicia la aplicación con `scripts/start-local.ps1` y abre `http://localhost:8025` para verlos. El SMTP de Mailpit usa el puerto 1025 y su panel el 8025, ambos publicados solo en loopback. Los mensajes son temporales; no se incluye un volumen persistente. Una instalación configurada con `MAIL_MODE=smtp` envía mediante su proveedor real y no utiliza este buzón.

Para configurar manualmente una API dentro de Compose:

```dotenv
APP_WEB_URL=http://localhost:8080
MAIL_MODE=local
MAIL_FROM=barberia@example.test
SMTP_HOST=mailpit
SMTP_PORT=1025
```

Si ejecutas NestJS directamente en la computadora, cambia `SMTP_HOST` a `127.0.0.1`. Para levantar solo el buzón: `docker compose --profile mail up -d mailpit`.

## Usar un Gmail personal como remitente

Activa la verificación en dos pasos en esa cuenta y crea una contraseña de aplicación en Google. Su disponibilidad depende de la configuración de la cuenta. No uses la contraseña habitual ni compartas la clave de aplicación en el chat.

Desde la raíz, ejecuta:

```powershell
.\scripts\configure-gmail.ps1
```

El script pide correo y contraseña de aplicación de forma local, conserva un respaldo ignorado por Git de la configuración anterior, guarda los datos solo en `backend/.env` y recrea la API. Configura `smtp.gmail.com:587` con STARTTLS obligatorio y validación del certificado. Para otro proveedor, utiliza sus parámetros SMTP en las variables de entorno; no todos admiten contraseñas de aplicación.

Configuración equivalente:

```dotenv
APP_WEB_URL=https://tu-web.example
MAIL_MODE=smtp
MAIL_FROM=tu-cuenta@gmail.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu-cuenta@gmail.com
SMTP_PASSWORD=tu-contraseña-de-aplicación
```

Los enlaces apuntan a `APP_WEB_URL`, nunca al dominio proporcionado en una petición entrante. En desarrollo `localhost` solo funciona en la computadora donde se ejecuta la web: abre allí el correo. Para abrir los enlaces desde cualquier teléfono, publica la web y configura su URL HTTPS; los enlaces actuales abren Flutter Web, no una ruta nativa de la APK. Para ver estas pantallas dentro de la aplicación Android, recompila e instala la APK actualizada.

## Seguridad y límites

Se generan tokens aleatorios de 256 bits. La BD guarda solo su SHA-256, propósito, vencimiento y fecha de consumo. Verificación: 24 horas. Recuperación: 30 minutos. Reenviar invalida los enlaces anteriores del mismo propósito. El consumo y el cambio de estado se realizan en una transacción con bloqueo por usuario para impedir usos simultáneos.

Se permite como máximo un correo de cada propósito por minuto y cinco por hora por cuenta, además de los límites HTTP por IP. Recuperación responde con el mismo mensaje y estado para cuentas ausentes, inactivas y fallos de envío; no confirma si la dirección está registrada. Los fallos SMTP se registran sin credenciales, destinatarios ni enlaces. No hay una cola persistente ni reintentos automáticos: se informa del problema en registro/reenvío y se permite solicitar un nuevo mensaje.

Los tokens van en el fragmento del enlace, por lo que no llegan en la URL solicitada al servidor web. La pantalla los envía mediante POST a la API. La web conserva `Referrer-Policy: no-referrer`. En producción tanto la web como la API deben usar HTTPS.

`MAIL_MODE=disabled` desactiva el envío explícitamente. Nunca se devuelve un enlace privado en la respuesta de la API para suplir un error de correo. La verificación de TLS no se desactiva para SMTP real.

## Validación

`node scripts/test-local-backend.mjs` aplica las migraciones y ejecuta las pruebas de integración contra `barberia_test` local, independientemente de la base configurada en la aplicación. Necesita esa base creada y PostgreSQL local en ejecución. Con el backend compilado y Mailpit activo, `node scripts/test-account-mail.mjs` verifica la entrega SMTP y los enlaces reales usando una cuenta temporal en esa base aislada.

Las pruebas Flutter incluyen recuperación desde login, confirmación de contraseña, limpieza de sesión y verificación sin consumo automático al abrir el enlace.

Referencias: [contraseñas de aplicación de Google](https://support.google.com/mail/answer/185833), [SMTP de Gmail](https://developers.google.com/workspace/gmail/imap/imap-smtp), [transporte SMTP de Nodemailer](https://nodemailer.com/smtp).
