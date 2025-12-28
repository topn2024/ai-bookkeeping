#!/bin/bash
# AI Bookkeeping - Full Test Suite Runner
# This script runs all tests for both backend and frontend

set -e

echo "============================================"
echo "AI Bookkeeping - Full Test Suite"
echo "============================================"
echo ""

# Set project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python
echo "Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python3 not found!${NC}"
    exit 1
fi
python3 --version

# Check Flutter
echo "Checking Flutter installation..."
SKIP_FLUTTER=0
if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}Warning: Flutter not found. Skipping frontend tests.${NC}"
    SKIP_FLUTTER=1
else
    flutter --version
fi

echo ""
echo "============================================"
echo "Running Backend Tests"
echo "============================================"
echo ""

cd "$PROJECT_ROOT/server"

# Create virtual environment if not exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt -q

# Run backend tests
echo "Running API tests..."
BACKEND_FAILED=0
python -m pytest tests/ -v --tb=short || BACKEND_FAILED=1

if [ $BACKEND_FAILED -eq 1 ]; then
    echo ""
    echo -e "${RED}Backend tests failed!${NC}"
else
    echo ""
    echo -e "${GREEN}Backend tests passed!${NC}"
fi

echo ""
echo "============================================"
echo "Running Frontend Tests"
echo "============================================"
echo ""

FRONTEND_FAILED=0
if [ $SKIP_FLUTTER -eq 1 ]; then
    echo "Skipping Flutter tests - Flutter not installed"
else
    cd "$PROJECT_ROOT/app"

    echo "Running Flutter tests..."
    flutter test || FRONTEND_FAILED=1

    if [ $FRONTEND_FAILED -eq 1 ]; then
        echo ""
        echo -e "${RED}Frontend tests failed!${NC}"
    else
        echo ""
        echo -e "${GREEN}Frontend tests passed!${NC}"
    fi
fi

echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
echo ""

if [ $BACKEND_FAILED -eq 1 ]; then
    echo -e "Backend Tests: ${RED}FAILED${NC}"
else
    echo -e "Backend Tests: ${GREEN}PASSED${NC}"
fi

if [ $SKIP_FLUTTER -eq 1 ]; then
    echo -e "Frontend Tests: ${YELLOW}SKIPPED${NC}"
elif [ $FRONTEND_FAILED -eq 1 ]; then
    echo -e "Frontend Tests: ${RED}FAILED${NC}"
else
    echo -e "Frontend Tests: ${GREEN}PASSED${NC}"
fi

echo ""

# Exit with error if any tests failed
if [ $BACKEND_FAILED -eq 1 ] || [ $FRONTEND_FAILED -eq 1 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi

echo -e "${GREEN}All tests passed!${NC}"
exit 0
