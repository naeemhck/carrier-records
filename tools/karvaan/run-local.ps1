param([ValidateSet('windows','chrome')][string]$Device='windows')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$defines=Join-Path $root 'tools/.local/karvaan-test-defines.json'
Push-Location $root
try {
    python tools/karvaan/local_environment.py check --defines $defines
    if ($LASTEXITCODE -ne 0) { throw 'Local boundary failed; app will not launch.' }
    Push-Location (Join-Path $root 'app')
    try {
        & (Join-Path $root 'tools/flutter.ps1') run -d $Device --dart-define-from-file=$defines --dart-define=KARVAAN_LOCAL_ONLY=true --dart-define=use_arabic=true
        if ($LASTEXITCODE -ne 0) { throw 'Candidate run failed.' }
    } finally { Pop-Location }
} finally { Pop-Location }
