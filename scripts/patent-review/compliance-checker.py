#!/usr/bin/env python3
"""
专利法律合规性检查工具

功能:
1. 检查文档结构完整性
2. 检查必要章节是否存在
3. 检查权利要求格式
4. 检查说明书基本要求

输出: JSON格式的合规性检查报告
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any
import re

class ComplianceChecker:
    """专利法律合规性检查器"""

    def __init__(self, patent_dir: str):
        self.patent_dir = Path(patent_dir)
        self.patent_id = self.patent_dir.name.split('-')[0]
        self.results = {
            "patent_id": self.patent_id,
            "patent_dir": str(self.patent_dir),
            "checks": {},
            "issues": [],
            "warnings": [],
            "passed": True
        }

    def check_file_structure(self) -> Dict[str, Any]:
        """检查文件结构完整性"""
        required_files = {
            "specification.md": "说明书",
            "claims.md": "权利要求书",
            "abstract.md": "摘要",
            "metadata.json": "元数据"
        }

        check_result = {
            "name": "文件结构检查",
            "passed": True,
            "details": {}
        }

        for filename, description in required_files.items():
            filepath = self.patent_dir / filename
            exists = filepath.exists()
            check_result["details"][filename] = {
                "description": description,
                "exists": exists,
                "path": str(filepath)
            }

            if not exists:
                check_result["passed"] = False
                self.results["passed"] = False
                self.results["issues"].append({
                    "type": "missing_file",
                    "severity": "error",
                    "file": filename,
                    "message": f"缺少必需文件: {description} ({filename})",
                    "legal_basis": "《专利审查指南》第一部分第一章"
                })

        return check_result

    def check_specification_structure(self) -> Dict[str, Any]:
        """检查说明书结构"""
        spec_file = self.patent_dir / "specification.md"
        if not spec_file.exists():
            return {"name": "说明书结构检查", "passed": False, "skipped": True}

        content = spec_file.read_text(encoding='utf-8')

        # 必需章节(根据《专利审查指南》第二部分第二章)
        required_sections = {
            "技术领域": r"###?\s*技术领域",
            "背景技术": r"###?\s*背景技术",
            "发明内容": r"###?\s*发明内容",
            "附图说明": r"###?\s*附图说明",
            "具体实施方式": r"###?\s*具体实施方式"
        }

        check_result = {
            "name": "说明书结构检查",
            "passed": True,
            "details": {}
        }

        for section_name, pattern in required_sections.items():
            found = bool(re.search(pattern, content))
            check_result["details"][section_name] = {
                "found": found,
                "required": True
            }

            if not found:
                check_result["passed"] = False
                self.results["passed"] = False
                self.results["issues"].append({
                    "type": "missing_section",
                    "severity": "error",
                    "section": section_name,
                    "message": f"说明书缺少必需章节: {section_name}",
                    "legal_basis": "《专利审查指南》第二部分第二章第2.1节"
                })

        # 检查发明内容的子章节
        invention_subsections = {
            "发明目的": r"####?\s*发明目的",
            "技术方案": r"####?\s*技术方案",
        }

        for subsection_name, pattern in invention_subsections.items():
            found = bool(re.search(pattern, content))
            if not found:
                self.results["warnings"].append({
                    "type": "missing_subsection",
                    "severity": "warning",
                    "section": subsection_name,
                    "message": f"发明内容建议包含: {subsection_name}",
                    "legal_basis": "《专利审查指南》第二部分第二章第2.2.2节"
                })

        return check_result

    def check_claims_structure(self) -> Dict[str, Any]:
        """检查权利要求书结构"""
        claims_file = self.patent_dir / "claims.md"
        if not claims_file.exists():
            return {"name": "权利要求书结构检查", "passed": False, "skipped": True}

        content = claims_file.read_text(encoding='utf-8')

        check_result = {
            "name": "权利要求书结构检查",
            "passed": True,
            "details": {}
        }

        # 检查是否有独立权利要求
        independent_claims = re.findall(r'\*\*权利要求\s*\d+\*\*[：:]\s*一种', content)
        check_result["details"]["independent_claims"] = {
            "count": len(independent_claims),
            "found": len(independent_claims) > 0
        }

        if len(independent_claims) == 0:
            check_result["passed"] = False
            self.results["passed"] = False
            self.results["issues"].append({
                "type": "missing_independent_claim",
                "severity": "error",
                "message": "未找到独立权利要求",
                "legal_basis": "《专利审查指南》第二部分第二章第3.1.2节"
            })

        # 检查权利要求编号是否连续
        claim_numbers = re.findall(r'\*\*权利要求\s*(\d+)\*\*', content)
        if claim_numbers:
            claim_numbers = [int(n) for n in claim_numbers]
            expected = list(range(1, len(claim_numbers) + 1))
            if claim_numbers != expected:
                self.results["warnings"].append({
                    "type": "claim_numbering",
                    "severity": "warning",
                    "message": f"权利要求编号可能不连续: {claim_numbers}",
                    "legal_basis": "《专利审查指南》第一部分第一章"
                })

        check_result["details"]["total_claims"] = len(claim_numbers)

        return check_result

    def check_abstract(self) -> Dict[str, Any]:
        """检查摘要"""
        abstract_file = self.patent_dir / "abstract.md"
        if not abstract_file.exists():
            return {"name": "摘要检查", "passed": False, "skipped": True}

        content = abstract_file.read_text(encoding='utf-8')

        check_result = {
            "name": "摘要检查",
            "passed": True,
            "details": {}
        }

        # 检查摘要长度(建议150-300字)
        # 去除markdown标记和空白字符
        text_content = re.sub(r'[#*\-\n\r]', '', content)
        text_length = len(text_content.strip())

        check_result["details"]["length"] = {
            "characters": text_length,
            "recommended_range": "150-300字"
        }

        if text_length < 50:
            self.results["warnings"].append({
                "type": "abstract_too_short",
                "severity": "warning",
                "message": f"摘要过短({text_length}字),建议150-300字",
                "legal_basis": "《专利审查指南》第二部分第二章第2.3节"
            })
        elif text_length > 500:
            self.results["warnings"].append({
                "type": "abstract_too_long",
                "severity": "warning",
                "message": f"摘要过长({text_length}字),建议150-300字",
                "legal_basis": "《专利审查指南》第二部分第二章第2.3节"
            })

        return check_result

    def check_figures(self) -> Dict[str, Any]:
        """检查附图"""
        figures_dir = self.patent_dir / "figures"

        check_result = {
            "name": "附图检查",
            "passed": True,
            "details": {}
        }

        if not figures_dir.exists():
            check_result["details"]["figures_dir_exists"] = False
            self.results["warnings"].append({
                "type": "no_figures_dir",
                "severity": "warning",
                "message": "未找到figures目录,如果说明书中提到附图,需要提供图片文件",
                "legal_basis": "《专利审查指南》第一部分第一章"
            })
            return check_result

        check_result["details"]["figures_dir_exists"] = True

        # 统计图片文件
        image_files = list(figures_dir.glob("*.png")) + list(figures_dir.glob("*.jpg"))
        svg_files = list(figures_dir.glob("*.svg"))

        check_result["details"]["image_files"] = {
            "png_jpg_count": len(image_files),
            "svg_count": len(svg_files),
            "files": [f.name for f in image_files + svg_files]
        }

        # 检查是否有PNG/JPG格式(专利局要求)
        if len(svg_files) > 0 and len(image_files) == 0:
            self.results["warnings"].append({
                "type": "svg_only",
                "severity": "warning",
                "message": "仅有SVG格式图片,专利局要求提交PNG或JPG格式",
                "legal_basis": "《专利审查指南》第一部分第一章第4.2节"
            })

        return check_result

    def run_all_checks(self) -> Dict[str, Any]:
        """运行所有检查"""
        print(f"正在检查专利: {self.patent_id}")
        print(f"专利目录: {self.patent_dir}")
        print("-" * 60)

        # 运行各项检查
        self.results["checks"]["file_structure"] = self.check_file_structure()
        self.results["checks"]["specification"] = self.check_specification_structure()
        self.results["checks"]["claims"] = self.check_claims_structure()
        self.results["checks"]["abstract"] = self.check_abstract()
        self.results["checks"]["figures"] = self.check_figures()

        # 统计结果
        self.results["summary"] = {
            "total_checks": len(self.results["checks"]),
            "passed_checks": sum(1 for c in self.results["checks"].values() if c.get("passed", False)),
            "total_issues": len(self.results["issues"]),
            "total_warnings": len(self.results["warnings"]),
            "overall_passed": self.results["passed"]
        }

        return self.results

    def print_summary(self):
        """打印检查摘要"""
        print("\n" + "=" * 60)
        print("检查摘要")
        print("=" * 60)

        summary = self.results["summary"]
        print(f"总检查项: {summary['total_checks']}")
        print(f"通过检查: {summary['passed_checks']}")
        print(f"错误数量: {summary['total_issues']}")
        print(f"警告数量: {summary['total_warnings']}")
        print(f"总体结果: {'✅ 通过' if summary['overall_passed'] else '❌ 未通过'}")

        if self.results["issues"]:
            print("\n错误列表:")
            for i, issue in enumerate(self.results["issues"], 1):
                print(f"  {i}. [{issue['severity'].upper()}] {issue['message']}")
                print(f"     法律依据: {issue['legal_basis']}")

        if self.results["warnings"]:
            print("\n警告列表:")
            for i, warning in enumerate(self.results["warnings"], 1):
                print(f"  {i}. [{warning['severity'].upper()}] {warning['message']}")
                print(f"     法律依据: {warning['legal_basis']}")

def main():
    if len(sys.argv) < 2:
        print("用法: python compliance-checker.py <专利目录路径>")
        print("示例: python compliance-checker.py docs/patents/patents/P12-游戏化激励")
        sys.exit(1)

    patent_dir = sys.argv[1]

    if not os.path.exists(patent_dir):
        print(f"错误: 专利目录不存在: {patent_dir}")
        sys.exit(1)

    # 运行检查
    checker = ComplianceChecker(patent_dir)
    results = checker.run_all_checks()
    checker.print_summary()

    # 保存结果
    output_dir = Path("docs/patents/reviews") / checker.patent_id
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / "compliance-check.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n检查结果已保存到: {output_file}")

    # 返回退出码
    sys.exit(0 if results["passed"] else 1)

if __name__ == "__main__":
    main()
