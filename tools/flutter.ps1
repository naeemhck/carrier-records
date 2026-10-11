$ErrorActionPreference = 'Stop'
$sdk = $env:FLUTTER_SDK
if (-not $sdk) {
    $settingsPath = Join-Path $env:APPDATA 'Code/User/settings.json'
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $sdk = $settings.'dart.flutterSdkPath'
    }
}
if (-not $sdk) { throw 'Set FLUTTER_SDK or configure dart.flutterSdkPath in VS Code.' }
$flutter = Join-Path $sdk 'bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Configured SDK lacks bin/flutter.bat.' }
$ErrorActionPreference = 'Continue'
& $flutter @args
exit $LASTEXITCODE
