#!/usr/bin/env python3
"""
生成Flutter应用页面导航关系图
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
    return Path(file_path).stem.replace('_page', '').replace('_', ' ').title()

def extract_navigations(file_path):
    """从Dart文件中提取导航目标"""
    navigations = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 匹配 Navigator.push 和 MaterialPageRoute
        patterns = [
            r'MaterialPageRoute\(builder:.*?=>\s*(?:const\s+)?(\w+)\(',
            r'Navigator\.push.*?MaterialPageRoute.*?(\w+Page)\(',
            r'Navigator\.pushNamed\([^,]+,\s*[\'"]([^\'"]+)[\'"]',
        ]

        for pattern in patterns:
            matches = re.findall(pattern, content)
            navigations.extend(matches)

    except Exception as e:
        print(f"Error reading {file_path}: {e}")

    return list(set(navigations))

def generate_mermaid_graph(navigation_map, output_file):
    """生成Mermaid格式的导航图"""
    lines = ['```mermaid', 'graph TD']

    # 定义节点样式
    lines.append('    classDef hub fill:#ff6b6b,stroke:#c92a2a,color:#fff')
    lines.append('    classDef auth fill:#4dabf7,stroke:#1971c2,color:#fff')
    lines.append('    classDef main fill:#51cf66,stroke:#2f9e44,color:#fff')

    # 识别主要导航中心（导航到5个以上页面的）
    hubs = {page for page, targets in navigation_map.items() if len(targets) >= 5}

    # 生成节点和边
    node_ids = {}
    node_counter = 0

    for source, targets in sorted(navigation_map.items()):
        if not targets:
            continue

        # 为源页面创建节点ID
        if source not in node_ids:
            node_ids[source] = f"N{node_counter}"
            node_counter += 1

        source_id = node_ids[source]

        for target in sorted(targets):
            # 为目标页面创建节点ID
            if target not in node_ids:
                node_ids[target] = f"N{node_counter}"
                node_counter += 1

            target_id = node_ids[target]

            # 添加边
            lines.append(f"    {source_id}[{source}] --> {target_id}[{target}]")

    # 应用样式
    for page, node_id in node_ids.items():
        if page in hubs:
            lines.append(f"    class {node_id} hub")
        elif 'Login' in page or 'Register' in page:
            lines.append(f"    class {node_id} auth")
        elif page in ['Main Navigation', 'Home', 'Profile', 'Settings']:
            lines.append(f"    class {node_id} main")

    lines.append('```')

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"Mermaid graph saved to {output_file}")

def generate_dot_graph(navigation_map, output_file):
    """生成Graphviz DOT格式的导航图"""
    lines = ['digraph NavigationGraph {']
    lines.append('    rankdir=LR;')
    lines.append('    node [shape=box, style=rounded];')
    lines.append('    ')

    # 识别主要导航中心
    hubs = {page for page, targets in navigation_map.items() if len(targets) >= 10}

    # 生成节点
    node_ids = {}
    for i, page in enumerate(sorted(set(navigation_map.keys()) |
                                   {t for targets in navigation_map.values() for t in targets})):
        node_id = f"N{i}"
        node_ids[page] = node_id

        # 设置节点样式
        if page in hubs:
            lines.append(f'    {node_id} [label="{page}", fillcolor="#ff6b6b", style="filled,rounded"];')
        elif 'Login' in page or 'Register' in page:
            lines.append(f'    {node_id} [label="{page}", fillcolor="#4dabf7", style="filled,rounded"];')
        elif page in ['Main Navigation', 'Home', 'Profile', 'Settings']:
            lines.append(f'    {node_id} [label="{page}", fillcolor="#51cf66", style="filled,rounded"];')
        else:
            lines.append(f'    {node_id} [label="{page}"];')

    lines.append('    ')

    # 生成边
    for source, targets in sorted(navigation_map.items()):
        source_id = node_ids[source]
        for target in sorted(targets):
            target_id = node_ids[target]
            lines.append(f'    {source_id} -> {target_id};')

    lines.append('}')

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"DOT graph saved to {output_file}")

def generate_summary(navigation_map, output_file):
    """生成导航关系摘要"""
    lines = ['# 页面导航关系分析\n']

    # 统计信息
    total_pages = len(navigation_map)
    total_edges = sum(len(targets) for targets in navigation_map.values())

    lines.append(f"## 统计信息\n")
    lines.append(f"- 总页面数: {total_pages}")
    lines.append(f"- 总导航关系数: {total_edges}")
    lines.append(f"- 平均每页导航数: {total_edges/total_pages:.1f}\n")

    # Top 20 导航中心
    lines.append(f"## Top 20 导航中心页面\n")
    sorted_pages = sorted(navigation_map.items(), key=lambda x: len(x[1]), reverse=True)[:20]

    for i, (page, targets) in enumerate(sorted_pages, 1):
        lines.append(f"{i}. **{page}** ({len(targets)} 个目标页面)")
        if len(targets) <= 10:
            for target in sorted(targets):
                lines.append(f"   - {target}")
        else:
            for target in sorted(targets)[:5]:
                lines.append(f"   - {target}")
            lines.append(f"   - ... 还有 {len(targets)-5} 个页面")
        lines.append('')

    # 孤立页面（没有导航到其他页面的）
    isolated = [page for page, targets in navigation_map.items() if not targets]
    if isolated:
        lines.append(f"## 孤立页面 ({len(isolated)} 个)\n")
        lines.append("这些页面不导航到其他页面（可能是终点页面）:\n")
        for page in sorted(isolated)[:20]:
            lines.append(f"- {page}")
        if len(isolated) > 20:
            lines.append(f"- ... 还有 {len(isolated)-20} 个页面")
        lines.append('')

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"Summary saved to {output_file}")

def main():
    # 设置路径
    app_dir = Path(__file__).parent.parent / 'app'
    pages_dir = app_dir / 'lib' / 'pages'
    output_dir = Path(__file__).parent.parent / 'docs'
    output_dir.mkdir(exist_ok=True)

    print(f"Scanning pages in: {pages_dir}")

    # 查找所有页面
    page_files = find_dart_pages(str(pages_dir))
    print(f"Found {len(page_files)} page files")

    # 构建导航映射
    navigation_map = defaultdict(list)

    for page_file in page_files:
        page_name = extract_page_name(page_file)
        targets = extract_navigations(page_file)

        # 清理目标页面名称
        clean_targets = []
        for target in targets:
            if target.endswith('Page'):
                clean_name = target.replace('Page', '').replace('_', ' ')
                # 转换为标题格式
                clean_name = ' '.join(word.capitalize() for word in clean_name.split())
                clean_targets.append(clean_name)

        navigation_map[page_name] = clean_targets

    print(f"Built navigation map with {len(navigation_map)} pages")

    # 生成输出文件
    generate_summary(navigation_map, output_dir / 'navigation_summary.md')
    generate_mermaid_graph(navigation_map, output_dir / 'navigation_graph.mmd')
    generate_dot_graph(navigation_map, output_dir / 'navigation_graph.dot')

    print("\n生成完成！")
    print(f"- 摘要: {output_dir / 'navigation_summary.md'}")
    print(f"- Mermaid图: {output_dir / 'navigation_graph.mmd'}")
    print(f"- DOT图: {output_dir / 'navigation_graph.dot'}")
    print("\n使用方法:")
    print("1. Mermaid图可以在GitHub、GitLab或支持Mermaid的Markdown编辑器中查看")
    print("2. DOT图可以使用Graphviz转换为图片: dot -Tpng navigation_graph.dot -o navigation_graph.png")

if __name__ == '__main__':
    main()
