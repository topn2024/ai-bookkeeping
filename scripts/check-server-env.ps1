# ============================================================
# Server Environment Diagnostic Script
# AI Bookkeeping - Backend Services Check
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       Server Environment Diagnostic Report" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

$issues = @()
$warnings = @()

# ============================================================
# 1. Check Python
# ============================================================
Write-Host "[1/8] Checking Python..." -ForegroundColor Yellow

$pythonOk = $false
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonVersion = python --version 2>&1
    Write-Host "  [OK] $pythonVersion" -ForegroundColor Green
    $pythonOk = $true

    # Check pip
    $pipVersion = pip --version 2>&1
    Write-Host "  [OK] $pipVersion" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Python not installed" -ForegroundColor Red
    $issues += "Python not installed"
}

# ============================================================
# 2. Check Docker
# ============================================================
Write-Host ""
Write-Host "[2/8] Checking Docker..." -ForegroundColor Yellow

$dockerOk = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerVersion = docker --version 2>&1
    Write-Host "  [OK] $dockerVersion" -ForegroundColor Green
    $dockerOk = $true

    # Check Docker Compose
    $composeVersion = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $composeVersion" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Docker Compose not available" -ForegroundColor Yellow
        $warnings += "Docker Compose not available"
    }

    # Check if Docker is running
    $dockerPs = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Docker daemon is running" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Docker daemon not running" -ForegroundColor Yellow
        $warnings += "Docker daemon not running"
    }
} else {
    Write-Host "  [FAIL] Docker not installed" -ForegroundColor Red
    Write-Host "  [INFO] Docker is recommended for running services" -ForegroundColor Gray
    $issues += "Docker not installed"
}

# ============================================================
# 3. Check PostgreSQL
# ============================================================
Write-Host ""
Write-Host "[3/8] Checking PostgreSQL..." -ForegroundColor Yellow

$pgOk = $false

# Check if PostgreSQL service is running
$pgService = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue
if ($pgService) {
    if ($pgService.Status -eq "Running") {
        Write-Host "  [OK] PostgreSQL service is running" -ForegroundColor Green
        $pgOk = $true
    } else {
        Write-Host "  [WARN] PostgreSQL service exists but not running" -ForegroundColor Yellow
        $warnings += "PostgreSQL service not running"
    }
}

# Check port 5432
$pgPort = Get-NetTCPConnection -LocalPort 5432 -ErrorAction SilentlyContinue
if ($pgPort) {
    Write-Host "  [OK] Port 5432 is in use" -ForegroundColor Green
    $pgOk = $true
} else {
    if (-not $pgOk) {
        Write-Host "  [FAIL] PostgreSQL not running on port 5432" -ForegroundColor Red
        $issues += "PostgreSQL not running"
    }
}

# Check psql command
if (Get-Command psql -ErrorAction SilentlyContinue) {
    $psqlVersion = psql --version 2>&1
    Write-Host "  [OK] psql client: $psqlVersion" -ForegroundColor Green
}

# ============================================================
# 4. Check Redis
# ============================================================
Write-Host ""
Write-Host "[4/8] Checking Redis..." -ForegroundColor Yellow

$redisOk = $false

# Check Redis service
$redisService = Get-Service -Name "Redis*" -ErrorAction SilentlyContinue
if ($redisService) {
    if ($redisService.Status -eq "Running") {
        Write-Host "  [OK] Redis service is running" -ForegroundColor Green
        $redisOk = $true
    } else {
        Write-Host "  [WARN] Redis service exists but not running" -ForegroundColor Yellow
        $warnings += "Redis service not running"
    }
}

# Check port 6379
$redisPort = Get-NetTCPConnection -LocalPort 6379 -ErrorAction SilentlyContinue
if ($redisPort) {
    Write-Host "  [OK] Port 6379 is in use" -ForegroundColor Green
    $redisOk = $true
} else {
    if (-not $redisOk) {
        Write-Host "  [FAIL] Redis not running on port 6379" -ForegroundColor Red
        $issues += "Redis not running"
    }
}

# ============================================================
# 5. Check MinIO (Optional)
# ============================================================
Write-Host ""
Write-Host "[5/8] Checking MinIO (Optional)..." -ForegroundColor Yellow

$minioPort = Get-NetTCPConnection -LocalPort 9000 -ErrorAction SilentlyContinue
if ($minioPort) {
    Write-Host "  [OK] MinIO running on port 9000" -ForegroundColor Green
} else {
    Write-Host "  [INFO] MinIO not running (optional for dev)" -ForegroundColor Gray
}

# ============================================================
# 6. Check Python Dependencies
# ============================================================
Write-Host ""
Write-Host "[6/8] Checking Python Dependencies..." -ForegroundColor Yellow

$serverPath = "D:\code\ai-bookkeeping\server"
$requirementsPath = "$serverPath\requirements.txt"

if (Test-Path $requirementsPath) {
    Write-Host "  [OK] requirements.txt found" -ForegroundColor Green

    if ($pythonOk) {
        # Check if venv exists
        $venvPath = "$serverPath\venv"
        if (Test-Path $venvPath) {
            Write-Host "  [OK] Virtual environment exists" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Virtual environment not created" -ForegroundColor Yellow
            $warnings += "Python venv not created"
        }

        # Check key packages
        $keyPackages = @("fastapi", "sqlalchemy", "asyncpg", "redis", "uvicorn")
        $installedPackages = pip list --format=freeze 2>&1

        foreach ($pkg in $keyPackages) {
            if ($installedPackages -match $pkg) {
                Write-Host "  [OK] $pkg installed" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] $pkg not installed" -ForegroundColor Yellow
                $warnings += "$pkg not installed"
            }
        }
    }
} else {
    Write-Host "  [FAIL] requirements.txt not found" -ForegroundColor Red
    $issues += "requirements.txt not found"
}

# ============================================================
# 7. Check Configuration
# ============================================================
Write-Host ""
Write-Host "[7/8] Checking Configuration..." -ForegroundColor Yellow

$envPath = "$serverPath\.env"
if (Test-Path $envPath) {
    Write-Host "  [OK] .env file exists" -ForegroundColor Green

    # Parse .env and check key settings
    $envContent = Get-Content $envPath

    $hasDbUrl = $envContent | Where-Object { $_ -match "^DATABASE_URL=" }
    $hasRedisUrl = $envContent | Where-Object { $_ -match "^REDIS_URL=" }
    $hasJwtSecret = $envContent | Where-Object { $_ -match "^JWT_SECRET_KEY=" }

    if ($hasDbUrl) { Write-Host "  [OK] DATABASE_URL configured" -ForegroundColor Green }
    else { Write-Host "  [WARN] DATABASE_URL not configured" -ForegroundColor Yellow }

    if ($hasRedisUrl) { Write-Host "  [OK] REDIS_URL configured" -ForegroundColor Green }
    else { Write-Host "  [WARN] REDIS_URL not configured" -ForegroundColor Yellow }

    if ($hasJwtSecret) { Write-Host "  [OK] JWT_SECRET_KEY configured" -ForegroundColor Green }
    else { Write-Host "  [WARN] JWT_SECRET_KEY not configured" -ForegroundColor Yellow }

} else {
    Write-Host "  [FAIL] .env file not found" -ForegroundColor Red
    $issues += ".env file not found"
}

# ============================================================
# 8. Check Database Tables
# ============================================================
Write-Host ""
Write-Host "[8/8] Checking Database Tables..." -ForegroundColor Yellow

if ($pgOk -and (Get-Command psql -ErrorAction SilentlyContinue)) {
    # Try to connect and list tables
    $dbHost = "localhost"
    $dbPort = "5432"
    $dbName = "ai_bookkeeping"
    $dbUser = "ai_bookkeeping"

    Write-Host "  Attempting to connect to database..." -ForegroundColor Gray

    # Note: This requires psql and proper authentication
    $tables = psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -t -c "\dt" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Database connection successful" -ForegroundColor Green

        $expectedTables = @("users", "books", "accounts", "categories", "transactions", "budgets")
        foreach ($table in $expectedTables) {
            if ($tables -match $table) {
                Write-Host "  [OK] Table '$table' exists" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Table '$table' not found" -ForegroundColor Yellow
                $warnings += "Table $table not found"
            }
        }
    } else {
        Write-Host "  [INFO] Cannot connect to database (may need password)" -ForegroundColor Gray
        Write-Host "  [INFO] Tables will be created on first app startup" -ForegroundColor Gray
    }
} else {
    Write-Host "  [INFO] Cannot check tables (PostgreSQL not available)" -ForegroundColor Gray
    Write-Host "  [INFO] Tables will be auto-created when app starts" -ForegroundColor Gray
}

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Component Status:" -ForegroundColor White
Write-Host "  Python:      $(if($pythonOk){'OK'}else{'Missing'})" -ForegroundColor $(if($pythonOk){'Green'}else{'Red'})
Write-Host "  Docker:      $(if($dockerOk){'OK'}else{'Missing'})" -ForegroundColor $(if($dockerOk){'Green'}else{'Red'})
Write-Host "  PostgreSQL:  $(if($pgOk){'Running'}else{'Not Running'})" -ForegroundColor $(if($pgOk){'Green'}else{'Red'})
Write-Host "  Redis:       $(if($redisOk){'Running'}else{'Not Running'})" -ForegroundColor $(if($redisOk){'Green'}else{'Red'})

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host ""
    Write-Host "  All checks passed!" -ForegroundColor Green
} else {
    if ($issues.Count -gt 0) {
        Write-Host ""
        Write-Host "  Critical Issues ($($issues.Count)):" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }

    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
        $warnings | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (-not $dockerOk) {
    Write-Host @"

Option 1: Install Docker (Recommended)
---------------------------------------
1. Download Docker Desktop: https://www.docker.com/products/docker-desktop
2. Install and restart computer
3. Run: .\scripts\setup-server-docker.ps1

"@
}

if (-not $pgOk -or -not $redisOk) {
    Write-Host @"

Option 2: Install Services Manually
-----------------------------------
PostgreSQL: https://www.postgresql.org/download/windows/
Redis:      https://github.com/tporadowski/redis/releases

Or use the setup script:
.\scripts\setup-server-env.ps1

"@
}

if ($pythonOk -and ($warnings -contains "Python venv not created")) {
    Write-Host @"

Setup Python Environment:
-------------------------
cd D:\code\ai-bookkeeping\server
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

"@
}

Write-Host @"

Start Server:
-------------
cd D:\code\ai-bookkeeping\server
.\venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

API Documentation: http://localhost:8000/docs

"@
