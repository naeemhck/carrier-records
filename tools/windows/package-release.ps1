param([Parameter(Mandatory=$true)][string]$Compiler)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
throw 'Karvaan local-only branch: shipping packaging is disabled. Use the separately guarded local candidate package workflow; never install it over production.'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
if ((Get-AuthenticodeSignature -LiteralPath $compilerPath).Status -ne 'Valid') {
    throw 'A valid signed Inno Setup compiler is required.'
}
$pubspec = Get-Content -LiteralPath (Join-Path $root 'app/pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$') {
    throw 'Expected explicit semantic version and build number.'
}
$version = $Matches[1]; $build = $Matches[2]
$release = Join-Path $root 'app/build/windows/x64/runner/Release'
$output = Join-Path $root "app/build/windows/installer/$version+$build"
# Never replace an earlier artifact/evidence directory.
if (Test-Path -LiteralPath $output) { throw "Output exists; preserve it: $output" }
Push-Location (Join-Path $root 'app')
try {
    & (Join-Path $root 'tools/flutter.ps1') build windows --release --no-pub --dart-define=APP_ENV=production
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
} finally { Pop-Location }
$payload = Join-Path $output 'payload'
New-Item -ItemType Directory -Path $payload -Force | Out-Null
Get-ChildItem -LiteralPath $release -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($release.Length + 1)
    if ($_.Extension -eq '.pdb') { return }
    $allowedJson = @('native_assets.json', 'data\flutter_assets\FontManifest.json', 'data\flutter_assets\NativeAssetsManifest.json')
    if (($_.Extension -eq '.json' -and $relative -notin $allowedJson) -or
        $relative -match '(?i)(\.env|\.dump$|\.key$|\.pem$|\.pfx$|\.jks$|\.crb$|\.recovery\.|receipts|backups|test_config)') {
        throw "Unexpected release payload file: $relative"
    }
    $target = Join-Path $payload $relative
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $target
}
Copy-Item -LiteralPath (Join-Path $root 'docs/windows-installation.md') -Destination (Join-Path $payload 'INSTALLATION.md')
foreach ($guide in @('accounts-setup.md','masters-setup.md','windows-backend-prerequisites.md',
    'windows-pilot-checklist.md','restoration-evidence.md','restoration-setup.md')) {
    Copy-Item -LiteralPath (Join-Path $root "docs/$guide") -Destination (Join-Path $payload $guide)
}
& $compilerPath "/DPayloadDir=$payload" "/DOutputDir=$output" "/DAppVersion=$version" "/DBuildNumber=$build" (Join-Path $PSScriptRoot 'carrier-records.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$installer = Join-Path $output "CarrierRecords-$version+$build-windows-x64-setup.exe"
$files = @(Get-ChildItem -LiteralPath $payload -Recurse -File | ForEach-Object {
    @{ path = $_.FullName.Substring($payload.Length + 1); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
@{ version=$version; build=$build; environment='production'; installer=$installer;
   installerSha256=(Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant();
   files=$files } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'manifest.json') -Encoding UTF8
Write-Output "Installer: $installer"
Get-FileHash -LiteralPath $installer -Algorithm SHA256
