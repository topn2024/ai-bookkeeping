#!/usr/bin/env python3
"""
查找完全孤立的页面（既不导航到其他页面，也不被其他页面导航到）
"""
import os
import re
from pathlib import Path
from collections import defaultdict

def find_dart_pages(pages_dir):
    """查找所有Dart页面文件"""
    pages = []
    for root, dirs, files in os.walk(pages_dir):
        for file in files:
            if file.endswith('_page.dart'):
                pages.append(os.path.join(root, file))
    return pages

def extract_page_name(file_path):
    """从文件路径提取页面名称"""
    return Path(file_path).stem

def extract_navigations(file_path):
    """从Dart文件中提取导航目标"""
    navigations = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 匹配各种导航模式
        patterns = [
            r'MaterialPageRoute\(builder:.*?=>\s*(?:const\s+)?(\w+Page)\(',
            r'Navigator\.push.*?(\w+Page)\(',
            r'Navigator\.pushNamed\([^,]+,\s*[\'"]([^\'"]+)[\'"]',
        ]

        for pattern in patterns:
            matches = re.findall(pattern, content)
            navigations.extend(matches)

    except Exception as e:
        print(f"Error reading {file_path}: {e}")

    return list(set(navigations))

def check_main_navigation(main_dart_path):
    """检查main.dart中引用的页面"""
    referenced = []
    try:
        with open(main_dart_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 查找所有导入的页面
        imports = re.findall(r"import\s+['\"].*?/(\w+_page)\.dart['\"]", content)
        referenced.extend(imports)

        # 查找直接使用的页面
        pages = re.findall(r'(\w+Page)\(', content)
        referenced.extend(pages)

    except Exception as e:
        print(f"Error reading main.dart: {e}")

    return list(set(referenced))

def main():
    app_dir = Path(__file__).parent.parent / 'app'
    pages_dir = app_dir / 'lib' / 'pages'
    main_dart = app_dir / 'lib' / 'main.dart'

    print("=" * 80)
    print("查找完全孤立的页面")
    print("=" * 80)
    print()

    # 查找所有页面文件
    page_files = find_dart_pages(str(pages_dir))
    all_pages = {extract_page_name(f) for f in page_files}
    print(f"📄 总页面数: {len(all_pages)}")
    print()

    # 构建导航映射（哪些页面导航到哪些页面）
    navigation_map = defaultdict(set)
    for page_file in page_files:
        page_name = extract_page_name(page_file)
        targets = extract_navigations(page_file)
        navigation_map[page_name].update(targets)

    # 构建反向映射（哪些页面被导航到）
    navigated_to = set()
    for source, targets in navigation_map.items():
        navigated_to.update(targets)

    # 检查main.dart中引用的页面
    main_referenced = check_main_navigation(str(main_dart))
    navigated_to.update(main_referenced)

    print(f"🔗 有导航出口的页面数: {len([p for p in navigation_map if navigation_map[p]])}")
    print(f"🎯 被其他页面导航到的页面数: {len(navigated_to)}")
    print(f"🏠 main.dart中引用的页面数: {len(main_referenced)}")
    print()

    # 查找完全孤立的页面
    pages_with_outgoing = {p for p in navigation_map if navigation_map[p]}
    pages_with_incoming = navigated_to

    # 孤立页面 = 既没有导航出口，也没有被导航到
    orphaned_pages = all_pages - pages_with_outgoing - pages_with_incoming

    print("=" * 80)
    print(f"🚨 完全孤立的页面 ({len(orphaned_pages)} 个)")
    print("=" * 80)
    print()

    if orphaned_pages:
        print("这些页面既不导航到其他页面，也不被任何页面导航到：")
        print("（这些可能是死代码，或者通过其他方式访问，如命名路由、深链接等）")
        print()

        for page in sorted(orphaned_pages):
            # 查找文件路径
            page_file = None
            for f in page_files:
                if extract_page_name(f) == page:
                    page_file = f
                    break

            if page_file:
                rel_path = Path(page_file).relative_to(app_dir.parent)
                print(f"  ❌ {page}")
                print(f"     📁 {rel_path}")
                print()
    else:
        print("✅ 没有发现完全孤立的页面！所有页面都至少有一个导航连接。")

    print()
    print("=" * 80)
    print("📊 其他统计")
    print("=" * 80)
    print()

    # 只有导航出口，但没有被导航到的页面（可能是入口页面）
    entry_pages = pages_with_outgoing - pages_with_incoming
    print(f"🚪 可能的入口页面 ({len(entry_pages)} 个):")
    print("   （有导航出口，但不被其他页面导航到）")
    for page in sorted(entry_pages)[:10]:
        print(f"   - {page}")
    if len(entry_pages) > 10:
        print(f"   ... 还有 {len(entry_pages) - 10} 个")
    print()

    # 只被导航到，但没有导航出口的页面（终点页面）
    terminal_pages = pages_with_incoming - pages_with_outgoing
    print(f"🏁 终点页面 ({len(terminal_pages)} 个):")
    print("   （被其他页面导航到，但自己不导航到其他页面）")
    for page in sorted(terminal_pages)[:10]:
        print(f"   - {page}")
    if len(terminal_pages) > 10:
        print(f"   ... 还有 {len(terminal_pages) - 10} 个")
    print()

    # 既有导航出口，又被导航到的页面（中间页面）
    intermediate_pages = pages_with_outgoing & pages_with_incoming
    print(f"🔄 中间页面 ({len(intermediate_pages)} 个):")
    print("   （既导航到其他页面，又被其他页面导航到）")
    for page in sorted(intermediate_pages)[:10]:
        out_count = len(navigation_map[page])
        print(f"   - {page} (导航到 {out_count} 个页面)")
    if len(intermediate_pages) > 10:
        print(f"   ... 还有 {len(intermediate_pages) - 10} 个")
    print()

if __name__ == '__main__':
    main()
