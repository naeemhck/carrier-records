param([Parameter(Mandatory=$true)][string]$ConfigPath,[Parameter(Mandatory=$true)][string]$PythonExe,[string]$DailyTime)
$ErrorActionPreference='Stop'
$resolvedConfig=(Resolve-Path -LiteralPath $ConfigPath).Path
$resolvedPython=(Resolve-Path -LiteralPath $PythonExe).Path
$cfg=Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json
if ($DailyTime) { if ($DailyTime -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') { throw 'CONFIGURATION_INVALID' }; $cfg.daily_time=$DailyTime }
if ($cfg.task_name -notmatch '^CarrierRecordsBackup-[0-9a-f-]{36}$' -or $cfg.daily_time -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') { throw 'CONFIGURATION_INVALID' }
$helper=Join-Path $PSScriptRoot 'backup.py'
& $resolvedPython $helper check --config $resolvedConfig
if ($LASTEXITCODE -ne 0) { throw 'ADMINISTRATOR_VERIFICATION_FAILED' }
$arguments='"'+$helper+'" run --config "'+$resolvedConfig+'" --scheduled'
$existing=Get-ScheduledTask -TaskName $cfg.task_name -ErrorAction SilentlyContinue
if ($existing -and (@($existing.Actions).Count -ne 1 -or $existing.Actions[0].Execute -ne $resolvedPython -or $existing.Actions[0].Arguments -ne $arguments)) { throw 'TASK_NAME_ALREADY_EXISTS_WITH_DIFFERENT_ACTION' }
$identity=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action=New-ScheduledTaskAction -Execute $resolvedPython -Argument $arguments -WorkingDirectory $PSScriptRoot
$daily=New-ScheduledTaskTrigger -Daily -At $cfg.daily_time
$logon=New-ScheduledTaskTrigger -AtLogOn -User $identity
# Periodic retries run only when a daily backup is due. They do not keep the backend awake.
$retry=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 1)
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 15) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $cfg.task_name -Action $action -Trigger @($daily,$logon,$retry) -Settings $settings -Principal $principal -Description 'Carrier Records encrypted backup, daily and missed-run catch-up for the dedicated administrator Windows account.' -Force | Out-Null
$verified=Get-ScheduledTask -TaskName $cfg.task_name
if ($verified.State -eq 'Disabled' -or -not $verified.Settings.StartWhenAvailable) { throw 'SCHEDULE_NOT_ACTIVE' }
$cfg.time_zone=(Get-TimeZone).Id
$cfg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedConfig -Encoding UTF8
@{schedule_active=$true;daily_time=$cfg.daily_time;time_zone=$cfg.time_zone;requires_admin_windows_logon=$true} | ConvertTo-Json -Compress
