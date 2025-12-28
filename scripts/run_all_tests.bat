@echo off
REM AI Bookkeeping - Full Test Suite Runner
REM This script runs all tests for both backend and frontend

echo ============================================
echo AI Bookkeeping - Full Test Suite
echo ============================================
echo.

REM Set project root
set PROJECT_ROOT=%~dp0..

REM Check Python
echo Checking Python installation...
python --version
if %ERRORLEVEL% NEQ 0 (
    echo Error: Python not found!
    exit /b 1
)

REM Check Flutter
echo Checking Flutter installation...
flutter --version
if %ERRORLEVEL% NEQ 0 (
    echo Warning: Flutter not found. Skipping frontend tests.
    set SKIP_FLUTTER=1
)

echo.
echo ============================================
echo Running Backend Tests
echo ============================================
echo.

cd %PROJECT_ROOT%\server

REM Install test dependencies
echo Installing test dependencies...
pip install pytest pytest-asyncio pytest-cov pytest-html httpx -q

REM Run backend tests
echo Running API tests...
python -m pytest tests/ -v --tb=short

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Backend tests failed!
    set BACKEND_FAILED=1
) else (
    echo.
    echo Backend tests passed!
)

echo.
echo ============================================
echo Running Frontend Tests
echo ============================================
echo.

if defined SKIP_FLUTTER (
    echo Skipping Flutter tests - Flutter not installed
) else (
    cd %PROJECT_ROOT%\app

    echo Running Flutter tests...
    flutter test

    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo Frontend tests failed!
        set FRONTEND_FAILED=1
    ) else (
        echo.
        echo Frontend tests passed!
    )
)

echo.
echo ============================================
echo Test Summary
echo ============================================
echo.

if defined BACKEND_FAILED (
    echo Backend Tests: FAILED
) else (
    echo Backend Tests: PASSED
)

if defined SKIP_FLUTTER (
    echo Frontend Tests: SKIPPED
) else if defined FRONTEND_FAILED (
    echo Frontend Tests: FAILED
) else (
    echo Frontend Tests: PASSED
)

echo.

if defined BACKEND_FAILED (
    exit /b 1
)
if defined FRONTEND_FAILED (
    exit /b 1
)

echo All tests passed!
exit /b 0
