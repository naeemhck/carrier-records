param(
  [Parameter(Mandatory=$true)][string[]]$PageImages,
  [Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
# Synthetic QA files only; never change printer defaults or install a printer.
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.local/t14-native-files'))
$target = [IO.Path]::GetFullPath($OutputPath)
if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Output must be inside the ignored T14 synthetic fixture directory.'
}
if (Test-Path -LiteralPath $target) { throw 'Refusing to overwrite an existing file.' }
Add-Type -AssemblyName System.Drawing
$images = @()
$document = New-Object System.Drawing.Printing.PrintDocument
try {
  foreach ($path in $PageImages) {
    $absolute = [IO.Path]::GetFullPath($path)
    if (-not $absolute.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Image outside synthetic fixture directory.' }
    $images += [Drawing.Image]::FromFile($absolute)
  }
  $document.PrinterSettings.PrinterName = 'Microsoft Print to PDF'
  if (-not $document.PrinterSettings.IsValid) { throw 'Existing virtual printer unavailable.' }
  $document.PrinterSettings.PrintToFile = $true
  $document.PrinterSettings.PrintFileName = $target
  $document.PrintController = New-Object Drawing.Printing.StandardPrintController
  $document.DocumentName = 'Carrier Records synthetic T14 print verification'
  $document.DefaultPageSettings.Landscape = $true
  $document.DefaultPageSettings.PaperSize = $document.PrinterSettings.PaperSizes | Where-Object { $_.Kind -eq 'A4' } | Select-Object -First 1
  $document.DefaultPageSettings.Margins = New-Object Drawing.Printing.Margins(0,0,0,0)
  $script:t14PageIndex = 0
  $document.add_PrintPage({
    param($sender,$eventArgs)
    $eventArgs.Graphics.DrawImage($images[$script:t14PageIndex], $eventArgs.PageBounds)
    $script:t14PageIndex++
    $eventArgs.HasMorePages = $script:t14PageIndex -lt $images.Count
  })
  $document.Print()
  if (-not (Test-Path -LiteralPath $target)) { throw 'Print did not create output.' }
  Write-Output ('PASS Windows existing virtual printer: ' + $script:t14PageIndex + ' A4 landscape pages; physical printing not exercised.')
} finally {
  $document.Dispose()
  foreach ($image in $images) { $image.Dispose() }
}
