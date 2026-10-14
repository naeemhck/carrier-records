"""Fail closed while checking the existing installer compiler's signature."""
import shutil,subprocess
from pathlib import Path

def verify_compiler(path):
    path=Path(path)
    if not path.is_file():raise RuntimeError('Installer compiler absent.')
    shell=shutil.which('pwsh') or shutil.which('powershell')
    if not shell:raise RuntimeError('PowerShell signature verification unavailable.')
    # Windows PowerShell may inherit PS7's module search path. Import the
    # security module belonging to the selected host, not an inherited module.
    literal=str(path).replace("'","''")
    command="Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1') -ErrorAction Stop; (Get-AuthenticodeSignature -LiteralPath '"+literal+"').Status"
    result=subprocess.run([shell,'-NoProfile','-Command',command],capture_output=True,text=True)
    if result.returncode or result.stdout.strip()!='Valid':
        raise RuntimeError('Installer compiler signature verification failed.')
