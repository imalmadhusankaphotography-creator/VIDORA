<#
.SYNOPSIS
  Build and package VIDORA for Windows x64.

.DESCRIPTION
  Produces, in $env:DIST (default: dist):
    VIDORA-<version>-windows-x64.msi            per-machine installer (WiX v5), Start menu + desktop shortcuts
    VIDORA-<version>-windows-x64-portable.zip   VIDORA\VIDORA.exe + vidora-cli.exe, no installation

  Based on FilmCraft's packaging/windows/package.ps1. The binaries link the C runtime statically
  (+crt-static), so neither package needs the Visual C++ redistributable. VIDORA's Sinhala fonts are
  embedded with CRAFT_FONTS_DIR=packaging/vidora (crates/text/build.rs).

  Needs: Rust (MSVC toolchain), the Windows SDK (rc.exe, for the icon and version info), and
  WiX v5: dotnet tool install --global wix --version 5.0.2

.EXAMPLE
  pwsh packaging/vidora/package.ps1
  pwsh packaging/vidora/package.ps1 -SkipBuild
  pwsh packaging/vidora/package.ps1 -NoMsi        # portable zip only (no WiX needed)
#>
param(
  [switch] $SkipBuild,
  [switch] $NoMsi
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Here = $PSScriptRoot

function Invoke-Native([string] $What, [scriptblock] $Block) {
  Write-Output "==> $What"
  & $Block
  if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE" }
}

# The version lives in one place: [workspace.package] version in the root Cargo.toml.
$Version = $env:VIDORA_VERSION
if (-not $Version) {
  $inPkg = $false
  foreach ($line in Get-Content (Join-Path $Root 'Cargo.toml')) {
    if ($line -match '^\s*\[') { $inPkg = ($line.Trim() -eq '[workspace.package]'); continue }
    if ($inPkg -and $line -match '^\s*version\s*=\s*"([^"]+)"') { $Version = $Matches[1]; break }
  }
}
if (-not $Version) { throw 'could not read [workspace.package] version from Cargo.toml' }
$MsiVersion = ($Version -split '-')[0]

$Target = 'x86_64-pc-windows-msvc'
$Dist = if ($env:DIST) { $env:DIST } else { Join-Path $Root 'dist' }
$TargetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $Root 'target' }
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

if (-not $env:FILMCRAFT_BUILD_SHA) { $env:FILMCRAFT_BUILD_SHA = (git -C $Root rev-parse HEAD 2>$null) }
if (-not $env:FILMCRAFT_BUILD_DATE) { $env:FILMCRAFT_BUILD_DATE = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd') }
# VIDORA's bundled Sinhala fonts (packaging/vidora/fonts/manifest.txt), required in release builds.
if (-not $env:CRAFT_FONTS_DIR) { $env:CRAFT_FONTS_DIR = $Here }
if (-not $env:CRAFT_FONTS_REQUIRED) { $env:CRAFT_FONTS_REQUIRED = '1' }

Write-Output "VIDORA $Version for Windows x64 ($Target)"

if (-not $SkipBuild) {
  # Static CRT: no VC++ redistributable needed. Scoped to the target so host build scripts and
  # proc-macros are unaffected.
  $flagVar = 'CARGO_TARGET_' + ($Target.ToUpper() -replace '-', '_') + '_RUSTFLAGS'
  [Environment]::SetEnvironmentVariable($flagVar, '-C target-feature=+crt-static')
  # Fail the build (rather than warn) if the icon/VERSIONINFO can't be embedded.
  $env:FILMCRAFT_REQUIRE_WINRES = '1'
  Invoke-Native "cargo build ($Target)" { cargo build --release --locked -p filmcraft -p filmcraft-cli --target $Target }
}

$Bin = Join-Path $TargetDir "$Target\release"

# PE checks: x64 machine; the app is a GUI program (no console window), the CLI a console one.
function Get-PeHeader([string] $Path) {
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $pe = [BitConverter]::ToInt32($bytes, 0x3C)
  return @{ Machine = [BitConverter]::ToUInt16($bytes, $pe + 4); Subsystem = [BitConverter]::ToUInt16($bytes, $pe + 0x5C) }
}
foreach ($check in @(@('filmcraft.exe', 2), @('filmcraft-cli.exe', 3))) {
  $h = Get-PeHeader (Join-Path $Bin $check[0])
  if ($h.Machine -ne 0x8664) { throw "$($check[0]) is for machine 0x$('{0:X}' -f $h.Machine), expected x64" }
  if ($h.Subsystem -ne $check[1]) { throw "$($check[0]) has PE subsystem $($h.Subsystem), expected $($check[1])" }
  Write-Output "ok $($check[0]): x64, PE subsystem $($h.Subsystem)"
}

# ---- stage: VIDORA.exe, vidora-cli.exe, README and licences -----------------------------------
$Stage = Join-Path $TargetDir 'vidora-package\VIDORA'
Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
Copy-Item (Join-Path $Bin 'filmcraft.exe') (Join-Path $Stage 'VIDORA.exe')
Copy-Item (Join-Path $Bin 'filmcraft-cli.exe') (Join-Path $Stage 'vidora-cli.exe')
Copy-Item (Join-Path $Here 'README-VIDORA.txt') (Join-Path $Stage 'README.txt')
foreach ($f in 'LICENSE-MIT', 'LICENSE-APACHE', 'NOTICE') { Copy-Item (Join-Path $Root $f) $Stage }
Copy-Item (Join-Path $Here 'fonts\OFL-NotoSinhala.txt') $Stage

# ---- MSI ---------------------------------------------------------------------------------------
$Msi = Join-Path $Dist "VIDORA-$Version-windows-x64.msi"
if (-not $NoMsi) {
  Invoke-Native 'wix build' {
    wix build (Join-Path $Here 'vidora.wxs') -arch x64 `
      -d "Version=$MsiVersion" -d "BinDir=$Stage" -d "IconPath=$(Join-Path $Root 'assets\app-icon\filmcraft.ico')" `
      -o $Msi
  }
  Remove-Item -Force -ErrorAction SilentlyContinue ([IO.Path]::ChangeExtension($Msi, '.wixpdb'))
}

# ---- portable zip ------------------------------------------------------------------------------
$Portable = Join-Path $TargetDir 'vidora-package\portable\VIDORA'
Remove-Item -Recurse -Force (Split-Path $Portable) -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Portable | Out-Null
Copy-Item (Join-Path $Stage '*') $Portable
Copy-Item (Join-Path $Here 'Create Desktop Shortcut.bat') $Portable
# The marker that makes VIDORA keep its data in .\data next to the exe instead of %APPDATA%\VIDORA.
Set-Content -Encoding ascii -Path (Join-Path $Portable 'portable.txt') -Value @(
  'VIDORA portable: preferences, presets, logs and crash recovery are kept in the data folder',
  'next to VIDORA.exe. Delete this file to use %APPDATA%\VIDORA instead.'
)
$Zip = Join-Path $Dist "VIDORA-$Version-windows-x64-portable.zip"
Remove-Item -Force $Zip -ErrorAction SilentlyContinue
Compress-Archive -Path $Portable -DestinationPath $Zip

Invoke-Native 'vidora-cli --version' { & (Join-Path $Stage 'vidora-cli.exe') --version }
$out = @($Zip)
if (-not $NoMsi) { $out += $Msi }
Get-Item $out | Format-Table Name, Length
