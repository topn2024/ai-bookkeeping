#!/usr/bin/env python3
"""
Test runner script for AI Bookkeeping API.

Usage:
    python scripts/run_tests.py              # Run all tests
    python scripts/run_tests.py --unit       # Run only unit tests
    python scripts/run_tests.py --coverage   # Run with coverage report
    python scripts/run_tests.py --html       # Generate HTML report
    python scripts/run_tests.py --module auth  # Run specific module tests
"""

import argparse
import subprocess
import sys
import os

# Add project root to path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)


def run_tests(args):
    """Run pytest with specified options."""
    cmd = ["python", "-m", "pytest"]

    # Add test path
    test_path = os.path.join(PROJECT_ROOT, "tests")

    # Module filter
    if args.module:
        test_path = os.path.join(test_path, f"test_{args.module}.py")

    cmd.append(test_path)

    # Verbosity
    if args.verbose:
        cmd.append("-v")
    else:
        cmd.append("-v")  # Default to verbose

    # Coverage
    if args.coverage:
        cmd.extend([
            "--cov=app",
            "--cov-report=term-missing",
            "--cov-report=html:coverage_html",
            "--cov-fail-under=50",  # Minimum coverage threshold
        ])

    # HTML report
    if args.html:
        cmd.extend([
            "--html=test_report.html",
            "--self-contained-html",
        ])

    # Markers
    if args.unit:
        cmd.extend(["-m", "unit"])
    elif args.integration:
        cmd.extend(["-m", "integration"])
    elif args.slow:
        cmd.extend(["-m", "slow"])

    # Parallel execution
    if args.parallel:
        cmd.extend(["-n", "auto"])

    # Stop on first failure
    if args.exitfirst:
        cmd.append("-x")

    # Show local variables on failure
    if args.showlocals:
        cmd.append("-l")

    # Print command
    print(f"Running: {' '.join(cmd)}")
    print("-" * 60)

    # Execute
    result = subprocess.run(cmd, cwd=PROJECT_ROOT)
    return result.returncode


def setup_test_database():
    """Create test database if it doesn't exist."""
    print("Setting up test database...")

    # Check if psql is available
    try:
        subprocess.run(["psql", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Warning: psql not found. Please create test database manually.")
        print("  CREATE DATABASE ai_bookkeeping_test;")
        return

    # Create test database
    create_db_cmd = [
        "psql",
        "-U", "ai_bookkeeping",
        "-c", "CREATE DATABASE ai_bookkeeping_test;",
    ]

    try:
        subprocess.run(create_db_cmd, capture_output=True)
        print("Test database created successfully.")
    except subprocess.CalledProcessError:
        print("Test database may already exist.")


def main():
    parser = argparse.ArgumentParser(
        description="Run tests for AI Bookkeeping API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # Test selection
    parser.add_argument(
        "--module", "-m",
        help="Run tests for specific module (auth, books, transactions, budgets, ai_features)",
    )
    parser.add_argument(
        "--unit",
        action="store_true",
        help="Run only unit tests",
    )
    parser.add_argument(
        "--integration",
        action="store_true",
        help="Run only integration tests",
    )
    parser.add_argument(
        "--slow",
        action="store_true",
        help="Include slow tests",
    )

    # Output options
    parser.add_argument(
        "--coverage", "-c",
        action="store_true",
        help="Run with coverage report",
    )
    parser.add_argument(
        "--html",
        action="store_true",
        help="Generate HTML test report",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output",
    )

    # Execution options
    parser.add_argument(
        "--parallel", "-p",
        action="store_true",
        help="Run tests in parallel (requires pytest-xdist)",
    )
    parser.add_argument(
        "--exitfirst", "-x",
        action="store_true",
        help="Stop on first failure",
    )
    parser.add_argument(
        "--showlocals", "-l",
        action="store_true",
        help="Show local variables on failure",
    )

    # Setup
    parser.add_argument(
        "--setup-db",
        action="store_true",
        help="Setup test database before running tests",
    )

    args = parser.parse_args()

    # Setup database if requested
    if args.setup_db:
        setup_test_database()

    # Run tests
    exit_code = run_tests(args)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
