# 开发环境迁移脚本 - 从C盘迁移到D盘
# 运行前请仔细阅读 C盘迁移建议.md 文档

param(
    [switch]$DryRun = $false,  # 试运行模式,不实际执行迁移
    [switch]$GradleOnly = $false,  # 仅迁移Gradle
    [switch]$AndroidOnly = $false,  # 仅迁移Android配置
    [switch]$PubOnly = $false,  # 仅迁移Pub缓存
    [switch]$JdkOnly = $false,  # 仅迁移JDK
    [switch]$All = $false  # 迁移所有项目
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }

# 检查管理员权限
function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 计算目录大小
function Get-DirectorySize {
    param([string]$Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size/1GB, 2)
    }
    return 0
}

# 迁移函数
function Move-Directory {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Name,
        [switch]$UseSymLink = $false
    )

    Write-Info "`n========== 开始迁移: $Name =========="

    if (-not (Test-Path $Source)) {
        Write-Warning "源目录不存在: $Source"
        return $false
    }

    $size = Get-DirectorySize $Source
    Write-Info "源目录: $Source"
    Write-Info "目标目录: $Destination"
    Write-Info "大小: ${size}GB"

    if ($DryRun) {
        Write-Warning "[试运行模式] 跳过实际迁移"
        return $true
    }

    # 创建目标目录的父目录
    $destParent = Split-Path $Destination -Parent
    if (-not (Test-Path $destParent)) {
        Write-Info "创建目标父目录: $destParent"
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    # 如果目标已存在,询问是否覆盖
    if (Test-Path $Destination) {
        $response = Read-Host "目标目录已存在,是否删除? (y/n)"
        if ($response -eq 'y') {
            Remove-Item $Destination -Recurse -Force
        } else {
            Write-Warning "跳过迁移: $Name"
            return $false
        }
    }

    # 执行移动
    Write-Info "正在移动文件..."
    try {
        robocopy $Source $Destination /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NP | Out-Null

        if ($LASTEXITCODE -le 7) {  # robocopy成功的退出码
            Write-Success "✓ 文件移动完成"

            # 如果需要创建符号链接
            if ($UseSymLink) {
                Write-Info "创建符号链接: $Source -> $Destination"
                cmd /c mklink /D "$Source" "$Destination" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "✓ 符号链接创建成功"
                } else {
                    Write-Error "✗ 符号链接创建失败"
                    return $false
                }
            }

            return $true
        } else {
            Write-Error "✗ 文件移动失败 (退出码: $LASTEXITCODE)"
            return $false
        }
    } catch {
        Write-Error "✗ 迁移过程出错: $_"
        return $false
    }
}

# 主程序
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     开发环境迁移工具 - C盘到D盘                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Warning "*** 试运行模式 - 不会实际执行迁移 ***`n"
}

# 检查是否选择了至少一个迁移选项
if (-not ($All -or $GradleOnly -or $AndroidOnly -or $PubOnly -or $JdkOnly)) {
    Write-Error "请指定要迁移的项目:"
    Write-Host "  -All          : 迁移所有项目"
    Write-Host "  -GradleOnly   : 仅迁移Gradle缓存"
    Write-Host "  -AndroidOnly  : 仅迁移Android配置"
    Write-Host "  -PubOnly      : 仅迁移Pub缓存"
    Write-Host "  -JdkOnly      : 仅迁移JDK"
    Write-Host "  -DryRun       : 试运行模式"
    Write-Host "`n示例: .\migrate_to_d_drive.ps1 -GradleOnly -AndroidOnly"
    exit 1
}

# 定义迁移配置
$migrations = @()

# Gradle缓存迁移
if ($All -or $GradleOnly) {
    $migrations += @{
        Name = "Gradle缓存"
        Source = "$env:USERPROFILE\.gradle"
        Destination = "D:\gradle_cache"
        UseSymLink = $false
        EnvVar = @{
            Name = "GRADLE_USER_HOME"
            Value = "D:\gradle_cache"
            Scope = "User"
        }
    }
}

# Android配置迁移
if ($All -or $AndroidOnly) {
    $migrations += @{
        Name = "Android配置"
        Source = "$env:USERPROFILE\.android"
        Destination = "D:\Android\.android"
        UseSymLink = $true  # Android需要符号链接
        EnvVar = $null
    }
}

# Pub缓存迁移
if ($All -or $PubOnly) {
    $migrations += @{
        Name = "Pub缓存"
        Source = "$env:LOCALAPPDATA\Pub\Cache"
        Destination = "D:\flutter_pub_cache"
        UseSymLink = $false
        EnvVar = @{
            Name = "PUB_CACHE"
            Value = "D:\flutter_pub_cache"
            Scope = "User"
        }
    }
}

# JDK迁移
if ($All -or $JdkOnly) {
    if (-not (Test-IsAdmin)) {
        Write-Error "JDK迁移需要管理员权限!请以管理员身份运行此脚本。"
        exit 1
    }

    $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if ($javaHome) {
        $migrations += @{
            Name = "Java JDK"
            Source = $javaHome
            Destination = "D:\Java\jdk-17"
            UseSymLink = $false
            EnvVar = @{
                Name = "JAVA_HOME"
                Value = "D:\Java\jdk-17"
                Scope = "Machine"
            }
        }
    } else {
        Write-Warning "未找到JAVA_HOME环境变量,跳过JDK迁移"
    }
}

# 显示迁移计划
Write-Info "迁移计划:"
foreach ($migration in $migrations) {
    $size = Get-DirectorySize $migration.Source
    Write-Host "  - $($migration.Name): ${size}GB" -ForegroundColor Yellow
}

if (-not $DryRun) {
    Write-Host "`n确认要开始迁移吗? (y/n): " -NoNewline -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -ne 'y') {
        Write-Warning "用户取消迁移"
        exit 0
    }
}

# 执行迁移
$successCount = 0
$totalCount = $migrations.Count

foreach ($migration in $migrations) {
    $result = Move-Directory -Source $migration.Source `
                             -Destination $migration.Destination `
                             -Name $migration.Name `
                             -UseSymLink:$migration.UseSymLink

    if ($result -and -not $DryRun) {
        # 设置环境变量
        if ($migration.EnvVar) {
            Write-Info "设置环境变量: $($migration.EnvVar.Name)"
            [Environment]::SetEnvironmentVariable(
                $migration.EnvVar.Name,
                $migration.EnvVar.Value,
                $migration.EnvVar.Scope
            )
            Write-Success "✓ 环境变量设置完成"
        }

        $successCount++
    }
}

# 特殊处理: Pub缓存还需要配置Flutter
if (($All -or $PubOnly) -and -not $DryRun) {
    Write-Info "`n配置Flutter使用新的Pub缓存路径..."
    try {
        flutter config --pub-cache D:\flutter_pub_cache 2>&1 | Out-Null
        Write-Success "✓ Flutter配置完成"
    } catch {
        Write-Warning "Flutter配置失败: $_"
    }
}

# 特殊处理: JDK还需要配置Flutter
if (($All -or $JdkOnly) -and -not $DryRun) {
    Write-Info "`n配置Flutter使用新的JDK路径..."
    try {
        flutter config --jdk-dir="D:\Java\jdk-17" 2>&1 | Out-Null
        Write-Success "✓ Flutter JDK配置完成"
    } catch {
        Write-Warning "Flutter JDK配置失败: $_"
    }
}

# 总结
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    迁移完成                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if (-not $DryRun) {
    Write-Info "成功迁移: $successCount / $totalCount"

    if ($successCount -gt 0) {
        Write-Success "`n✓ 迁移成功!"
        Write-Info "`n后续步骤:"
        Write-Host "  1. 重启命令行或IDE以使环境变量生效"
        Write-Host "  2. 运行 'flutter doctor -v' 验证环境"
        Write-Host "  3. 重新构建项目测试是否正常"

        # 显示释放的空间
        $drives = Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -eq 'C'}
        $freeGB = [math]::Round($drives[0].Free/1GB, 2)
        Write-Success "`nC盘当前剩余空间: ${freeGB}GB"
    }
} else {
    Write-Warning "`n[试运行完成] 未执行实际迁移操作"
    Write-Info "如需执行迁移,请移除 -DryRun 参数"
}

Write-Host ""
