$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEnvPath = Join-Path $taskRoot 'backend/.env'
if (-not (Test-Path -LiteralPath $taskEnvPath)) { throw 'Configura primero backend/.env.' }
Write-Host 'Conectaremos un Gmail como remitente. Usa una contraseña de aplicación de Google, no tu contraseña de acceso.'
Write-Host 'Primero escribe tu dirección Gmail completa (ejemplo: tunombre@gmail.com). La clave se pide después en un campo oculto.'
$taskEmail = (Read-Host 'Dirección de correo Gmail, NO la clave').Trim()
if ($taskEmail -notmatch '^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$') { throw 'Ingresa una dirección de correo válida.' }
$taskSecurePassword = Read-Host 'Contraseña de aplicación de Google (16 caracteres; no se mostrará)' -AsSecureString
$taskPointer = [IntPtr]::Zero
try {
    $taskPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($taskSecurePassword)
    $taskPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($taskPointer).Replace(' ', '')
    if ($taskPassword -notmatch '^[a-zA-Z0-9]{16}$') { throw 'Se espera una contraseña de aplicación de Google de 16 caracteres.' }
    $taskText = [IO.File]::ReadAllText($taskEnvPath)
    $taskBackupDirectory = Join-Path $taskRoot 'artifacts/account-email'
    [IO.Directory]::CreateDirectory($taskBackupDirectory) | Out-Null
    $taskBackupPath = Join-Path $taskBackupDirectory ('backend-before-gmail-' + [Guid]::NewGuid().ToString('N') + '.env')
    [IO.File]::WriteAllText($taskBackupPath, $taskText, [Text.UTF8Encoding]::new($false))
    $taskValues = @{
        MAIL_MODE = 'smtp'; MAIL_FROM = $taskEmail; SMTP_HOST = 'smtp.gmail.com'; SMTP_PORT = '587'; SMTP_USER = $taskEmail; SMTP_PASSWORD = $taskPassword
    }
    if ($taskText -notmatch '(?m)^APP_WEB_URL=.+') { $taskValues['APP_WEB_URL'] = 'http://localhost:8080' }
    foreach ($taskEntry in $taskValues.GetEnumerator()) {
        $taskPattern = '(?m)^' + [Regex]::Escape($taskEntry.Key) + '=.*$'
        $taskLine = $taskEntry.Key + '=' + $taskEntry.Value
        if ([Regex]::IsMatch($taskText, $taskPattern)) {
            $taskReplacement = $taskLine
            $taskText = [Regex]::Replace($taskText, $taskPattern, [Text.RegularExpressions.MatchEvaluator]{ param($taskMatch) $taskReplacement })
        } else { $taskText = $taskText.TrimEnd() + "`n" + $taskLine + "`n" }
    }
    [IO.File]::WriteAllText($taskEnvPath, $taskText, [Text.UTF8Encoding]::new($false))
    Write-Host 'Remitente guardado en backend/.env, excluido de Git. Reiniciaremos la API.'
} finally {
    if ($taskPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($taskPointer) }
    $taskPassword = $null; $taskText = $null; $taskLine = $null; $taskReplacement = $null; $taskValues = $null
    $taskSecurePassword.Dispose()
}
Push-Location $taskRoot
try {
    docker compose --profile app up -d --force-recreate --wait api
    if ($LASTEXITCODE -ne 0) { throw 'La configuración está guardada, pero no se pudo reiniciar la API. Comprueba Docker Desktop.' }
    Write-Host 'Gmail configurado. Prueba registrando una cuenta con un correo real y revisa también spam.'
    Write-Host 'Los enlaces apuntan a APP_WEB_URL. Si usas localhost, abre el enlace en esta computadora.'
} finally { Pop-Location }
