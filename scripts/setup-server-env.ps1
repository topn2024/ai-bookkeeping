# ============================================================
# Server Environment Setup (Without Docker)
# Install PostgreSQL, Redis, and configure Python environment
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "    AI Bookkeeping - Server Environment Setup" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] Please run as Administrator!" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. Install Chocolatey (if needed)
# ============================================================
Write-Host ""
Write-Host "[1/5] Checking Chocolatey..." -ForegroundColor Yellow

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "[OK] Chocolatey installed" -ForegroundColor Green
} else {
    Write-Host "[OK] Chocolatey already installed" -ForegroundColor Green
}

# ============================================================
# 2. Install PostgreSQL
# ============================================================
Write-Host ""
Write-Host "[2/5] Installing PostgreSQL 15..." -ForegroundColor Yellow

$pgService = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
if ($pgService) {
    Write-Host "[OK] PostgreSQL already installed" -ForegroundColor Green
} else {
    Write-Host "Downloading and installing PostgreSQL..."
    choco install postgresql15 --params '/Password:AiBookkeeping@2024' -y

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Wait for service to start
    Start-Sleep -Seconds 5

    Write-Host "[OK] PostgreSQL installed" -ForegroundColor Green
}

# ============================================================
# 3. Install Redis
# ============================================================
Write-Host ""
Write-Host "[3/5] Installing Redis..." -ForegroundColor Yellow

$redisService = Get-Service -Name "Redis*" -ErrorAction SilentlyContinue
if ($redisService) {
    Write-Host "[OK] Redis already installed" -ForegroundColor Green
} else {
    Write-Host "Downloading and installing Redis..."
    choco install redis-64 -y

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Write-Host "[OK] Redis installed" -ForegroundColor Green
}

# ============================================================
# 4. Configure Database
# ============================================================
Write-Host ""
Write-Host "[4/5] Configuring Database..." -ForegroundColor Yellow

# Find psql path
$psqlPaths = @(
    "C:\Program Files\PostgreSQL\15\bin\psql.exe",
    "C:\Program Files\PostgreSQL\16\bin\psql.exe",
    "C:\Program Files\PostgreSQL\14\bin\psql.exe"
)

$psqlPath = $null
foreach ($path in $psqlPaths) {
    if (Test-Path $path) {
        $psqlPath = $path
        break
    }
}

if ($psqlPath) {
    Write-Host "Creating database and user..."

    # Create database setup SQL
    $sqlScript = @"
-- Create user if not exists
DO `$`$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ai_bookkeeping') THEN
        CREATE USER ai_bookkeeping WITH PASSWORD 'AiBookkeeping@2024';
    END IF;
END
`$`$;

-- Create database if not exists
SELECT 'CREATE DATABASE ai_bookkeeping OWNER ai_bookkeeping'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ai_bookkeeping')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ai_bookkeeping TO ai_bookkeeping;
"@

    $sqlFile = "$env:TEMP\init_db.sql"
    $sqlScript | Out-File -FilePath $sqlFile -Encoding UTF8

    # Execute SQL
    $env:PGPASSWORD = "AiBookkeeping@2024"
    & $psqlPath -h localhost -U postgres -f $sqlFile 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Database configured" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Database setup may need manual configuration" -ForegroundColor Yellow
    }

    Remove-Item $sqlFile -ErrorAction SilentlyContinue
} else {
    Write-Host "[WARN] psql not found, please configure database manually" -ForegroundColor Yellow
}

# ============================================================
# 5. Setup Python Environment
# ============================================================
Write-Host ""
Write-Host "[5/5] Setting up Python environment..." -ForegroundColor Yellow

$serverPath = "D:\code\ai-bookkeeping\server"

if (-not (Test-Path $serverPath)) {
    Write-Host "[ERROR] Server directory not found: $serverPath" -ForegroundColor Red
    exit 1
}

Set-Location $serverPath

# Create virtual environment
$venvPath = "$serverPath\venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "Creating virtual environment..."
    python -m venv venv
    Write-Host "[OK] Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "[OK] Virtual environment already exists" -ForegroundColor Green
}

# Activate and install dependencies
Write-Host "Installing Python dependencies..."
& "$venvPath\Scripts\pip.exe" install --upgrade pip
& "$venvPath\Scripts\pip.exe" install -r requirements.txt

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "[WARN] Some dependencies may have failed to install" -ForegroundColor Yellow
}

# ============================================================
# Start Services
# ============================================================
Write-Host ""
Write-Host "Starting services..." -ForegroundColor Yellow

# Start PostgreSQL service
$pgSvc = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
if ($pgSvc -and $pgSvc.Status -ne "Running") {
    Start-Service $pgSvc.Name
    Write-Host "[OK] PostgreSQL service started" -ForegroundColor Green
}

# Start Redis service
$redisSvc = Get-Service -Name "Redis*" -ErrorAction SilentlyContinue
if ($redisSvc -and $redisSvc.Status -ne "Running") {
    Start-Service $redisSvc.Name
    Write-Host "[OK] Redis service started" -ForegroundColor Green
}

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host @"

Service Configuration:
----------------------
PostgreSQL:
  - Host:     localhost:5432
  - Database: ai_bookkeeping
  - User:     ai_bookkeeping
  - Password: AiBookkeeping@2024

Redis:
  - Host:     localhost:6379
  - Password: AiBookkeeping@2024

Next Steps:
-----------
1. Activate Python environment:
   cd $serverPath
   .\venv\Scripts\Activate.ps1

2. Start the API server:
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

3. Open API documentation:
   http://localhost:8000/docs

Note: Database tables will be created automatically on first startup.

"@
