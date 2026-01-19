#!/usr/bin/env python3
"""
专利文档迁移工具

将旧格式专利文档迁移到新的标准化结构。
"""

import os
import sys
import json
import shutil
import argparse
from pathlib import Path
from datetime import datetime

# 专利目录映射：旧目录名 -> (新编号, 新目录名, 中文名称)
PATENT_MAPPING = {
    "01-FIFO钱龄计算": ("P01", "P01-fifo-money-age", "FIFO资源池钱龄计算"),
    "02-多模态融合记账": ("P02", "P02-multimodal-bookkeeping", "多模态融合智能记账"),
    "A-差分隐私自学习": ("P03", "P03-privacy-learning", "基于差分隐私的财务智能自学习系统"),
    "B-自适应零基预算": ("P04", "P04-adaptive-budget", "自适应零基预算智能管理系统"),
    "C-LLM语音交互": ("P05", "P05-llm-voice", "LLM增强的四维语音交互系统"),
    "06-位置增强管理": ("P06", "P06-location-enhanced", "位置增强财务管理"),
    "07-交易去重": ("P07", "P07-deduplication", "多因子交易去重"),
    "D-智能可视化系统": ("P08", "P08-visualization", "智能自适应财务数据可视化系统"),
    "E-财务健康评分": ("P09", "P09-health-scoring", "智能财务健康评分与管理系统"),
    "10-账单解析导入": ("P10", "P10-bill-parsing", "智能账单解析导入"),
    "11-离线增量同步": ("P11", "P11-offline-sync", "离线优先增量同步"),
    "13-游戏化激励": ("P12", "P12-gamification", "游戏化激励系统"),
    "14-家庭协作记账": ("P13", "P13-family-collab", "家庭协作记账"),
    "15-冷静期控制": ("P14", "P14-cooling-off", "冷静期消费控制"),
    "16-可变收入适配": ("P15", "P15-variable-income", "可变收入适配器"),
    "17-订阅追踪检测": ("P16", "P16-subscription", "订阅追踪与浪费检测"),
    "18-债务健康管理": ("P17", "P17-debt-management", "债务健康管理"),
    "20-消费趋势预测": ("P18", "P18-trend-prediction", "消费趋势预测"),
}

# 预估成功率映射
SUCCESS_RATES = {
    "P01": "85-90%",
    "P02": "80-85%",
    "P03": "80-85%",
    "P04": "80-85%",
    "P05": "85-90%",
    "P06": "75-80%",
    "P07": "75-80%",
    "P08": "75-80%",
    "P09": "75-80%",
    "P10": "75-80%",
    "P11": "75-80%",
    "P12": "75-80%",
    "P13": "75-80%",
    "P14": "80-85%",
    "P15": "80-85%",
    "P16": "80-85%",
    "P17": "75-80%",
    "P18": "75-80%",
}

# 分类映射
CATEGORIES = {
    "P01": "core-technology",
    "P02": "core-technology",
    "P03": "core-technology",
    "P04": "financial-management",
    "P05": "financial-management",
    "P06": "core-technology",
    "P07": "core-technology",
    "P08": "user-experience",
    "P09": "financial-management",
    "P10": "core-technology",
    "P11": "core-technology",
    "P12": "user-experience",
    "P13": "user-experience",
    "P14": "financial-management",
    "P15": "financial-management",
    "P16": "financial-management",
    "P17": "financial-management",
    "P18": "financial-management",
}


def get_project_root():
    """获取项目根目录"""
    current = Path(__file__).resolve()
    while current.parent != current:
        if (current / "docs" / "patents").exists():
            return current
        current = current.parent
    return Path.cwd()


def create_metadata(patent_id: str, title_zh: str, source_dir: Path) -> dict:
    """创建专利元数据"""
    return {
        "patent_id": patent_id,
        "patent_number": "",
        "title": {
            "zh": title_zh,
            "en": ""
        },
        "inventors": ["李北华"],
        "applicant": "李北华",
        "filing_date": "",
        "status": "drafting",
        "category": CATEGORIES.get(patent_id, "core-technology"),
        "tags": [],
        "estimated_success_rate": SUCCESS_RATES.get(patent_id, "75-80%"),
        "related_patents": [],
        "version": "2.0",
        "changelog": [
            {
                "version": "2.0",
                "date": datetime.now().strftime("%Y-%m-%d"),
                "changes": "迁移到标准化目录结构"
            }
        ],
        "figures": [],
        "files": {
            "specification": "specification.md",
            "claims": "claims.md",
            "abstract": "abstract.md"
        }
    }


def merge_part_files(source_dir: Path, target_file: Path):
    """合并分part的文件"""
    parts = []

    # 查找所有 part 文件
    for f in sorted(source_dir.glob("*_part*.md")):
        parts.append(f)

    if not parts:
        # 尝试查找单个文件
        for f in source_dir.glob("*.md"):
            if "part" not in f.name.lower():
                parts.append(f)
                break

    if parts:
        content = []
        for part in parts:
            with open(part, 'r', encoding='utf-8') as f:
                content.append(f.read())

        with open(target_file, 'w', encoding='utf-8') as f:
            f.write("\n\n".join(content))

        return True
    return False


def migrate_patent(source_dir: Path, target_dir: Path, patent_id: str,
                   title_zh: str, dry_run: bool = False):
    """迁移单个专利"""
    print(f"迁移: {source_dir.name} -> {target_dir.name}")

    if dry_run:
        print(f"  [预览] 将创建目录: {target_dir}")
        print(f"  [预览] 将创建 metadata.json")
        print(f"  [预览] 将迁移文档文件")
        return True

    # 创建目标目录
    target_dir.mkdir(parents=True, exist_ok=True)
    figures_dir = target_dir / "figures"
    figures_dir.mkdir(exist_ok=True)

    # 创建元数据
    metadata = create_metadata(patent_id, title_zh, source_dir)
    with open(target_dir / "metadata.json", 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)
    print(f"  创建: metadata.json")

    # 迁移/合并文档文件
    # 尝试查找并合并 专利申请书 文件
    申请书_files = list(source_dir.glob("专利申请书*.md"))
    if 申请书_files:
        merge_part_files(source_dir, target_dir / "specification.md")
        print(f"  合并: 专利申请书 -> specification.md")

    # 尝试查找 技术交底书
    技术交底书_files = list(source_dir.glob("技术交底书*.md"))
    if 技术交底书_files and not 申请书_files:
        # 如果没有专利申请书，使用技术交底书
        shutil.copy(技术交底书_files[0], target_dir / "specification.md")
        print(f"  复制: 技术交底书 -> specification.md")

    # 创建空的 claims.md 和 abstract.md（如果不存在）
    if not (target_dir / "claims.md").exists():
        with open(target_dir / "claims.md", 'w', encoding='utf-8') as f:
            f.write(f"# 权利要求书\n\n## {title_zh}\n\n待补充\n")
        print(f"  创建: claims.md (空模板)")

    if not (target_dir / "abstract.md").exists():
        with open(target_dir / "abstract.md", 'w', encoding='utf-8') as f:
            f.write(f"# 摘要\n\n## {title_zh}\n\n待补充\n")
        print(f"  创建: abstract.md (空模板)")

    return True


def migrate_all(patents_dir: Path, dry_run: bool = False):
    """迁移所有专利"""
    target_base = patents_dir / "patents"

    if not dry_run:
        target_base.mkdir(exist_ok=True)

    migrated = 0
    skipped = 0

    for old_name, (patent_id, new_name, title_zh) in PATENT_MAPPING.items():
        source_dir = patents_dir / old_name
        target_dir = target_base / new_name

        if not source_dir.exists():
            print(f"跳过: {old_name} (目录不存在)")
            skipped += 1
            continue

        if target_dir.exists() and not dry_run:
            print(f"跳过: {new_name} (目标已存在)")
            skipped += 1
            continue

        if migrate_patent(source_dir, target_dir, patent_id, title_zh, dry_run):
            migrated += 1

    print(f"\n完成: 迁移 {migrated} 个专利, 跳过 {skipped} 个")
    return migrated


def archive_old_files(patents_dir: Path, dry_run: bool = False):
    """归档旧的 .docx 文件"""
    archive_dir = patents_dir / "archive" / "v1.0"

    if not dry_run:
        archive_dir.mkdir(parents=True, exist_ok=True)

    docx_files = list(patents_dir.glob("*.docx"))

    for f in docx_files:
        if dry_run:
            print(f"[预览] 归档: {f.name}")
        else:
            shutil.move(str(f), str(archive_dir / f.name))
            print(f"归档: {f.name}")

    print(f"归档 {len(docx_files)} 个 .docx 文件")


def main():
    parser = argparse.ArgumentParser(description="专利文档迁移工具")
    parser.add_argument("--all", action="store_true", help="迁移所有专利")
    parser.add_argument("--source", type=str, help="源目录路径")
    parser.add_argument("--target", type=str, help="目标目录路径")
    parser.add_argument("--dry-run", action="store_true", help="预览模式，不实际执行")
    parser.add_argument("--archive", action="store_true", help="归档旧的 .docx 文件")

    args = parser.parse_args()

    project_root = get_project_root()
    patents_dir = project_root / "docs" / "patents"

    if not patents_dir.exists():
        print(f"错误: 专利目录不存在: {patents_dir}")
        sys.exit(1)

    if args.archive:
        archive_old_files(patents_dir, args.dry_run)
    elif args.all:
        migrate_all(patents_dir, args.dry_run)
    elif args.source and args.target:
        source = Path(args.source)
        target = Path(args.target)

        # 从映射中查找信息
        patent_id = "P00"
        title_zh = "未知专利"
        for old_name, (pid, new_name, title) in PATENT_MAPPING.items():
            if old_name in str(source) or new_name in str(target):
                patent_id = pid
                title_zh = title
                break

        migrate_patent(source, target, patent_id, title_zh, args.dry_run)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
