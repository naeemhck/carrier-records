$ErrorActionPreference = 'Stop'
$cli = Join-Path $PSScriptRoot '.local/supabase/supabase.exe'
if (-not (Test-Path -LiteralPath $cli)) { throw 'Run tools/install-supabase.ps1 first.' }
# Windows PowerShell 5 treats redirected native stderr progress as errors.
# Preserve the CLI exit code instead of failing on progress messages.
$ErrorActionPreference = 'Continue'
& $cli @args
exit $LASTEXITCODE
