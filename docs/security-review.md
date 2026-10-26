# Revisión de seguridad — 25 de octubre de 2026

Alcance: API NestJS, Prisma/PostgreSQL, configuración Docker, Flutter Web y servidor de vista previa. Es una revisión de los siete controles solicitados, no una certificación ni una prueba de penetración completa.

| Punto | Estado después de la revisión | Evidencia |
| --- | --- | --- |
| 1. Secretos en variables de entorno | Reforzado | JWT, URL de BD, contraseña de PostgreSQL y contraseña del seed provienen del entorno. Se eliminaron las contraseñas por defecto de Compose y del ejemplo del seed. `.env` y `backend/.env` están ignorados y excluidos de la imagen. El JWT rechaza secretos cortos o el placeholder. |
| 2. CORS restringido | Configurado y probado | Lista exacta en `CORS_ORIGINS`; sin comodines, credenciales de navegador ni rutas. Origen no autorizado: 403. Se conserva el acceso sin `Origin` necesario para Android/iOS. |
| 3. Validación backend | Configurada y reforzada | DTO con tipos, UUID, fechas, límites, rangos y campos permitidos. `ValidationPipe` global rechaza campos extra. Límite JSON de 16 KiB. Se validan también propiedad de las citas, horario, disponibilidad y condiciones del beneficio. |
| 4. Normalización y texto plano | Añadido | Nombre y descripción se normalizan en Unicode NFC; se recortan espacios y se normalizan saltos de línea. Se rechazan etiquetas y controles ocultos. Emails se recortan y convierten a minúsculas. Contraseñas, JWT y QR no se modifican. |
| 5. Rate limiting | Configurado y probado | Global: 120/minuto por IP y endpoint. Login/registro: 10/minuto. Escaneo QR: 30/minuto. Completar visita: 20/minuto. Healthcheck: 60/minuto (el monitor local consulta 12/minuto). Respuesta 429 al exceder límites. |
| 6. Row Level Security | **No activo; pendiente antes de endurecer el despliegue público** | Se consultó `pg_class`: las tablas no tienen RLS. El rol actual de BD tiene `rolsuper=true` y `rolbypassrls=true`. El aislamiento actual lo aplica la API, no PostgreSQL. |
| 7. Content Security Policy | Añadida a la web | Cabecera CSP en Nginx y en `preview.mjs`, compartida mediante `security-headers.json`. Scripts propios y una URL exacta y versionada del decodificador QR. Sin `unsafe-inline` ni `unsafe-eval` en scripts. Flutter se compila con `--csp` y CanvasKit local. |

## Interpretación de los controles

**CORS no demuestra que una petición venga de nuestra app.** Es un control del navegador; una app nativa o un cliente HTTP puede no enviar `Origin` o falsificarlo. JWT, verificación del usuario activo, roles y comprobaciones de propiedad siguen siendo la autorización real. Las rutas de catálogo, equipo e información comercial permanecen públicas por diseño. [Referencia de CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS).

**Sanitizar no equivale a eliminar todos los símbolos.** Los nombres admiten acentos y apóstrofes como `O'Connor`. La aplicación guarda texto plano, no contenido HTML. Se rechaza el marcado en lugar de intentar corregirlo. Prisma usa parámetros en las consultas; no se construye SQL concatenando entradas. Flutter muestra estos campos con widgets de texto, no con HTML. Si se añade un editor HTML, será necesario un sanitizador de HTML específico y codificación de salida apropiada. [Guía OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html).

**CSP tiene excepciones explícitas para Flutter:** `wasm-unsafe-eval` permite compilar WebAssembly, sin permitir evaluación arbitraria de cadenas JavaScript. Los estilos requieren `unsafe-inline` para el motor. Solo se autoriza el script de `zxing-wasm@3.1.3` en su ruta concreta; actualizar el paquete obliga a revisar esta regla. Fonts de respaldo se limitan a `fonts.gstatic.com`. `connect-src` incluye únicamente los dos orígenes locales de la API, recursos del propio sitio, fuentes y la ruta versionada de WASM. Antes de publicar hay que sustituir los orígenes locales por el dominio HTTPS real de la API. [Configuración del motor Flutter](https://docs.flutter.dev/platform-integration/web/initialization).

## Pendiente específico de RLS y roles de BD

Los superusuarios y los roles `BYPASSRLS` omiten RLS; activar solo la bandera en las tablas actuales daría una falsa garantía. [Documentación PostgreSQL](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).

Implementación necesaria para una capa RLS efectiva:

1. Separar credenciales del migrador/propietario y del usuario de ejecución. El usuario de ejecución no debe ser superusuario, propietario ni tener `BYPASSRLS`.
2. Propagar la identidad verificada por JWT a cada transacción de Prisma mediante contexto local de transacción, sin dejar estado reutilizable en el pool.
3. Definir políticas para clientes, barberos asignados y administradores en citas, tarjetas y movimientos. La disponibilidad debe poder consultar ocupación sin revelar clientes; autenticación, registro, catálogo y tareas administrativas necesitan alcances propios.
4. Probar consultas SQL sin filtros desde el usuario de ejecución, concurrencia, reutilización de conexiones y operaciones de sellos/canjes. Después, habilitar y forzar políticas con migración.

En esta revisión se verificó el aislamiento actual mediante HTTP: un cliente no lista ni cancela las citas ajenas; otro barbero no obtiene la tarjeta mediante un QR sin citas asignadas disponibles y no completa citas ajenas. **Estas pruebas no constituyen RLS ni sustituyen la separación de privilegios de BD.**

## Configuración y ejecución

- Los archivos `.env.example` contienen placeholders, no credenciales de producción. Para un entorno nuevo configura tanto `.env` de la raíz como `backend/.env`, con las URLs apropiadas para Docker y para el host. No cambies únicamente `POSTGRES_PASSWORD` sobre un volumen existente: eso no rota la contraseña ya guardada en PostgreSQL.
- La configuración local existente se conservó; no se cambiaron las contraseñas de las cuentas de demostración ni se borraron datos. Esas cuentas conocidas no deben usarse en producción.
- El limitador conserva contadores en memoria de cada proceso. Para varias réplicas hace falta almacenamiento compartido y configurar correctamente el proxy; no confiar en `X-Forwarded-For` aportado por cualquier cliente.
- El tráfico local de pruebas permite HTTP, incluida la APK debug por USB. Publicación: HTTPS y firma móvil propios; no usar credenciales de prueba.
- El repositorio no incluye secretos reales en los assets de Flutter. `API_URL` es una dirección pública de servicio, no una clave.

Pruebas:

```powershell
Set-Location backend
npm.cmd run build
npm.cmd test
# Con TEST_DATABASE_URL apuntando a una base aislada terminada en _test:
npm.cmd run test:integration
Set-Location ..
node scripts/configure-web.mjs
node --test scripts/security.test.mjs
Set-Location frontend
flutter build web --release --csp
```

El arranque `scripts/start-local.ps1` genera las cabeceras, valida Nginx y recarga su configuración. Los cambios solo del backend/CSP no requieren reinstalar la APK Android.
