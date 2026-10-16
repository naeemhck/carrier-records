param([Parameter(Mandatory=$true)][ValidateSet('qa_admin','qa_khi','qa_isb')][string]$Username)
$ErrorActionPreference='Stop'
$secretPath=Join-Path $PSScriptRoot '../.local/qa-preview/tester-credentials.dpapi'
$protected=Get-Content -LiteralPath $secretPath -Raw | ConvertTo-SecureString
$items=[System.Net.NetworkCredential]::new('', $protected).Password | ConvertFrom-Json
$item=$items.$Username
$value=if ($item.handoff_temporary) { $item.handoff_temporary } else { $item.password }
Write-Host "LOCAL TEST ONLY — $Username"
Write-Host $value
Write-Host 'Enter this only on https://karvaan-test.pages.dev. Share privately; never paste into chat or evidence.'
$value=$null; $items=$null; $protected=$null
