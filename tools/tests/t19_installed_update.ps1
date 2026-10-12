param([Parameter(Mandatory=$true)][string]$Manifest,
      [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
$release = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$exe = Join-Path $env:LOCALAPPDATA 'Programs/CarrierRecords/carrier_records.exe'
$beforeVersion = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
$expectedVersion = "$($release.version)+$($release.build)"
if ($beforeVersion -eq $expectedVersion) { throw 'Requires an actual cross-version update.' }
$config = Join-Path $env:LOCALAPPDATA 'CarrierRecords/client.json'
if (Test-Path -LiteralPath $config) { throw 'Existing public configuration; refusing to replace it.' }
New-Item -ItemType Directory -Path (Split-Path $config) -Force | Out-Null
# Synthetic PUBLIC connection data only; no actual identity, token or backend.
@{version=1;url='https://127.0.0.1:1';publishableKey='sb_publishable_t19_synthetic_value';
  businessId=[guid]::NewGuid().ToString()} | ConvertTo-Json | Set-Content -LiteralPath $config -Encoding UTF8
$configHash = (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
try {
    if ((Get-FileHash -LiteralPath $release.installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $release.installerSha256) {
        throw 'Installer hash mismatch.'
    }
    $process = Start-Process -FilePath $release.installer -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Update failed: $($process.ExitCode)" }
    $afterVersion = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
    if ($afterVersion -ne $expectedVersion) { throw 'Installed version mismatch.' }
    if ((Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash -ne $configHash) { throw 'Configuration changed.' }
    @{beforeVersion=$beforeVersion;afterVersion=$afterVersion;installerExit=$process.ExitCode;
      publicConfigHashPreserved=$true;cleanMachine=$false;authorizedAccessVerified=$false;
      protectedSessionVerified=$false} | ConvertTo-Json | Set-Content -LiteralPath $Evidence -Encoding UTF8
    Get-Content -LiteralPath $Evidence
} finally {
    # Remove only our unchanged synthetic configuration, never an existing/user-edited file.
    if (Test-Path -LiteralPath $config) {
        if ((Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash -eq $configHash) {
            Remove-Item -LiteralPath $config
        } else { Write-Warning 'Configuration changed externally; left untouched.' }
    }
}
