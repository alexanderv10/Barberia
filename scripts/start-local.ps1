$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'backend/.env'))) {
    throw 'Configura backend/.env siguiendo README.md.'
}
if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'frontend/build/web/index.html'))) {
    throw 'Primero compila la web: cd frontend; flutter build web --release'
}
Push-Location $taskRoot
try {
    node scripts/configure-web.mjs
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron generar las cabeceras de seguridad web.' }
    docker compose --profile app up -d --build --wait
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar la aplicación. Comprueba Docker Desktop y ejecuta docker compose --profile app logs --tail 30.' }
    docker compose --profile app exec -T web nginx -t
    if ($LASTEXITCODE -ne 0) { throw 'La configuración de seguridad de Nginx no es válida.' }
    docker compose --profile app exec -T web nginx -s reload
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo recargar la configuración de Nginx.' }
    Write-Host 'Barbería disponible en http://localhost:8080'
    Write-Host 'Los contenedores siguen activos al cerrar la terminal. Para detenerlos: docker compose --profile app stop'
} finally { Pop-Location }
