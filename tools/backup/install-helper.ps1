param([Parameter(Mandatory=$true)][string]$PythonExe)
$ErrorActionPreference='Stop'
$destination=Join-Path $env:LOCALAPPDATA 'CarrierRecords\BackupHelper'
if (Test-Path -LiteralPath (Join-Path $destination 'config.json')) { throw 'HELPER_ALREADY_CONFIGURED_USE_EXISTING_INSTALLATION' }
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls $destination /inheritance:r /grant:r "*$($sid):(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'HELPER_DIRECTORY_PROTECTION_FAILED' }
foreach ($file in @('backup.py','core.py','transport.py','vault.py','requirements.txt','install-schedule.ps1','schedule-status.ps1')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $destination -Force }
& $PythonExe -m venv (Join-Path $destination 'venv')
if ($LASTEXITCODE -ne 0) { throw 'HELPER_RUNTIME_INSTALL_FAILED' }
$runtime=Join-Path $destination 'venv\Scripts\python.exe'
& $runtime -m pip install --disable-pip-version-check -r (Join-Path $destination 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'HELPER_DEPENDENCY_INSTALL_FAILED' }
$launcher=@'
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'venv\Scripts\python.exe') (Join-Path $PSScriptRoot 'backup.py') run --config (Join-Path $PSScriptRoot 'config.json')
exit $LASTEXITCODE
'@
$launcher | Set-Content -LiteralPath (Join-Path $destination 'run-backup.ps1') -Encoding UTF8
Write-Output 'Helper installed for this Windows account. Configuration and scheduling are still required.'
