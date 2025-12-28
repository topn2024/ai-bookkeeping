# 紧急迁移脚本 - Gradle和Android配置
# 简化版本，直接执行迁移

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  紧急迁移: Gradle + Android配置" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查源目录
$gradleSource = "$env:USERPROFILE\.gradle"
$androidSource = "$env:USERPROFILE\.android"

Write-Host "检查源目录..." -ForegroundColor Yellow

if (-not (Test-Path $gradleSource)) {
    Write-Host "[!] Gradle缓存目录不存在: $gradleSource" -ForegroundColor Red
    $gradleExists = $false
} else {
    $gradleSize = (Get-ChildItem $gradleSource -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $gradleSizeGB = [math]::Round($gradleSize/1GB, 2)
    Write-Host "[+] Gradle缓存: ${gradleSizeGB}GB" -ForegroundColor Green
    $gradleExists = $true
}

if (-not (Test-Path $androidSource)) {
    Write-Host "[!] Android配置目录不存在: $androidSource" -ForegroundColor Red
    $androidExists = $false
} else {
    $androidSize = (Get-ChildItem $androidSource -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $androidSizeGB = [math]::Round($androidSize/1GB, 2)
    Write-Host "[+] Android配置: ${androidSizeGB}GB" -ForegroundColor Green
    $androidExists = $true
}

if (-not $gradleExists -and -not $androidExists) {
    Write-Host "`n没有需要迁移的内容!" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n确认开始迁移? (y/n): " -NoNewline -ForegroundColor Yellow
$confirm = Read-Host
if ($confirm -ne 'y') {
    Write-Host "已取消" -ForegroundColor Yellow
    exit 0
}

# 迁移Gradle缓存
if ($gradleExists) {
    Write-Host "`n========== 迁移 Gradle 缓存 ==========" -ForegroundColor Cyan
    $gradleDest = "D:\gradle_cache"

    Write-Host "源: $gradleSource" -ForegroundColor Gray
    Write-Host "目标: $gradleDest" -ForegroundColor Gray

    if (Test-Path $gradleDest) {
        Write-Host "[!] 目标目录已存在，删除中..." -ForegroundColor Yellow
        Remove-Item $gradleDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "移动文件中 (这可能需要几分钟)..." -ForegroundColor Yellow

    # 使用robocopy移动文件
    $result = robocopy $gradleSource $gradleDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS

    if ($LASTEXITCODE -le 7) {
        Write-Host "[+] Gradle缓存迁移成功!" -ForegroundColor Green

        # 设置环境变量
        Write-Host "设置环境变量 GRADLE_USER_HOME..." -ForegroundColor Yellow
        [Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\gradle_cache', 'User')
        Write-Host "[+] 环境变量设置完成" -ForegroundColor Green
    } else {
        Write-Host "[!] Gradle缓存迁移可能有问题，退出码: $LASTEXITCODE" -ForegroundColor Yellow
    }
}

# 迁移Android配置
if ($androidExists) {
    Write-Host "`n========== 迁移 Android 配置 ==========" -ForegroundColor Cyan
    $androidDest = "D:\Android\.android"

    Write-Host "源: $androidSource" -ForegroundColor Gray
    Write-Host "目标: $androidDest" -ForegroundColor Gray

    # 确保目标父目录存在
    $androidParent = "D:\Android"
    if (-not (Test-Path $androidParent)) {
        New-Item -ItemType Directory -Path $androidParent -Force | Out-Null
    }

    if (Test-Path $androidDest) {
        Write-Host "[!] 目标目录已存在，删除中..." -ForegroundColor Yellow
        Remove-Item $androidDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "移动文件中 (这可能需要几分钟)..." -ForegroundColor Yellow

    # 使用robocopy移动文件
    $result = robocopy $androidSource $androidDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS

    if ($LASTEXITCODE -le 7) {
        Write-Host "[+] Android配置迁移成功!" -ForegroundColor Green

        # 创建符号链接
        Write-Host "创建符号链接..." -ForegroundColor Yellow
        cmd /c mklink /D "$androidSource" "$androidDest" 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] 符号链接创建成功" -ForegroundColor Green
        } else {
            Write-Host "[!] 符号链接创建失败，但文件已迁移" -ForegroundColor Yellow
            Write-Host "    Android模拟器可能需要手动配置新路径" -ForegroundColor Gray
        }
    } else {
        Write-Host "[!] Android配置迁移可能有问题，退出码: $LASTEXITCODE" -ForegroundColor Yellow
    }
}

# 显示结果
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  迁移完成!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 检查C盘空间
$cDrive = Get-PSDrive -Name C
$freeGB = [math]::Round($cDrive.Free/1GB, 2)
$totalGB = [math]::Round(($cDrive.Used + $cDrive.Free)/1GB, 2)
$usedPercent = [math]::Round(($cDrive.Used/($cDrive.Used + $cDrive.Free))*100, 1)

Write-Host "`nC盘当前状态:" -ForegroundColor Yellow
Write-Host "  剩余空间: ${freeGB}GB / ${totalGB}GB" -ForegroundColor Green
Write-Host "  使用率: ${usedPercent}%" -ForegroundColor Green

Write-Host "`n后续步骤:" -ForegroundColor Yellow
Write-Host "  1. 重启命令行窗口以使环境变量生效" -ForegroundColor Gray
Write-Host "  2. 运行 'flutter doctor -v' 验证环境" -ForegroundColor Gray
Write-Host "  3. 重新构建项目测试" -ForegroundColor Gray

Write-Host ""
