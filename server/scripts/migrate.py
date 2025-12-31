#!/usr/bin/env python3
"""
Database Migration Management Script

Provides CLI commands for managing Alembic database migrations with
backup/restore, version checking, and deployment integration.

Usage:
    python scripts/migrate.py status      # Show current migration status
    python scripts/migrate.py upgrade     # Upgrade to latest version
    python scripts/migrate.py downgrade   # Downgrade one version
    python scripts/migrate.py history     # Show migration history
    python scripts/migrate.py backup      # Create database backup
    python scripts/migrate.py restore     # Restore from latest backup
"""

import argparse
import asyncio
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.config import settings


class MigrationManager:
    """Manages database migrations with backup and safety checks."""

    def __init__(self):
        self.server_dir = Path(__file__).parent.parent
        self.backup_dir = self.server_dir / "backups" / "db"
        self.backup_dir.mkdir(parents=True, exist_ok=True)

    def _run_alembic(self, *args) -> tuple[int, str, str]:
        """Run alembic command and return exit code, stdout, stderr."""
        cmd = ["alembic"] + list(args)
        result = subprocess.run(
            cmd,
            cwd=self.server_dir,
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONPATH": str(self.server_dir)}
        )
        return result.returncode, result.stdout, result.stderr

    def _parse_db_url(self) -> dict:
        """Parse DATABASE_URL into components."""
        url = settings.DATABASE_URL
        # postgresql+asyncpg://user:pass@host:port/dbname
        if "://" not in url:
            raise ValueError("Invalid DATABASE_URL format")

        # Remove driver prefix
        url = url.split("://", 1)[1]

        # Parse credentials
        if "@" in url:
            creds, hostpart = url.rsplit("@", 1)
            if ":" in creds:
                user, password = creds.split(":", 1)
            else:
                user, password = creds, ""
        else:
            user, password = "", ""
            hostpart = url

        # Parse host and database
        if "/" in hostpart:
            hostport, dbname = hostpart.split("/", 1)
        else:
            hostport, dbname = hostpart, ""

        if ":" in hostport:
            host, port = hostport.split(":", 1)
        else:
            host, port = hostport, "5432"

        return {
            "user": user,
            "password": password,
            "host": host,
            "port": port,
            "dbname": dbname.split("?")[0]  # Remove query params
        }

    def status(self) -> int:
        """Show current migration status."""
        print("=" * 60)
        print("Database Migration Status")
        print("=" * 60)

        # Current revision
        code, stdout, stderr = self._run_alembic("current")
        if code != 0:
            print(f"Error getting current revision: {stderr}")
            return 1

        current = stdout.strip() or "None (not initialized)"
        print(f"\nCurrent revision: {current}")

        # Head revision
        code, stdout, stderr = self._run_alembic("heads")
        if code == 0:
            heads = stdout.strip() or "None"
            print(f"Latest revision:  {heads}")

        # Check for pending migrations
        code, stdout, stderr = self._run_alembic("check")
        if code == 0:
            print("\n✅ Database is up to date")
        else:
            print("\n⚠️  Pending migrations available")
            print(stderr.strip())

        print("=" * 60)
        return 0

    def history(self, verbose: bool = False) -> int:
        """Show migration history."""
        print("=" * 60)
        print("Migration History")
        print("=" * 60)

        args = ["history"]
        if verbose:
            args.append("-v")

        code, stdout, stderr = self._run_alembic(*args)
        if code != 0:
            print(f"Error: {stderr}")
            return 1

        print(stdout)
        return 0

    def backup(self, tag: str = None) -> int:
        """Create database backup using pg_dump."""
        try:
            db = self._parse_db_url()
        except Exception as e:
            print(f"Error parsing DATABASE_URL: {e}")
            return 1

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        tag_suffix = f"_{tag}" if tag else ""
        backup_file = self.backup_dir / f"backup_{timestamp}{tag_suffix}.sql"

        print(f"Creating backup: {backup_file}")

        # Set PGPASSWORD environment variable
        env = os.environ.copy()
        env["PGPASSWORD"] = db["password"]

        cmd = [
            "pg_dump",
            "-h", db["host"],
            "-p", db["port"],
            "-U", db["user"],
            "-d", db["dbname"],
            "-F", "c",  # Custom format (compressed)
            "-f", str(backup_file)
        ]

        result = subprocess.run(cmd, env=env, capture_output=True, text=True)

        if result.returncode != 0:
            print(f"Backup failed: {result.stderr}")
            return 1

        # Get file size
        size = backup_file.stat().st_size
        print(f"✅ Backup created successfully ({size / 1024 / 1024:.2f} MB)")

        # Clean old backups (keep last 10)
        self._cleanup_old_backups(keep=10)

        return 0

    def _cleanup_old_backups(self, keep: int = 10):
        """Remove old backup files, keeping the most recent ones."""
        backups = sorted(self.backup_dir.glob("backup_*.sql"), reverse=True)
        for old_backup in backups[keep:]:
            print(f"Removing old backup: {old_backup.name}")
            old_backup.unlink()

    def restore(self, backup_file: str = None) -> int:
        """Restore database from backup."""
        try:
            db = self._parse_db_url()
        except Exception as e:
            print(f"Error parsing DATABASE_URL: {e}")
            return 1

        if backup_file:
            backup_path = Path(backup_file)
        else:
            # Find latest backup
            backups = sorted(self.backup_dir.glob("backup_*.sql"), reverse=True)
            if not backups:
                print("No backup files found")
                return 1
            backup_path = backups[0]

        if not backup_path.exists():
            print(f"Backup file not found: {backup_path}")
            return 1

        print(f"⚠️  WARNING: This will restore from {backup_path}")
        confirm = input("Are you sure? (yes/no): ")
        if confirm.lower() != "yes":
            print("Restore cancelled")
            return 0

        print(f"Restoring from: {backup_path}")

        env = os.environ.copy()
        env["PGPASSWORD"] = db["password"]

        cmd = [
            "pg_restore",
            "-h", db["host"],
            "-p", db["port"],
            "-U", db["user"],
            "-d", db["dbname"],
            "-c",  # Clean (drop) before restore
            "--if-exists",
            str(backup_path)
        ]

        result = subprocess.run(cmd, env=env, capture_output=True, text=True)

        if result.returncode != 0:
            # pg_restore returns non-zero for warnings too
            if "error" in result.stderr.lower():
                print(f"Restore failed: {result.stderr}")
                return 1
            else:
                print(f"Restore completed with warnings: {result.stderr}")

        print("✅ Database restored successfully")
        return 0

    def upgrade(self, revision: str = "head", backup: bool = True) -> int:
        """Upgrade database to specified revision."""
        print("=" * 60)
        print(f"Upgrading database to: {revision}")
        print("=" * 60)

        # Create backup before upgrade
        if backup:
            print("\nStep 1: Creating pre-upgrade backup...")
            if self.backup("pre_upgrade") != 0:
                print("⚠️  Backup failed, continuing anyway...")

        # Show what will be done
        print("\nStep 2: Checking pending migrations...")
        code, stdout, stderr = self._run_alembic("current")
        current = stdout.strip().split()[0] if stdout.strip() else "None"
        print(f"Current: {current} -> Target: {revision}")

        # Run upgrade
        print("\nStep 3: Running migrations...")
        code, stdout, stderr = self._run_alembic("upgrade", revision)

        if code != 0:
            print(f"\n❌ Migration failed!")
            print(f"Error: {stderr}")
            print("\nTo rollback, run: python scripts/migrate.py restore")
            return 1

        print(stdout)

        # Verify
        print("\nStep 4: Verifying migration...")
        code, stdout, stderr = self._run_alembic("current")
        print(f"New revision: {stdout.strip()}")

        print("\n✅ Upgrade completed successfully")
        print("=" * 60)
        return 0

    def downgrade(self, revision: str = "-1", backup: bool = True) -> int:
        """Downgrade database to specified revision."""
        print("=" * 60)
        print(f"Downgrading database: {revision}")
        print("=" * 60)

        # Create backup before downgrade
        if backup:
            print("\nStep 1: Creating pre-downgrade backup...")
            if self.backup("pre_downgrade") != 0:
                print("⚠️  Backup failed, continuing anyway...")

        # Confirm dangerous operation
        print("\n⚠️  WARNING: Downgrade may cause data loss!")
        confirm = input("Are you sure you want to continue? (yes/no): ")
        if confirm.lower() != "yes":
            print("Downgrade cancelled")
            return 0

        # Show current state
        print("\nStep 2: Current migration status...")
        code, stdout, stderr = self._run_alembic("current")
        current = stdout.strip().split()[0] if stdout.strip() else "None"
        print(f"Current: {current}")

        # Run downgrade
        print("\nStep 3: Running downgrade...")
        code, stdout, stderr = self._run_alembic("downgrade", revision)

        if code != 0:
            print(f"\n❌ Downgrade failed!")
            print(f"Error: {stderr}")
            return 1

        print(stdout)

        # Verify
        print("\nStep 4: Verifying downgrade...")
        code, stdout, stderr = self._run_alembic("current")
        print(f"New revision: {stdout.strip() or 'None'}")

        print("\n✅ Downgrade completed successfully")
        print("=" * 60)
        return 0

    def create(self, message: str) -> int:
        """Create a new migration revision."""
        if not message:
            print("Error: Migration message is required")
            return 1

        print(f"Creating new migration: {message}")

        code, stdout, stderr = self._run_alembic("revision", "--autogenerate", "-m", message)

        if code != 0:
            print(f"Error: {stderr}")
            return 1

        print(stdout)
        print("\n✅ Migration created successfully")
        print("Remember to review the generated migration file!")
        return 0

    def check(self) -> int:
        """Check if database is up to date."""
        code, stdout, stderr = self._run_alembic("check")
        if code == 0:
            print("✅ Database is up to date")
            return 0
        else:
            print("⚠️  Database needs migration")
            return 1


def main():
    parser = argparse.ArgumentParser(
        description="Database Migration Management",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/migrate.py status              Show current status
  python scripts/migrate.py upgrade             Upgrade to latest
  python scripts/migrate.py upgrade 0003        Upgrade to specific revision
  python scripts/migrate.py downgrade           Downgrade one version
  python scripts/migrate.py downgrade base      Downgrade to empty database
  python scripts/migrate.py history             Show migration history
  python scripts/migrate.py backup              Create database backup
  python scripts/migrate.py restore             Restore latest backup
  python scripts/migrate.py create "Add xyz"    Create new migration
        """
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Status command
    subparsers.add_parser("status", help="Show migration status")

    # History command
    history_parser = subparsers.add_parser("history", help="Show migration history")
    history_parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")

    # Upgrade command
    upgrade_parser = subparsers.add_parser("upgrade", help="Upgrade database")
    upgrade_parser.add_argument("revision", nargs="?", default="head", help="Target revision")
    upgrade_parser.add_argument("--no-backup", action="store_true", help="Skip backup")

    # Downgrade command
    downgrade_parser = subparsers.add_parser("downgrade", help="Downgrade database")
    downgrade_parser.add_argument("revision", nargs="?", default="-1", help="Target revision")
    downgrade_parser.add_argument("--no-backup", action="store_true", help="Skip backup")

    # Backup command
    backup_parser = subparsers.add_parser("backup", help="Create database backup")
    backup_parser.add_argument("--tag", help="Optional backup tag")

    # Restore command
    restore_parser = subparsers.add_parser("restore", help="Restore from backup")
    restore_parser.add_argument("--file", help="Backup file path")

    # Create command
    create_parser = subparsers.add_parser("create", help="Create new migration")
    create_parser.add_argument("message", help="Migration description")

    # Check command
    subparsers.add_parser("check", help="Check if database is up to date")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    manager = MigrationManager()

    if args.command == "status":
        return manager.status()
    elif args.command == "history":
        return manager.history(verbose=args.verbose)
    elif args.command == "upgrade":
        return manager.upgrade(args.revision, backup=not args.no_backup)
    elif args.command == "downgrade":
        return manager.downgrade(args.revision, backup=not args.no_backup)
    elif args.command == "backup":
        return manager.backup(tag=args.tag)
    elif args.command == "restore":
        return manager.restore(backup_file=args.file)
    elif args.command == "create":
        return manager.create(args.message)
    elif args.command == "check":
        return manager.check()
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
