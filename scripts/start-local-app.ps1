[CmdletBinding()]
param([ValidateSet('web-server', 'chrome', 'windows')][string]$Device = 'web-server')

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $workspace
try {
    try {
        $emulators = Invoke-RestMethod -Uri 'http://127.0.0.1:4400/emulators' -TimeoutSec 3
        if (-not $emulators.auth -or -not $emulators.firestore -or -not $emulators.functions) {
            throw 'Missing required emulators.'
        }
    } catch {
        throw 'Start the backend in another terminal first: .\scripts\start-local-backend.ps1'
    }
    $flutterArguments = @('run', '-d', $Device, '--dart-define=USE_FIREBASE_EMULATORS=true')
    if ($Device -ne 'windows') {
        $flutterArguments += @('--web-port=54321', '--web-hostname=127.0.0.1')
    }
    Write-Host 'LOCAL mode: use local test accounts, separate from your live Firebase account.'
    Write-Host 'Web app and invitations: http://127.0.0.1:54321/'
    & flutter.bat @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
}
