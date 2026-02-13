#!/usr/bin/env python3
"""
全面的页面导航分析工具
包括：Navigator.push、直接实例化、IndexedStack、条件渲染等所有访问方式
"""
import os
import re
from pathlib import Path
from collections import defaultdict

def find_dart_files(directory, pattern='*.dart'):
    """查找所有Dart文件"""
    files = []
    for root, dirs, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith('.dart'):
                files.append(os.path.join(root, filename))
    return files

def extract_page_name(file_path):
    """从文件路径提取页面名称"""
    return Path(file_path).stem

def analyze_file(file_path):
    """分析单个文件中的所有页面引用"""
    references = {
        'navigator_push': [],
        'direct_instantiation': [],
        'imports': []
    }

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 1. 查找 Navigator.push 导航
        nav_patterns = [
            r'MaterialPageRoute\(builder:.*?=>\s*(?:const\s+)?(\w+Page)\(',
            r'Navigator\.push.*?(\w+Page)\(',
        ]
        for pattern in nav_patterns:
            matches = re.findall(pattern, content)
            references['navigator_push'].extend(matches)

        # 2. 查找直接实例化（如 HomePage(), const TrendsPage()）
        instantiation_pattern = r'(?:const\s+)?(\w+Page)\(\)'
        matches = re.findall(instantiation_pattern, content)
        references['direct_instantiation'].extend(matches)

        # 3. 查找导入的页面
        import_pattern = r"import\s+['\"].*?/(\w+_page)\.dart['\"]"
        matches = re.findall(import_pattern, content)
        references['imports'].extend(matches)

    except Exception as e:
        print(f"Error reading {file_path}: {e}")

    return references

def main():
    app_dir = Path(__file__).parent.parent / 'app'
    pages_dir = app_dir / 'lib' / 'pages'
    lib_dir = app_dir / 'lib'

    print("=" * 80)
    print("全面的页面导航分析")
    print("=" * 80)
    print()

    # 1. 查找所有页面文件
    page_files = []
    for root, dirs, files in os.walk(pages_dir):
        for file in files:
            if file.endswith('_page.dart'):
                page_files.append(os.path.join(root, file))

    all_pages = {extract_page_name(f) for f in page_files}
    print(f"📄 总页面数: {len(all_pages)}")
    print()

    # 2. 分析所有Dart文件（不仅仅是页面文件）
    all_dart_files = find_dart_files(lib_dir)
    print(f"🔍 分析 {len(all_dart_files)} 个Dart文件...")
    print()

    # 收集所有页面引用
    page_references = defaultdict(lambda: {
        'referenced_by': set(),
        'access_methods': defaultdict(set)
    })

    for dart_file in all_dart_files:
        file_name = Path(dart_file).stem
        refs = analyze_file(dart_file)

        # 记录所有引用
        all_refs = set(refs['navigator_push'] + refs['direct_instantiation'] + refs['imports'])

        for page in all_refs:
            page_references[page]['referenced_by'].add(file_name)

            if page in refs['navigator_push']:
                page_references[page]['access_methods']['Navigator.push'].add(file_name)
            if page in refs['direct_instantiation']:
                page_references[page]['access_methods']['Direct Instantiation'].add(file_name)
            if page in refs['imports']:
                page_references[page]['access_methods']['Import'].add(file_name)

    # 3. 特殊检查：main.dart 和 main_navigation.dart
    special_files = {
        'main.dart': str(lib_dir / 'main.dart'),
        'main_navigation.dart': str(pages_dir / 'main_navigation.dart')
    }

    entry_points = set()
    for name, path in special_files.items():
        if os.path.exists(path):
            refs = analyze_file(path)
            all_refs = set(refs['navigator_push'] + refs['direct_instantiation'] + refs['imports'])
            entry_points.update(all_refs)
            print(f"🚪 {name} 引用的页面: {len(all_refs)} 个")
            for page in sorted(all_refs)[:10]:
                print(f"   - {page}")
            if len(all_refs) > 10:
                print(f"   ... 还有 {len(all_refs) - 10} 个")
            print()

    # 4. 分类页面
    referenced_pages = set(page_references.keys())
    unreferenced_pages = all_pages - referenced_pages

    # 可以从入口点访问的页面
    accessible_from_entry = entry_points & all_pages

    print("=" * 80)
    print("📊 分析结果")
    print("=" * 80)
    print()

    print(f"✅ 被引用的页面: {len(referenced_pages)} 个 ({len(referenced_pages)/len(all_pages)*100:.1f}%)")
    print(f"🚪 从入口点可访问: {len(accessible_from_entry)} 个")
    print(f"❌ 完全未被引用: {len(unreferenced_pages)} 个 ({len(unreferenced_pages)/len(all_pages)*100:.1f}%)")
    print()

    # 5. 显示从入口点可访问的页面
    print("=" * 80)
    print(f"🚪 从入口点直接可访问的页面 ({len(accessible_from_entry)} 个)")
    print("=" * 80)
    print()

    for page in sorted(accessible_from_entry):
        methods = page_references[page]['access_methods']
        method_str = ', '.join(methods.keys())
        print(f"  ✓ {page}")
        print(f"    访问方式: {method_str}")

        # 显示在哪些文件中被引用
        refs = page_references[page]['referenced_by']
        if 'main' in refs or 'main_navigation' in refs:
            print(f"    入口文件: {', '.join(r for r in refs if 'main' in r)}")
        print()

    # 6. 显示完全未被引用的页面
    if unreferenced_pages:
        print("=" * 80)
        print(f"❌ 完全未被引用的页面 ({len(unreferenced_pages)} 个)")
        print("=" * 80)
        print()
        print("这些页面在整个代码库中都没有被引用，可能是死代码：")
        print()

        for page in sorted(unreferenced_pages)[:50]:
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

        if len(unreferenced_pages) > 50:
            print(f"  ... 还有 {len(unreferenced_pages) - 50} 个未显示")
            print()

    # 7. 显示被引用最多的页面
    print("=" * 80)
    print("🔥 被引用最多的页面 (Top 20)")
    print("=" * 80)
    print()

    sorted_pages = sorted(
        [(page, len(info['referenced_by'])) for page, info in page_references.items()],
        key=lambda x: x[1],
        reverse=True
    )[:20]

    for i, (page, count) in enumerate(sorted_pages, 1):
        methods = list(page_references[page]['access_methods'].keys())
        print(f"{i}. {page} - 被 {count} 个文件引用")
        print(f"   访问方式: {', '.join(methods)}")
        print()

    # 8. 生成摘要报告
    output_file = Path(__file__).parent.parent / 'docs' / 'navigation_analysis_comprehensive.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 全面的页面导航分析报告\n\n")
        f.write(f"生成时间: {Path(__file__).stat().st_mtime}\n\n")
        f.write("## 统计摘要\n\n")
        f.write(f"- 总页面数: {len(all_pages)}\n")
        f.write(f"- 被引用的页面: {len(referenced_pages)} ({len(referenced_pages)/len(all_pages)*100:.1f}%)\n")
        f.write(f"- 从入口点可访问: {len(accessible_from_entry)}\n")
        f.write(f"- 完全未被引用: {len(unreferenced_pages)} ({len(unreferenced_pages)/len(all_pages)*100:.1f}%)\n\n")

        f.write("## 从入口点可访问的页面\n\n")
        for page in sorted(accessible_from_entry):
            methods = ', '.join(page_references[page]['access_methods'].keys())
            f.write(f"- **{page}** - {methods}\n")

        f.write("\n## 完全未被引用的页面\n\n")
        for page in sorted(unreferenced_pages):
            f.write(f"- {page}\n")

    print(f"📝 详细报告已保存到: {output_file}")
    print()

if __name__ == '__main__':
    main()
