<#
.SYNOPSIS
  Build AzadHub for Windows: flutter build + copy native DLLs + zip

.DESCRIPTION
  鸿蒙 fork 的 Flutter SDK 在 Windows 构建时不会自动复制 native assets
  (sbm_ffi.dll, sqlite3mc.dll, flutter_pty.dll) 到 Release 目录。
  此脚本在构建后自动复制这三个 DLL，然后打包成 zip。

.PARAMETER FlutterSdk
  Flutter SDK 根目录。默认用 D:\workspace\flutter\ohos-flutter_3.44.9，
  不存在则回退到 PATH 里的 flutter。

.PARAMETER Proxy
  HTTP 代理地址。默认 http://127.0.0.1:7897。传空字符串跳过代理。

.PARAMETER SkipBuild
  跳过 flutter build，只复制 DLL 和打包（用于已构建的情况）。

.PARAMETER OutputDir
  zip 输出目录。默认 build\dist。

.EXAMPLE
  .\scripts\build-windows.ps1
  .\scripts\build-windows.ps1 -SkipBuild
  .\scripts\build-windows.ps1 -FlutterSdk "D:\flutter\stable" -Proxy ""
#>

param(
    [string]$FlutterSdk = "D:\workspace\flutter\ohos-flutter_3.44.9",
    [string]$Proxy = "http://127.0.0.1:7897",
    [switch]$SkipBuild,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

# --- 路径 ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$releaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$nativeAssetsDir = Join-Path $projectRoot "build\native_assets\windows"
$dlls = @("sbm_ffi.dll", "sqlite3mc.dll", "flutter_pty.dll")

# --- 代理 ---
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
    Write-Host "Proxy: $Proxy" -ForegroundColor DarkGray
}

# --- Flutter 命令 ---
$flutter = $null
if ($FlutterSdk -and (Test-Path (Join-Path $FlutterSdk "bin\flutter.bat"))) {
    $flutter = Join-Path $FlutterSdk "bin\flutter.bat"
} elseif (Get-Command flutter -ErrorAction SilentlyContinue) {
    $flutter = "flutter"
} else {
    Write-Host "ERROR: Flutter SDK not found. Use -FlutterSdk to specify." -ForegroundColor Red
    exit 1
}
Write-Host "Flutter: $flutter" -ForegroundColor DarkGray

# --- 1. 构建 ---
if (-not $SkipBuild) {
    Write-Host "`n[1/3] Building Windows release..." -ForegroundColor Cyan
    & $flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    Write-Host "Build OK" -ForegroundColor Green
} else {
    Write-Host "`n[1/3] Skipping build (-SkipBuild)" -ForegroundColor DarkGray
}

if (-not (Test-Path $releaseDir)) {
    Write-Host "ERROR: Release dir not found: $releaseDir" -ForegroundColor Red
    Write-Host "Run without -SkipBuild first." -ForegroundColor Yellow
    exit 1
}

# --- 2. 复制 native DLL ---
Write-Host "`n[2/3] Copying native DLLs..." -ForegroundColor Cyan
$copied = 0
foreach ($dll in $dlls) {
    $src = Join-Path $nativeAssetsDir $dll
    $dst = Join-Path $releaseDir $dll
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        $size = [math]::Round((Get-Item $src).Length / 1KB)
        Write-Host "  $dll ($size KB)" -ForegroundColor Green
        $copied++
    } else {
        Write-Host "  $dll -- NOT FOUND in native_assets" -ForegroundColor Yellow
    }
}
Write-Host "Copied $copied/$($dlls.Count) DLLs" -ForegroundColor Green

# --- 3. 打包 zip ---
Write-Host "`n[3/3] Creating zip..." -ForegroundColor Cyan

# 读版本号
$pubspec = Get-Content (Join-Path $projectRoot "pubspec.yaml") -Raw
$version = "unknown"
if ($pubspec -match "version:\s*([^\s+]+)") {
    $version = $matches[1]
}

if (-not $OutputDir) {
    $OutputDir = Join-Path $projectRoot "build\dist"
}
if (-not (Test-Path $OutputDir)) {
    New-Item $OutputDir -ItemType Directory -Force | Out-Null
}

$zipName = "AzadHub-$version-windows-x64.zip"
$zipPath = Join-Path $OutputDir $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath -Force

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "  $zipName ($zipSize MB)" -ForegroundColor Green

Write-Host "`nDone!" -ForegroundColor Green
Write-Host "  exe: $releaseDir\AzadHub.exe" -ForegroundColor DarkGray
Write-Host "  zip: $zipPath" -ForegroundColor DarkGray
