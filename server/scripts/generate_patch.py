#!/usr/bin/env python3
"""
APK Patch Generator

Generates bsdiff patches between two APK versions for incremental updates.

Usage:
    python generate_patch.py old_apk new_apk output_patch
    python generate_patch.py --help

Requirements:
    - bsdiff4 Python package: pip install bsdiff4
    - or bsdiff command line tool

Example:
    python generate_patch.py app_v1.0.0.apk app_v1.1.0.apk patch_1.0.0_to_1.1.0.patch
"""

import argparse
import hashlib
import os
import sys
import subprocess
import tempfile
import gzip
from pathlib import Path
from datetime import datetime

try:
    import bsdiff4
    HAS_BSDIFF4 = True
except ImportError:
    HAS_BSDIFF4 = False


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


def generate_patch_bsdiff4(old_path: str, new_path: str, patch_path: str) -> bool:
    """Generate patch using bsdiff4 Python library."""
    try:
        print(f"Reading old file: {old_path}")
        with open(old_path, 'rb') as f:
            old_data = f.read()

        print(f"Reading new file: {new_path}")
        with open(new_path, 'rb') as f:
            new_data = f.read()

        print("Generating patch...")
        patch_data = bsdiff4.diff(old_data, new_data)

        print(f"Writing patch to: {patch_path}")
        with open(patch_path, 'wb') as f:
            f.write(patch_data)

        return True
    except Exception as e:
        print(f"Error generating patch with bsdiff4: {e}")
        return False


def generate_patch_cmdline(old_path: str, new_path: str, patch_path: str) -> bool:
    """Generate patch using bsdiff command line tool."""
    try:
        # Try bsdiff command
        result = subprocess.run(
            ['bsdiff', old_path, new_path, patch_path],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            return True

        print(f"bsdiff failed: {result.stderr}")
        return False
    except FileNotFoundError:
        print("bsdiff command not found. Please install bsdiff or bsdiff4 Python package.")
        return False
    except Exception as e:
        print(f"Error running bsdiff: {e}")
        return False


def generate_patch(old_path: str, new_path: str, patch_path: str) -> bool:
    """Generate patch using available method."""
    if HAS_BSDIFF4:
        print("Using bsdiff4 Python library")
        return generate_patch_bsdiff4(old_path, new_path, patch_path)
    else:
        print("Using bsdiff command line tool")
        return generate_patch_cmdline(old_path, new_path, patch_path)


def verify_patch(old_path: str, patch_path: str, expected_md5: str) -> bool:
    """Verify patch by applying it and checking MD5."""
    if not HAS_BSDIFF4:
        print("Skipping verification (bsdiff4 not available)")
        return True

    try:
        print("Verifying patch...")

        with open(old_path, 'rb') as f:
            old_data = f.read()

        with open(patch_path, 'rb') as f:
            patch_data = f.read()

        # Apply patch
        new_data = bsdiff4.patch(old_data, patch_data)

        # Calculate MD5
        actual_md5 = hashlib.md5(new_data).hexdigest()

        if actual_md5 == expected_md5:
            print(f"Verification passed: {actual_md5}")
            return True
        else:
            print(f"Verification failed!")
            print(f"  Expected: {expected_md5}")
            print(f"  Actual:   {actual_md5}")
            return False

    except Exception as e:
        print(f"Verification error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Generate bsdiff patches for APK incremental updates',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('old_apk', help='Path to the old APK file')
    parser.add_argument('new_apk', help='Path to the new APK file')
    parser.add_argument('output_patch', help='Path for the output patch file')
    parser.add_argument('--verify', action='store_true',
                       help='Verify patch after generation')
    parser.add_argument('--json', action='store_true',
                       help='Output metadata as JSON')

    args = parser.parse_args()

    # Validate input files
    if not os.path.exists(args.old_apk):
        print(f"Error: Old APK not found: {args.old_apk}")
        sys.exit(1)

    if not os.path.exists(args.new_apk):
        print(f"Error: New APK not found: {args.new_apk}")
        sys.exit(1)

    # Create output directory if needed
    output_dir = os.path.dirname(args.output_patch)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Get file info
    old_size = get_file_size(args.old_apk)
    new_size = get_file_size(args.new_apk)
    old_md5 = calculate_md5(args.old_apk)
    new_md5 = calculate_md5(args.new_apk)

    print("=" * 60)
    print("APK Patch Generator")
    print("=" * 60)
    print(f"Old APK: {args.old_apk}")
    print(f"  Size: {old_size:,} bytes ({old_size / 1024 / 1024:.2f} MB)")
    print(f"  MD5:  {old_md5}")
    print()
    print(f"New APK: {args.new_apk}")
    print(f"  Size: {new_size:,} bytes ({new_size / 1024 / 1024:.2f} MB)")
    print(f"  MD5:  {new_md5}")
    print()

    # Generate patch
    print("Generating patch...")
    start_time = datetime.now()

    if not generate_patch(args.old_apk, args.new_apk, args.output_patch):
        print("Failed to generate patch!")
        sys.exit(1)

    duration = (datetime.now() - start_time).total_seconds()

    # Get patch info
    patch_size = get_file_size(args.output_patch)
    patch_md5 = calculate_md5(args.output_patch)
    savings = (1 - patch_size / new_size) * 100

    print()
    print("Patch generated successfully!")
    print(f"Output: {args.output_patch}")
    print(f"  Size: {patch_size:,} bytes ({patch_size / 1024 / 1024:.2f} MB)")
    print(f"  MD5:  {patch_md5}")
    print(f"  Savings: {savings:.1f}% smaller than full APK")
    print(f"  Time: {duration:.1f} seconds")

    # Verify if requested
    if args.verify:
        print()
        if not verify_patch(args.old_apk, args.output_patch, new_md5):
            print("Patch verification failed!")
            sys.exit(1)

    # Output JSON metadata
    if args.json:
        import json
        metadata = {
            "old_apk": {
                "path": args.old_apk,
                "size": old_size,
                "md5": old_md5
            },
            "new_apk": {
                "path": args.new_apk,
                "size": new_size,
                "md5": new_md5
            },
            "patch": {
                "path": args.output_patch,
                "size": patch_size,
                "md5": patch_md5,
                "savings_percent": round(savings, 1)
            },
            "generated_at": datetime.now().isoformat()
        }
        print()
        print("JSON Metadata:")
        print(json.dumps(metadata, indent=2))

    print()
    print("=" * 60)
    print("Done!")


if __name__ == '__main__':
    main()
