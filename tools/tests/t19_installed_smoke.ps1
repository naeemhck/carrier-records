param([Parameter(Mandatory=$true)][string]$Executable,
      [Parameter(Mandatory=$true)][string]$Evidence)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class CarrierWindowProbe {
  public delegate bool Callback(IntPtr hwnd, IntPtr data);
  [DllImport("user32.dll")] static extern bool EnumWindows(Callback callback, IntPtr data);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int count);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
  public static IntPtr Find(uint pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((hwnd, data) => {
      uint owner; GetWindowThreadProcessId(hwnd, out owner);
      var text = new StringBuilder(256); GetWindowText(hwnd, text, 256);
      if (owner == pid && text.ToString() == "Carrier Records") {found = hwnd; return false;}
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
'@
$path = (Resolve-Path -LiteralPath $Executable).Path
$process = Start-Process -FilePath $path -WorkingDirectory (Split-Path $path) -WindowStyle Hidden -PassThru
try {
    $window = [IntPtr]::Zero
    for ($attempt=0; $attempt -lt 90; $attempt++) {
        Start-Sleep -Milliseconds 500
        $process.Refresh()
        if ($process.HasExited) { throw "Installed process exited: $($process.ExitCode)" }
        $window = [CarrierWindowProbe]::Find($process.Id)
        if ($window -ne [IntPtr]::Zero) { break }
    }
    if ($window -eq [IntPtr]::Zero) { throw 'No owned Carrier Records window within 45 seconds.' }
    $result = @{path=$path; version=(Get-Item $path).VersionInfo.FileVersion;
        processAlive=$true; windowCreated=$true; windowVisible=[CarrierWindowProbe]::IsWindowVisible($window);
        responding=$process.Responding; cleanMachine=$false; loginVerified=$false;
        publicConfigPresent=(Test-Path (Join-Path $env:LOCALAPPDATA 'CarrierRecords/client.json'))}
    $result | ConvertTo-Json | Set-Content -LiteralPath $Evidence -Encoding UTF8
    $result | ConvertTo-Json
} finally {
    if (!$process.HasExited) { Stop-Process -Id $process.Id }
}
