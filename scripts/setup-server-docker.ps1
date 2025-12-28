# ============================================================
# Server Environment Setup with Docker
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "    AI Bookkeeping - Docker Services Setup" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# Check Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Docker not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker Desktop first:"
    Write-Host "https://www.docker.com/products/docker-desktop"
    exit 1
}

# Check if Docker is running
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker daemon is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again."
    exit 1
}

Write-Host "[OK] Docker is ready" -ForegroundColor Green

# Navigate to server directory
$serverPath = "D:\code\ai-bookkeeping\server"
Set-Location $serverPath

Write-Host ""
Write-Host "Starting services with Docker Compose..." -ForegroundColor Yellow

# Start services
docker compose up -d

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] All services started successfully!" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to start services" -ForegroundColor Red
    exit 1
}

# Wait for services to be ready
Write-Host ""
Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow

$maxRetries = 30
$retries = 0

# Wait for PostgreSQL
Write-Host "  Checking PostgreSQL..." -NoNewline
while ($retries -lt $maxRetries) {
    $pgReady = docker exec aibook-postgres pg_isready -U ai_bookkeeping 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Ready!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $retries++
    Write-Host "." -NoNewline
}

# Wait for Redis
$retries = 0
Write-Host "  Checking Redis..." -NoNewline
while ($retries -lt $maxRetries) {
    $redisReady = docker exec aibook-redis redis-cli -a "AiBookkeeping@2024" ping 2>&1
    if ($redisReady -match "PONG") {
        Write-Host " Ready!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 1
    $retries++
    Write-Host "." -NoNewline
}

# Wait for MinIO
$retries = 0
Write-Host "  Checking MinIO..." -NoNewline
while ($retries -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/minio/health/live" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            Write-Host " Ready!" -ForegroundColor Green
            break
        }
    } catch {}
    Start-Sleep -Seconds 1
    $retries++
    Write-Host "." -NoNewline
}

# Show running containers
Write-Host ""
Write-Host "Running containers:" -ForegroundColor Cyan
docker compose ps

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Services are ready!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host @"

Service Endpoints:
------------------
PostgreSQL:  localhost:5432
  - Database: ai_bookkeeping
  - User:     ai_bookkeeping
  - Password: AiBookkeeping@2024

Redis:       localhost:6379
  - Password: AiBookkeeping@2024

MinIO:       localhost:9000
  - Console:  http://localhost:9001
  - User:     minioadmin
  - Password: AiBookkeeping@2024

Adminer:     http://localhost:8080
  - System:   PostgreSQL
  - Server:   postgres
  - User:     ai_bookkeeping
  - Password: AiBookkeeping@2024

Next Steps:
-----------
1. Setup Python environment:
   cd $serverPath
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   pip install -r requirements.txt

2. Start the API server:
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

3. Open API docs:
   http://localhost:8000/docs

Docker Commands:
----------------
Stop services:    docker compose stop
Start services:   docker compose start
View logs:        docker compose logs -f
Remove all:       docker compose down -v

"@
