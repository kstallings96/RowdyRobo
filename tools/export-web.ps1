<#
.SYNOPSIS
  Exports the web build into web/, which Vercel serves as static files.

.DESCRIPTION
  Vercel cannot run the Godot exporter, so the build is produced here and
  committed. Run this, play through web/ locally, then commit and push.

  The Godot version must match the installed export templates. Check with:
      ls $env:APPDATA\Godot\export_templates

.PARAMETER Godot
  Path to the Godot executable. Defaults to $env:GODOT if set.

.EXAMPLE
  .\tools\export-web.ps1 -Godot "C:\Godot\Godot_v4.5-stable_win64.exe"
#>
param(
  [string]$Godot = $env:GODOT
)

$ErrorActionPreference = 'Stop'

if (-not $Godot) {
  Write-Error "No Godot path. Pass -Godot <path to Godot exe>, or set `$env:GODOT."
}
if (-not (Test-Path $Godot)) {
  Write-Error "Godot not found at: $Godot"
}

$project = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $project 'web'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Exporting with $Godot" -ForegroundColor Cyan

# --headless keeps it off the display server; --export-release matches the
# "Web" preset in export_presets.cfg.
& $Godot --headless --path $project --export-release 'Web' (Join-Path $outDir 'index.html')
$exportExit = $LASTEXITCODE

if ($exportExit -ne 0) {
  Write-Error "Godot export failed (exit $exportExit). If it complains about export templates, the editor version and the installed templates do not match."
}

# The exported .pck carries a copy of config.json, but the served one is what
# the web build actually reads at startup. On the deployed site that copy is
# written by Vercel from its environment variables; here it is just your local
# config.json, so the build you test points at the same backend you do.
Copy-Item (Join-Path $project 'config.json') (Join-Path $outDir 'config.json') -Force

Write-Host "`nExported to $outDir" -ForegroundColor Green
Get-ChildItem $outDir | Select-Object Name, @{n='Size';e={'{0:N1} MB' -f ($_.Length / 1MB)}} | Format-Table -AutoSize

Write-Host "This is a LOCAL build for testing. Deploying happens on git push," -ForegroundColor Yellow
Write-Host "via .github/workflows/deploy.yml. To try this build in a browser:" -ForegroundColor Yellow
Write-Host "    python -m http.server 8000 --directory web" -ForegroundColor DarkGray
