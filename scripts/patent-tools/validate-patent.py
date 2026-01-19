#!/usr/bin/env python3
"""
专利文档验证工具

检查专利文档的完整性和规范性。
"""

import os
import sys
import json
import re
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Tuple

# 必需文件列表
REQUIRED_FILES = [
    "metadata.json",
    "specification.md",
    "claims.md",
    "abstract.md",
]

# 目录命名正则
PATENT_DIR_PATTERN = re.compile(r'^P(\d{2})-[a-z][a-z0-9-]*$')

# 流程图命名正则
FIGURE_PATTERN = re.compile(r'^fig-(\d{2})-[a-z][a-z0-9-]*\.(svg|png)$')


class ValidationResult:
    """验证结果"""

    def __init__(self, patent_id: str):
        self.patent_id = patent_id
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []

    def add_error(self, msg: str):
        self.errors.append(msg)

    def add_warning(self, msg: str):
        self.warnings.append(msg)

    def add_info(self, msg: str):
        self.info.append(msg)

    @property
    def passed(self) -> bool:
        return len(self.errors) == 0

    def summary(self) -> str:
        status = "✅ 通过" if self.passed else "❌ 失败"
        return f"{self.patent_id}: {status} ({len(self.errors)} 错误, {len(self.warnings)} 警告)"


def get_project_root():
    """获取项目根目录"""
    current = Path(__file__).resolve()
    while current.parent != current:
        if (current / "docs" / "patents").exists():
            return current
        current = current.parent
    return Path.cwd()


def validate_directory_name(dir_path: Path, result: ValidationResult):
    """验证目录命名"""
    dir_name = dir_path.name

    if not PATENT_DIR_PATTERN.match(dir_name):
        result.add_error(f"目录命名不符合规范: {dir_name}")
        result.add_info("应为 P{XX}-{英文简称} 格式，如 P01-fifo-money-age")
    else:
        result.add_info(f"目录命名正确: {dir_name}")


def validate_required_files(dir_path: Path, result: ValidationResult):
    """验证必需文件"""
    for filename in REQUIRED_FILES:
        file_path = dir_path / filename
        if not file_path.exists():
            result.add_error(f"缺少必需文件: {filename}")
        else:
            # 检查文件是否为空
            if file_path.stat().st_size == 0:
                result.add_warning(f"文件为空: {filename}")
            else:
                result.add_info(f"文件存在: {filename}")


def validate_metadata(dir_path: Path, result: ValidationResult):
    """验证元数据文件"""
    metadata_path = dir_path / "metadata.json"

    if not metadata_path.exists():
        return

    try:
        with open(metadata_path, 'r', encoding='utf-8') as f:
            metadata = json.load(f)

        # 检查必需字段
        required_fields = [
            "patent_id", "title", "inventors", "applicant",
            "status", "category", "version"
        ]

        for field in required_fields:
            if field not in metadata:
                result.add_error(f"metadata.json 缺少字段: {field}")

        # 检查 title 子字段
        if "title" in metadata:
            if "zh" not in metadata["title"]:
                result.add_error("metadata.json 缺少 title.zh 字段")
            if "en" not in metadata["title"]:
                result.add_warning("metadata.json 缺少 title.en 字段")

        # 检查状态值
        valid_statuses = ["drafting", "filed", "granted"]
        if metadata.get("status") not in valid_statuses:
            result.add_warning(f"无效的状态值: {metadata.get('status')}")

        result.add_info("metadata.json 格式正确")

    except json.JSONDecodeError as e:
        result.add_error(f"metadata.json 格式错误: {e}")


def validate_figures(dir_path: Path, result: ValidationResult):
    """验证流程图"""
    figures_dir = dir_path / "figures"

    if not figures_dir.exists():
        result.add_warning("缺少 figures 目录")
        return

    svg_files = set()
    png_files = set()
    invalid_names = []

    for f in figures_dir.iterdir():
        if f.is_file():
            if FIGURE_PATTERN.match(f.name):
                base_name = f.stem
                if f.suffix == '.svg':
                    svg_files.add(base_name)
                elif f.suffix == '.png':
                    png_files.add(base_name)
            else:
                invalid_names.append(f.name)

    # 检查命名规范
    for name in invalid_names:
        result.add_warning(f"流程图命名不规范: {name}")

    # 检查 SVG 和 PNG 配对
    svg_only = svg_files - png_files
    png_only = png_files - svg_files

    for name in svg_only:
        result.add_warning(f"缺少 PNG 版本: {name}")

    for name in png_only:
        result.add_warning(f"缺少 SVG 源文件: {name}")

    paired = svg_files & png_files
    if paired:
        result.add_info(f"找到 {len(paired)} 组配对的流程图")

    if not svg_files and not png_files:
        result.add_warning("figures 目录为空，没有流程图")


def validate_specification(dir_path: Path, result: ValidationResult):
    """验证说明书"""
    spec_path = dir_path / "specification.md"

    if not spec_path.exists():
        return

    with open(spec_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查必需章节
    required_sections = [
        "技术领域",
        "背景技术",
        "发明内容",
        "附图说明",
        "具体实施方式",
    ]

    for section in required_sections:
        if section not in content:
            result.add_warning(f"说明书可能缺少章节: {section}")

    # 检查段落编号
    paragraph_pattern = re.compile(r'\[(\d{4})\]')
    paragraphs = paragraph_pattern.findall(content)

    if paragraphs:
        result.add_info(f"说明书包含 {len(paragraphs)} 个编号段落")
    else:
        result.add_warning("说明书未使用标准段落编号 [XXXX]")


def validate_patent(patent_dir: Path) -> ValidationResult:
    """验证单个专利"""
    result = ValidationResult(patent_dir.name)

    validate_directory_name(patent_dir, result)
    validate_required_files(patent_dir, result)
    validate_metadata(patent_dir, result)
    validate_figures(patent_dir, result)
    validate_specification(patent_dir, result)

    return result


def validate_all(patents_base: Path) -> List[ValidationResult]:
    """验证所有专利"""
    results = []

    for patent_dir in sorted(patents_base.iterdir()):
        if patent_dir.is_dir() and patent_dir.name.startswith('P'):
            result = validate_patent(patent_dir)
            results.append(result)

    return results


def generate_report(results: List[ValidationResult], output_path: Path):
    """生成验证报告"""
    total = len(results)
    passed = sum(1 for r in results if r.passed)
    failed = total - passed

    report = []
    report.append("# 专利文档验证报告")
    report.append("")
    report.append(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    report.append("## 总体统计")
    report.append("")
    report.append(f"- 总计: {total} 个专利")
    report.append(f"- 通过: {passed} 个")
    report.append(f"- 失败: {failed} 个")
    report.append(f"- 通过率: {passed/total*100:.1f}%" if total > 0 else "- 通过率: N/A")
    report.append("")
    report.append("## 详细结果")
    report.append("")

    for result in results:
        status = "✅" if result.passed else "❌"
        report.append(f"### {status} {result.patent_id}")
        report.append("")

        if result.errors:
            report.append("**错误:**")
            for err in result.errors:
                report.append(f"- ❌ {err}")
            report.append("")

        if result.warnings:
            report.append("**警告:**")
            for warn in result.warnings:
                report.append(f"- ⚠️ {warn}")
            report.append("")

        if not result.errors and not result.warnings:
            report.append("无问题")
            report.append("")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(report))

    print(f"验证报告已生成: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="专利文档验证工具")
    parser.add_argument("--all", action="store_true", help="验证所有专利")
    parser.add_argument("--patent", type=str, help="验证指定专利 (如 P01)")
    parser.add_argument("--report", action="store_true", help="生成验证报告")

    args = parser.parse_args()

    project_root = get_project_root()
    patents_base = project_root / "docs" / "patents" / "patents"

    if not patents_base.exists():
        print(f"警告: 标准化专利目录不存在: {patents_base}")
        print("尝试使用旧目录结构...")
        patents_base = project_root / "docs" / "patents"

    results = []

    if args.all:
        results = validate_all(patents_base)
    elif args.patent:
        patent_dir = patents_base / args.patent
        if not patent_dir.exists():
            # 尝试模糊匹配
            for d in patents_base.iterdir():
                if d.is_dir() and args.patent in d.name:
                    patent_dir = d
                    break

        if patent_dir.exists():
            results = [validate_patent(patent_dir)]
        else:
            print(f"错误: 找不到专利目录: {args.patent}")
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(0)

    # 打印结果
    print("\n验证结果:")
    print("-" * 50)

    for result in results:
        print(result.summary())

        if result.errors:
            for err in result.errors:
                print(f"  ❌ {err}")

        if result.warnings:
            for warn in result.warnings:
                print(f"  ⚠️ {warn}")

    print("-" * 50)

    total = len(results)
    passed = sum(1 for r in results if r.passed)
    print(f"总计: {passed}/{total} 通过")

    # 生成报告
    if args.report:
        report_path = project_root / "docs" / "patents" / "validation-report.md"
        generate_report(results, report_path)

    # 返回状态码
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
