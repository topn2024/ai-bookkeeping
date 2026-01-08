#!/usr/bin/env python3
import re
import os
from pathlib import Path

def fix_dead_null_aware(content):
    # Fix l10n.property ?? 'fallback' pattern
    pattern = r"(l10n\.\w+)\s*\?\?\s*['\"][^'\"]+['\"]"
    return re.sub(pattern, r'\1', content)

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = fix_dead_null_aware(content)

    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

def main():
    lib_path = Path('lib')
    fixed_count = 0

    for dart_file in lib_path.rglob('*.dart'):
        if process_file(dart_file):
            print(f'Fixed: {dart_file}')
            fixed_count += 1

    print(f'\nTotal files fixed: {fixed_count}')

if __name__ == '__main__':
    main()
