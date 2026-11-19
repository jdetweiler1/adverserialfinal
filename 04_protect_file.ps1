# Usage: .\04_protect_file.ps1 -Path 'C:\IT\reset_log.txt'
param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File not found: $Path" }
$Path = (Resolve-Path -LiteralPath $Path).Path
$Backup = Join-Path $env:TEMP ("blue-acl-" + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')

Write-Host '========== BEFORE =========='
icacls.exe $Path
icacls.exe $Path /save $Backup | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Could not save ACL backup' }

icacls.exe $Path /inheritance:r | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Could not disable inherited grants' }
icacls.exe $Path /remove:g '*S-1-1-0' '*S-1-5-11' '*S-1-5-32-545' | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Could not remove broad access' }
icacls.exe $Path /grant:r '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Could not grant system/admin access' }

Write-Host '========== AFTER =========='
icacls.exe $Path
Write-Host "ACL backup: $Backup"
Write-Host "Restore from containing directory with: icacls.exe '$(Split-Path $Path -Parent)' /restore '$Backup'"
