#!/usr/bin/env python3
"""
修复版：全面的页面导航分析工具
正确处理文件名和类名的映射
"""
import os
import re
from pathlib import Path
from collections import defaultdict

def find_dart_files(directory):
    """查找所有Dart文件"""
    files = []
    for root, dirs, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith('.dart'):
                files.append(os.path.join(root, filename))
    return files

def file_name_to_class_name(file_name):
    """将文件名转换为类名
    例如: home_page -> HomePage, add_transaction_page -> AddTransactionPage
    """
    parts = file_name.replace('_page', '').split('_')
    return ''.join(word.capitalize() for word in parts) + 'Page'

def class_name_to_file_name(class_name):
    """将类名转换为文件名
    例如: HomePage -> home_page, AddTransactionPage -> add_transaction_page
    """
    # 移除 Page 后缀
    name = class_name.replace('Page', '')
    # 将驼峰命名转换为下划线命名
    result = re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower()
    return result + '_page'

def analyze_file(file_path):
    """分析单个文件中的所有页面引用"""
    references = set()

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 查找所有页面类的引用（PascalCase + Page）
        pattern = r'\b([A-Z][a-zA-Z]*Page)\b'
        matches = re.findall(pattern, content)
        references.update(matches)

    except Exception as e:
        print(f"Error reading {file_path}: {e}")

    return references

def main():
    app_dir = Path(__file__).parent.parent / 'app'
    pages_dir = app_dir / 'lib' / 'pages'
    lib_dir = app_dir / 'lib'

    print("=" * 80)
    print("全面的页面导航分析（修复版）")
    print("=" * 80)
    print()

    # 1. 查找所有页面文件并建立映射
    page_files = []
    for root, dirs, files in os.walk(pages_dir):
        for file in files:
            if file.endswith('_page.dart'):
                page_files.append(os.path.join(root, file))

    # 建立文件名到类名的映射
    file_to_class = {}
    class_to_file = {}

    for page_file in page_files:
        file_name = Path(page_file).stem  # 例如: home_page
        class_name = file_name_to_class_name(file_name)  # 例如: HomePage
        file_to_class[file_name] = class_name
        class_to_file[class_name] = page_file

    print(f"📄 总页面数: {len(class_to_file)}")
    print()

    # 2. 分析所有Dart文件
    all_dart_files = find_dart_files(lib_dir)
    print(f"🔍 分析 {len(all_dart_files)} 个Dart文件...")
    print()

    # 收集所有页面引用（使用类名）
    page_references = defaultdict(lambda: {
        'referenced_by': set(),
        'reference_count': 0
    })

    for dart_file in all_dart_files:
        file_name = Path(dart_file).stem
        refs = analyze_file(dart_file)

        for class_name in refs:
            if class_name in class_to_file:
                page_references[class_name]['referenced_by'].add(file_name)
                page_references[class_name]['reference_count'] += 1

    # 3. 特殊检查：main.dart 和 main_navigation.dart
    special_files = {
        'main.dart': str(lib_dir / 'main.dart'),
        'main_navigation.dart': str(pages_dir / 'main_navigation.dart')
    }

    entry_points = set()
    for name, path in special_files.items():
        if os.path.exists(path):
            refs = analyze_file(path)
            valid_refs = refs & set(class_to_file.keys())
            entry_points.update(valid_refs)
            print(f"🚪 {name} 引用的页面: {len(valid_refs)} 个")
            for page in sorted(valid_refs):
                print(f"   - {page}")
            print()

    # 4. 分类页面
    referenced_pages = set(page_references.keys())
    all_page_classes = set(class_to_file.keys())
    unreferenced_pages = all_page_classes - referenced_pages

    # 可以从入口点访问的页面
    accessible_from_entry = entry_points & all_page_classes

    print("=" * 80)
    print("📊 分析结果")
    print("=" * 80)
    print()

    print(f"✅ 被引用的页面: {len(referenced_pages)} 个 ({len(referenced_pages)/len(all_page_classes)*100:.1f}%)")
    print(f"🚪 从入口点可访问: {len(accessible_from_entry)} 个")
    print(f"❌ 完全未被引用: {len(unreferenced_pages)} 个 ({len(unreferenced_pages)/len(all_page_classes)*100:.1f}%)")
    print()

    # 5. 显示从入口点可访问的页面
    print("=" * 80)
    print(f"🚪 从入口点直接可访问的页面 ({len(accessible_from_entry)} 个)")
    print("=" * 80)
    print()

    for page in sorted(accessible_from_entry):
        ref_count = page_references[page]['reference_count']
        refs = page_references[page]['referenced_by']
        print(f"  ✓ {page}")
        print(f"    被引用 {ref_count} 次")
        if 'main' in ' '.join(refs) or 'main_navigation' in ' '.join(refs):
            entry_refs = [r for r in refs if 'main' in r]
            print(f"    入口文件: {', '.join(entry_refs)}")
        print()

    # 6. 显示完全未被引用的页面
    if unreferenced_pages:
        print("=" * 80)
        print(f"❌ 完全未被引用的页面 ({len(unreferenced_pages)} 个)")
        print("=" * 80)
        print()
        print("⚠️  这些页面在整个代码库中都没有被引用，可能是死代码：")
        print()

        for page in sorted(unreferenced_pages)[:30]:
            page_file = class_to_file[page]
            rel_path = Path(page_file).relative_to(app_dir.parent)
            print(f"  ❌ {page}")
            print(f"     📁 {rel_path}")
            print()

        if len(unreferenced_pages) > 30:
            print(f"  ... 还有 {len(unreferenced_pages) - 30} 个未显示")
            print()

    # 7. 显示被引用最多的页面
    print("=" * 80)
    print("🔥 被引用最多的页面 (Top 20)")
    print("=" * 80)
    print()

    sorted_pages = sorted(
        [(page, info['reference_count']) for page, info in page_references.items()],
        key=lambda x: x[1],
        reverse=True
    )[:20]

    for i, (page, count) in enumerate(sorted_pages, 1):
        refs = page_references[page]['referenced_by']
        print(f"{i}. {page}")
        print(f"   被引用 {count} 次，在 {len(refs)} 个文件中")
        print()

    # 8. 生成摘要报告
    output_file = Path(__file__).parent.parent / 'docs' / 'navigation_analysis_final.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# 页面导航分析最终报告\n\n")
        f.write("## 统计摘要\n\n")
        f.write(f"- 总页面数: {len(all_page_classes)}\n")
        f.write(f"- 被引用的页面: {len(referenced_pages)} ({len(referenced_pages)/len(all_page_classes)*100:.1f}%)\n")
        f.write(f"- 从入口点可访问: {len(accessible_from_entry)}\n")
        f.write(f"- 完全未被引用: {len(unreferenced_pages)} ({len(unreferenced_pages)/len(all_page_classes)*100:.1f}%)\n\n")

        f.write("## 从入口点可访问的页面\n\n")
        for page in sorted(accessible_from_entry):
            ref_count = page_references[page]['reference_count']
            f.write(f"- **{page}** (被引用 {ref_count} 次)\n")

        f.write("\n## 完全未被引用的页面（可能是死代码）\n\n")
        for page in sorted(unreferenced_pages):
            page_file = class_to_file[page]
            rel_path = Path(page_file).relative_to(app_dir.parent)
            f.write(f"- {page} - `{rel_path}`\n")

        f.write("\n## Top 20 被引用最多的页面\n\n")
        for i, (page, count) in enumerate(sorted_pages, 1):
            refs = page_references[page]['referenced_by']
            f.write(f"{i}. **{page}** - 被引用 {count} 次，在 {len(refs)} 个文件中\n")

    print(f"📝 详细报告已保存到: {output_file}")
    print()

if __name__ == '__main__':
    main()
