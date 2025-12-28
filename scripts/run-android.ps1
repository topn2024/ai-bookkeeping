# ============================================================
# AI智能记账 - Android 一键运行脚本
# ============================================================

param(
    [ValidateSet("debug", "release", "profile")]
    [string]$Mode = "debug",
    [switch]$StartEmulator,
    [string]$Device
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $projectRoot) {
    $projectRoot = "D:\code\ai-bookkeeping"
}

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "       AI智能记账 - Android 运行脚本" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# 进入项目目录
Set-Location $projectRoot
Write-Host "项目目录: $projectRoot"

# 检查 Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Flutter 未安装或未添加到 PATH" -ForegroundColor Red
    exit 1
}

# 启动模拟器（如果需要）
if ($StartEmulator) {
    Write-Host "`n正在启动模拟器..." -ForegroundColor Yellow
    & "$projectRoot\scripts\start-emulator.ps1"
    Start-Sleep -Seconds 5
}

# 检查设备
Write-Host "`n检查已连接的设备..." -ForegroundColor Cyan
flutter devices

$devices = flutter devices --machine 2>$null | ConvertFrom-Json
if ($devices.Count -eq 0) {
    Write-Host "[ERROR] 没有可用的设备" -ForegroundColor Red
    Write-Host "请启动模拟器或连接真机后重试"
    Write-Host "运行: .\scripts\start-emulator.ps1"
    exit 1
}

# 获取依赖
Write-Host "`n获取项目依赖..." -ForegroundColor Cyan
flutter pub get

# 构建运行参数
$runArgs = @("run")

switch ($Mode) {
    "release" { $runArgs += "--release" }
    "profile" { $runArgs += "--profile" }
    default { $runArgs += "--debug" }
}

if ($Device) {
    $runArgs += @("-d", $Device)
}

# 运行应用
Write-Host "`n启动应用 (模式: $Mode)..." -ForegroundColor Green
Write-Host "============================================================"

& flutter $runArgs
