[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $workspace
try {
    if (-not (Test-Path 'functions/node_modules/firebase-functions')) {
        throw 'Install backend dependencies first: npm.cmd --prefix functions ci'
    }
    $localJava = Get-ChildItem -LiteralPath (Join-Path $workspace '.local/challenge-jre') -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin/java.exe') } | Select-Object -First 1
    if ($localJava) {
        $env:JAVA_HOME = $localJava.FullName
        $env:PATH = "$(Join-Path $localJava.FullName 'bin');$env:PATH"
    }
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        throw 'Java 21 or newer is required for the Firebase emulators. Install it or set JAVA_HOME and PATH.'
    }
    $dataDirectory = Join-Path $workspace '.local/firebase-data'
    $firebaseArguments = @('emulators:start', '--project', 'demo-flow-lens-challenges',
        '--only', 'auth,firestore,functions', '--export-on-exit', $dataDirectory)
    if (Test-Path (Join-Path $dataDirectory 'firebase-export-metadata.json')) {
        $firebaseArguments += @('--import', $dataDirectory)
    }
    Write-Host 'Starting local accounts, database, and challenges. Emulator UI: http://127.0.0.1:4000'
    Write-Host 'Use Ctrl+C once to stop and save test data. No production project is used.'
    & firebase.cmd @firebaseArguments
    if ($LASTEXITCODE -ne 0) { throw "Firebase emulators exited with code $LASTEXITCODE." }
} finally {
    Pop-Location
}
