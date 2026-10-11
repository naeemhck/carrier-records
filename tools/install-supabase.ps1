$ErrorActionPreference = 'Stop'
$version = '2.120.0'
$asset = "supabase_${version}_windows_amd64.zip"
$baseUrl = "https://github.com/supabase/cli/releases/download/v$version"
$target = Join-Path $PSScriptRoot '.local/supabase'
New-Item -ItemType Directory -Force -Path $target | Out-Null
$archive = Join-Path $target $asset
& curl.exe --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 600 --output $archive "$baseUrl/$asset"
if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI download failed.' }
$checksumFile = Join-Path $target 'checksums.txt'
& curl.exe --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 90 --output $checksumFile "$baseUrl/checksums.txt"
if ($LASTEXITCODE -ne 0) { throw 'Supabase checksum download failed.' }
$checksums = Get-Content -LiteralPath $checksumFile -Raw
$line = ($checksums -split "`n" | Where-Object { $_.Trim().EndsWith($asset) })
if (@($line).Count -ne 1) { throw 'No unique checksum for pinned CLI archive.' }
$expected = ($line.Trim() -split '\s+')[0]
$actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
if ($actual -ne $expected) { throw 'Supabase CLI archive checksum mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath $target -Force
& (Join-Path $target 'supabase.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI verification failed.' }
