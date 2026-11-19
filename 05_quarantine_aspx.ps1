# Usage: .\05_quarantine_aspx.ps1 -Path 'C:\inetpub\wwwroot\staff\portal.aspx'
param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or [IO.Path]::GetExtension($Path) -ne '.aspx') { throw 'Provide an existing .aspx file' }
if ([IO.Path]::GetFileName($Path).ToLowerInvariant() -eq 'default.aspx') { throw 'Refusing to move a default page' }

$Path = (Resolve-Path -LiteralPath $Path).Path
$Folder = Join-Path $env:ProgramData 'CIS4930-Quarantine'
New-Item -Path $Folder -ItemType Directory -Force | Out-Null
icacls.exe $Folder /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not secure quarantine folder' }
$Backup = Join-Path $Folder ("{0}.{1}" -f [IO.Path]::GetFileName($Path),(Get-Date -Format 'yyyyMMdd_HHmmss'))

Write-Host '========== BEFORE =========='
Get-Item -LiteralPath $Path | Select-Object FullName,Length,LastWriteTime
Move-Item -LiteralPath $Path -Destination $Backup
Write-Host '========== AFTER =========='
Write-Host "File moved outside web root: $Backup"
Write-Host "Rollback: Move-Item -LiteralPath '$Backup' -Destination '$Path'"
