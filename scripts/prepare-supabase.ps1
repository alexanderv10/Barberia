$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskDirectory = Join-Path $taskRoot 'artifacts/supabase-migration'
$taskConfigPath = Join-Path $taskDirectory 'connection.json'
if (-not (Test-Path -LiteralPath $taskConfigPath)) {
    throw 'Falta artifacts/supabase-migration/connection.json con los datos públicos de conexión.'
}
$taskConfig = Get-Content -LiteralPath $taskConfigPath -Raw | ConvertFrom-Json
if ($taskConfig.host -notmatch '^[a-zA-Z0-9.-]+\.supabase\.com$' -or $taskConfig.port -ne 5432 -or $taskConfig.database -ne 'postgres' -or $taskConfig.user -notmatch '^[a-zA-Z0-9_.-]+$') {
    throw 'Los datos de conexión no corresponden al Session pooler esperado.'
}

Write-Host 'Prepararemos la conexión a Supabase. Este comando no importa datos ni cambia la base usada por la app.'
$taskSecurePassword = Read-Host 'Introduce la contraseña de la BASE DE DATOS de Supabase (no se mostrará)' -AsSecureString
$taskPasswordPointer = [IntPtr]::Zero
$taskPlainPassword = $null
try {
    $taskPasswordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecurePassword)
    $taskPlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPasswordPointer)
    if ([string]::IsNullOrWhiteSpace($taskPlainPassword)) { throw 'La contraseña no puede estar vacía.' }
    $taskEncodedPassword = [Uri]::EscapeDataString($taskPlainPassword)
    $taskEncodedUser = [Uri]::EscapeDataString($taskConfig.user)
    $taskUrl = 'postgresql://' + $taskEncodedUser + ':' + $taskEncodedPassword + '@' + $taskConfig.host + ':5432/postgres?schema=public&sslmode=require&sslaccept=strict&connection_limit=3'
    $taskEnvPath = Join-Path $taskDirectory '.env'
    [IO.File]::WriteAllText($taskEnvPath, "SUPABASE_DATABASE_URL=$taskUrl`n", [Text.UTF8Encoding]::new($false))
    Write-Host 'Conexión guardada localmente en artifacts/supabase-migration/.env, excluido de Git.'
    Write-Host 'La base actual y sus datos permanecen intactos. Ya puedes volver al chat y decir: listo.'
} finally {
    if ($taskPasswordPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPasswordPointer) }
    $taskPlainPassword = $null
    $taskEncodedPassword = $null
    $taskUrl = $null
    $taskSecurePassword.Dispose()
}
