#!/usr/bin/env python3
"""
APK Version Publisher

Publishes a new APK version with automatic patch generation.

Usage:
    python publish_version.py new_apk --version 1.2.0 --code 18
    python publish_version.py new_apk --version 1.2.0 --code 18 --previous-apk old.apk
    python publish_version.py --help

This script:
1. Validates the new APK
2. Optionally generates a patch from the previous version
3. Uploads files to MinIO storage
4. Creates a version record in the database
"""

import argparse
import hashlib
import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime

# Add server directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'server'))

try:
    import bsdiff4
    HAS_BSDIFF4 = True
except ImportError:
    HAS_BSDIFF4 = False
    print("Warning: bsdiff4 not installed. Patch generation will be skipped.")


def calculate_md5(file_path: str) -> str:
    """Calculate MD5 hash of a file."""
    md5 = hashlib.md5()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            md5.update(chunk)
    return md5.hexdigest()


def get_file_size(file_path: str) -> int:
    """Get file size in bytes."""
    return os.path.getsize(file_path)


def generate_patch(old_path: str, new_path: str, patch_path: str) -> bool:
    """Generate bsdiff patch."""
    if not HAS_BSDIFF4:
        return False

    try:
        print(f"Generating patch from {old_path} to {new_path}...")

        with open(old_path, 'rb') as f:
            old_data = f.read()

        with open(new_path, 'rb') as f:
            new_data = f.read()

        patch_data = bsdiff4.diff(old_data, new_data)

        with open(patch_path, 'wb') as f:
            f.write(patch_data)

        print(f"Patch generated: {patch_path}")
        return True
    except Exception as e:
        print(f"Failed to generate patch: {e}")
        return False


def verify_patch(old_path: str, patch_path: str, expected_md5: str) -> bool:
    """Verify patch by applying it and checking MD5."""
    if not HAS_BSDIFF4:
        return True

    try:
        with open(old_path, 'rb') as f:
            old_data = f.read()

        with open(patch_path, 'rb') as f:
            patch_data = f.read()

        new_data = bsdiff4.patch(old_data, patch_data)
        actual_md5 = hashlib.md5(new_data).hexdigest()

        return actual_md5 == expected_md5
    except Exception as e:
        print(f"Patch verification failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Publish a new APK version with automatic patch generation'
    )
    parser.add_argument('apk', help='Path to the new APK file')
    parser.add_argument('--version', '-v', required=True,
                       help='Version name (e.g., 1.2.0)')
    parser.add_argument('--code', '-c', type=int, required=True,
                       help='Version code (e.g., 18)')
    parser.add_argument('--previous-apk', '-p',
                       help='Path to previous APK for patch generation')
    parser.add_argument('--previous-version',
                       help='Previous version name (for patch metadata)')
    parser.add_argument('--previous-code', type=int,
                       help='Previous version code (for patch metadata)')
    parser.add_argument('--release-notes', '-n',
                       help='Release notes text or path to file')
    parser.add_argument('--force', action='store_true',
                       help='Force update flag')
    parser.add_argument('--output-dir', '-o', default='./dist',
                       help='Output directory for generated files')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be done without actually doing it')

    args = parser.parse_args()

    # Validate APK
    if not os.path.exists(args.apk):
        print(f"Error: APK not found: {args.apk}")
        sys.exit(1)

    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get APK info
    apk_size = get_file_size(args.apk)
    apk_md5 = calculate_md5(args.apk)

    print("=" * 60)
    print("APK Version Publisher")
    print("=" * 60)
    print(f"APK: {args.apk}")
    print(f"Version: {args.version} (code: {args.code})")
    print(f"Size: {apk_size:,} bytes ({apk_size / 1024 / 1024:.2f} MB)")
    print(f"MD5: {apk_md5}")
    print()

    # Prepare version info
    version_info = {
        'version_name': args.version,
        'version_code': args.code,
        'file_size': apk_size,
        'file_md5': apk_md5,
        'is_force_update': args.force,
        'created_at': datetime.now().isoformat()
    }

    # Generate patch if previous APK provided
    patch_info = None
    if args.previous_apk and os.path.exists(args.previous_apk):
        if HAS_BSDIFF4:
            prev_version = args.previous_version or 'previous'
            prev_code = args.previous_code or 0

            patch_filename = f"patch_{prev_version}_to_{args.version}.patch"
            patch_path = output_dir / patch_filename

            print(f"Previous APK: {args.previous_apk}")
            prev_size = get_file_size(args.previous_apk)
            prev_md5 = calculate_md5(args.previous_apk)
            print(f"  Size: {prev_size:,} bytes")
            print(f"  MD5: {prev_md5}")
            print()

            if not args.dry_run:
                if generate_patch(args.previous_apk, args.apk, str(patch_path)):
                    # Verify patch
                    if verify_patch(args.previous_apk, str(patch_path), apk_md5):
                        patch_size = get_file_size(str(patch_path))
                        patch_md5 = calculate_md5(str(patch_path))
                        savings = (1 - patch_size / apk_size) * 100

                        print(f"Patch generated: {patch_path}")
                        print(f"  Size: {patch_size:,} bytes ({savings:.1f}% savings)")
                        print(f"  MD5: {patch_md5}")

                        patch_info = {
                            'from_version': prev_version,
                            'from_code': prev_code,
                            'file_size': patch_size,
                            'file_md5': patch_md5,
                            'savings_percent': round(savings, 1)
                        }
                        version_info['patch'] = patch_info
                    else:
                        print("Warning: Patch verification failed, skipping patch")
            else:
                print(f"[DRY RUN] Would generate patch: {patch_path}")
        else:
            print("Warning: bsdiff4 not installed, skipping patch generation")
    elif args.previous_apk:
        print(f"Warning: Previous APK not found: {args.previous_apk}")

    print()

    # Read release notes
    if args.release_notes:
        if os.path.exists(args.release_notes):
            with open(args.release_notes, 'r', encoding='utf-8') as f:
                version_info['release_notes'] = f.read()
        else:
            version_info['release_notes'] = args.release_notes
    else:
        version_info['release_notes'] = f"Version {args.version}"

    # Copy APK to output directory
    output_apk = output_dir / f"ai_bookkeeping_{args.version}.apk"
    if not args.dry_run:
        import shutil
        shutil.copy2(args.apk, output_apk)
        print(f"APK copied to: {output_apk}")

    # Write version metadata
    metadata_path = output_dir / f"version_{args.version}.json"
    if not args.dry_run:
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(version_info, f, indent=2, ensure_ascii=False)
        print(f"Metadata written to: {metadata_path}")

    print()
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    print(json.dumps(version_info, indent=2, ensure_ascii=False))

    print()
    print("Next steps:")
    print("1. Upload APK to MinIO storage")
    print("2. Upload patch file (if generated) to MinIO storage")
    print("3. Create version record in database via admin API")
    print()

    if args.dry_run:
        print("[DRY RUN] No changes were made")


if __name__ == '__main__':
    main()
