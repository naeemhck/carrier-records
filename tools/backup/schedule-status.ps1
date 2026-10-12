param([Parameter(Mandatory=$true)][string]$TaskName,[Parameter(Mandatory=$true)][string]$ConfigPath)
$ErrorActionPreference='Stop'
if ($TaskName -notmatch '^CarrierRecordsBackup-[0-9a-f-]{36}$') { exit 2 }
$task=Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$active=$false
if ($task -and $task.State -ne 'Disabled') {
    $active=@($task.Actions | Where-Object { $_.Arguments.Contains($ConfigPath) -and $_.Arguments.Contains('--scheduled') }).Count -eq 1
}
@{active=$active;time_zone=(Get-TimeZone).Id} | ConvertTo-Json -Compress
