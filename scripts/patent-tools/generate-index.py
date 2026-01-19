#!/usr/bin/env python3
"""
专利索引生成工具

扫描专利目录，生成 index.json 和 README.md。
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

# 分类名称映射
CATEGORY_NAMES = {
    "core-technology": "核心技术专利",
    "user-experience": "用户体验专利",
    "financial-management": "财务管理专利",
}


def get_project_root():
    """获取项目根目录"""
    current = Path(__file__).resolve()
    while current.parent != current:
        if (current / "docs" / "patents").exists():
            return current
        current = current.parent
    return Path.cwd()


def load_metadata(patent_dir: Path) -> Optional[Dict]:
    """加载专利元数据"""
    metadata_path = patent_dir / "metadata.json"

    if not metadata_path.exists():
        return None

    try:
        with open(metadata_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def scan_patents(patents_base: Path) -> List[Dict]:
    """扫描所有专利"""
    patents = []

    for patent_dir in sorted(patents_base.iterdir()):
        if not patent_dir.is_dir():
            continue

        if not patent_dir.name.startswith('P'):
            continue

        metadata = load_metadata(patent_dir)

        if metadata:
            patent_info = {
                "id": metadata.get("patent_id", patent_dir.name[:3]),
                "title": metadata.get("title", {}).get("zh", "未知"),
                "status": metadata.get("status", "drafting"),
                "category": metadata.get("category", "core-technology"),
                "success_rate": metadata.get("estimated_success_rate", ""),
                "directory": f"patents/{patent_dir.name}/",
            }
        else:
            # 从目录名推断
            patent_info = {
                "id": patent_dir.name[:3],
                "title": patent_dir.name,
                "status": "drafting",
                "category": "core-technology",
                "success_rate": "",
                "directory": f"patents/{patent_dir.name}/",
            }

        patents.append(patent_info)

    return patents


def generate_index_json(patents: List[Dict], output_path: Path):
    """生成 index.json"""
    # 按分类分组
    categories = {}
    for patent in patents:
        cat = patent["category"]
        if cat not in categories:
            categories[cat] = {
                "name": CATEGORY_NAMES.get(cat, cat),
                "count": 0,
                "patents": []
            }
        categories[cat]["count"] += 1
        categories[cat]["patents"].append(patent["id"])

    # 统计状态
    status_counts = {}
    for patent in patents:
        status = patent["status"]
        status_counts[status] = status_counts.get(status, 0) + 1

    # 统计成功率
    success_rate_counts = {"high": 0, "medium": 0, "low": 0}
    for patent in patents:
        rate = patent.get("success_rate", "")
        if "85" in rate or "90" in rate:
            success_rate_counts["high"] += 1
        elif "75" in rate or "80" in rate:
            success_rate_counts["medium"] += 1
        else:
            success_rate_counts["low"] += 1

    index = {
        "portfolio": {
            "name": "AI记账应用专利组合",
            "total_patents": len(patents),
            "last_updated": datetime.now().strftime("%Y-%m-%d"),
            "version": "2.0"
        },
        "categories": categories,
        "patents": patents,
        "statistics": {
            "by_status": status_counts,
            "by_success_rate": success_rate_counts
        }
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, indent=2)

    print(f"生成: {output_path}")


def generate_readme(patents: List[Dict], output_path: Path):
    """生成 README.md"""
    lines = []

    lines.append("# AI记账应用专利组合")
    lines.append("")
    lines.append(f"最后更新: {datetime.now().strftime('%Y-%m-%d')}")
    lines.append("")
    lines.append("## 概览")
    lines.append("")
    lines.append(f"- **总计**: {len(patents)} 个专利")

    # 按分类统计
    categories = {}
    for patent in patents:
        cat = patent["category"]
        cat_name = CATEGORY_NAMES.get(cat, cat)
        categories[cat_name] = categories.get(cat_name, 0) + 1

    for cat_name, count in categories.items():
        lines.append(f"- **{cat_name}**: {count} 个")

    lines.append("")
    lines.append("## 专利清单")
    lines.append("")
    lines.append("| 编号 | 名称 | 分类 | 预估成功率 | 状态 |")
    lines.append("|------|------|------|-----------|------|")

    status_icons = {
        "drafting": "📝 起草中",
        "filed": "📤 已申请",
        "granted": "✅ 已授权",
    }

    for patent in patents:
        status = status_icons.get(patent["status"], patent["status"])
        cat_name = CATEGORY_NAMES.get(patent["category"], patent["category"])
        lines.append(
            f"| {patent['id']} | [{patent['title']}]({patent['directory']}) | "
            f"{cat_name} | {patent['success_rate']} | {status} |"
        )

    lines.append("")
    lines.append("## 目录结构")
    lines.append("")
    lines.append("```")
    lines.append("docs/patents/")
    lines.append("├── README.md              # 本文档")
    lines.append("├── index.json             # 专利索引")
    lines.append("├── standards/             # 标准规范")
    lines.append("├── archive/               # 归档旧版本")
    lines.append("└── patents/               # 当前专利")

    for patent in patents[:3]:
        lines.append(f"    ├── {patent['directory'].replace('patents/', '')}")

    if len(patents) > 3:
        lines.append(f"    └── ... ({len(patents) - 3} more)")

    lines.append("```")
    lines.append("")
    lines.append("## 分类说明")
    lines.append("")
    lines.append("| 分类 | 说明 |")
    lines.append("|------|------|")
    lines.append("| 核心技术专利 | 系统核心算法和架构创新 |")
    lines.append("| 用户体验专利 | 界面交互和用户体验创新 |")
    lines.append("| 财务管理专利 | 财务分析和管理功能创新 |")
    lines.append("")
    lines.append("## 相关文档")
    lines.append("")
    lines.append("- [命名规范](standards/naming-convention.md)")
    lines.append("- [流程图标准](standards/figure-standards.md)")
    lines.append("- [文档模板](standards/document-template.md)")
    lines.append("")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"生成: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="专利索引生成工具")
    parser.add_argument("--json-only", action="store_true", help="仅生成 index.json")
    parser.add_argument("--readme-only", action="store_true", help="仅生成 README.md")

    args = parser.parse_args()

    project_root = get_project_root()
    patents_dir = project_root / "docs" / "patents"
    patents_base = patents_dir / "patents"

    # 如果标准化目录不存在，扫描旧目录
    if not patents_base.exists():
        print("标准化目录不存在，扫描旧目录结构...")
        patents_base = patents_dir

    patents = scan_patents(patents_base)

    if not patents:
        print("警告: 未找到任何专利目录")
        # 创建空索引
        patents = []

    print(f"找到 {len(patents)} 个专利")

    if not args.readme_only:
        generate_index_json(patents, patents_dir / "index.json")

    if not args.json_only:
        generate_readme(patents, patents_dir / "README.md")

    print("完成!")


if __name__ == "__main__":
    main()
