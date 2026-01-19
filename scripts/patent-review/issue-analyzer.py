#!/usr/bin/env python3
"""
问题汇总与分析工具

功能:
1. 分析所有专利的审查结果
2. 识别共性问题
3. 统计问题分布
4. 生成问题汇总报告

输出: Markdown格式的问题汇总报告
"""

import json
from pathlib import Path
from typing import Dict, List, Any
from collections import Counter, defaultdict

class IssueAnalyzer:
    """问题分析器"""

    def __init__(self):
        self.reviews_dir = Path("docs/patents/reviews")
        self.patents_data = []
        self.issue_stats = {
            "compliance_issues": Counter(),
            "technical_issues": Counter(),
            "common_problems": defaultdict(list)
        }

    def load_all_reviews(self):
        """加载所有审查结果"""
        for patent_dir in self.reviews_dir.iterdir():
            if not patent_dir.is_dir() or patent_dir.name == "summary":
                continue

            patent_id = patent_dir.name
            patent_data = {"patent_id": patent_id}

            # 加载质量评分
            quality_file = patent_dir / "quality-score.json"
            if quality_file.exists():
                quality_data = json.loads(quality_file.read_text(encoding='utf-8'))
                patent_data["quality"] = quality_data

            # 加载合规性检查
            compliance_file = patent_dir / "compliance-check.json"
            if compliance_file.exists():
                compliance_data = json.loads(compliance_file.read_text(encoding='utf-8'))
                patent_data["compliance"] = compliance_data

            # 加载技术分析
            technical_file = patent_dir / "technical-analysis.json"
            if technical_file.exists():
                technical_data = json.loads(technical_file.read_text(encoding='utf-8'))
                patent_data["technical"] = technical_data

            self.patents_data.append(patent_data)

    def analyze_compliance_issues(self):
        """分析合规性问题"""
        for patent in self.patents_data:
            compliance = patent.get("compliance", {})

            # 统计错误
            for issue in compliance.get("issues", []):
                issue_type = issue.get("type", "unknown")
                self.issue_stats["compliance_issues"][issue_type] += 1
                self.issue_stats["common_problems"][issue_type].append(patent["patent_id"])

            # 统计警告
            for warning in compliance.get("warnings", []):
                warning_type = warning.get("type", "unknown")
                self.issue_stats["compliance_issues"][warning_type] += 1
                self.issue_stats["common_problems"][warning_type].append(patent["patent_id"])

    def analyze_technical_issues(self):
        """分析技术性问题"""
        for patent in self.patents_data:
            technical = patent.get("technical", {})
            analysis = technical.get("analysis", {})

            # 检查技术问题
            problem_analysis = analysis.get("technical_problem", {})
            tech_problems = len(problem_analysis.get("technical_problems", []))
            biz_problems = len(problem_analysis.get("business_problems", []))

            if tech_problems == 0:
                self.issue_stats["technical_issues"]["no_technical_problem"] += 1
                self.issue_stats["common_problems"]["no_technical_problem"].append(patent["patent_id"])
            elif biz_problems > tech_problems:
                self.issue_stats["technical_issues"]["business_over_technical"] += 1
                self.issue_stats["common_problems"]["business_over_technical"].append(patent["patent_id"])

            # 检查技术效果
            effect_analysis = analysis.get("technical_effects", {})
            tech_effects = len(effect_analysis.get("technical_effects", []))
            biz_effects = len(effect_analysis.get("business_effects", []))

            if tech_effects == 0:
                self.issue_stats["technical_issues"]["no_technical_effect"] += 1
                self.issue_stats["common_problems"]["no_technical_effect"].append(patent["patent_id"])
            elif biz_effects > 0:
                self.issue_stats["technical_issues"]["has_business_effect"] += 1
                self.issue_stats["common_problems"]["has_business_effect"].append(patent["patent_id"])

            if not effect_analysis.get("quantified", False):
                self.issue_stats["technical_issues"]["effect_not_quantified"] += 1
                self.issue_stats["common_problems"]["effect_not_quantified"].append(patent["patent_id"])

    def generate_report(self) -> str:
        """生成问题汇总报告"""
        report = []

        report.append("# 专利问题汇总与分析报告\n")
        report.append(f"**分析专利数**: {len(self.patents_data)}\n")

        # 风险分布统计
        risk_distribution = Counter()
        score_ranges = {"0-40": 0, "40-60": 0, "60-80": 0, "80-100": 0}

        for patent in self.patents_data:
            quality = patent.get("quality", {})
            risk_level = quality.get("risk_level", "unknown")
            risk_distribution[risk_level] += 1

            score = quality.get("overall_score", 0)
            if score < 40:
                score_ranges["0-40"] += 1
            elif score < 60:
                score_ranges["40-60"] += 1
            elif score < 80:
                score_ranges["60-80"] += 1
            else:
                score_ranges["80-100"] += 1

        report.append("\n## 1. 整体质量分布\n")
        report.append("### 1.1 风险等级分布\n")
        report.append(f"- 🔴 高风险: {risk_distribution['high']}个 ({risk_distribution['high']/len(self.patents_data)*100:.1f}%)\n")
        report.append(f"- 🟡 中风险: {risk_distribution['medium']}个 ({risk_distribution['medium']/len(self.patents_data)*100:.1f}%)\n")
        report.append(f"- 🟢 低风险: {risk_distribution['low']}个 ({risk_distribution['low']/len(self.patents_data)*100:.1f}%)\n")

        report.append("\n### 1.2 评分区间分布\n")
        report.append(f"- 0-40分: {score_ranges['0-40']}个\n")
        report.append(f"- 40-60分: {score_ranges['40-60']}个\n")
        report.append(f"- 60-80分: {score_ranges['60-80']}个\n")
        report.append(f"- 80-100分: {score_ranges['80-100']}个\n")

        # 合规性问题统计
        report.append("\n## 2. 合规性问题统计\n")
        if self.issue_stats["compliance_issues"]:
            report.append("| 问题类型 | 出现次数 | 影响专利 |\n")
            report.append("|----------|----------|----------|\n")
            for issue_type, count in self.issue_stats["compliance_issues"].most_common():
                patents = ", ".join(self.issue_stats["common_problems"][issue_type][:5])
                if len(self.issue_stats["common_problems"][issue_type]) > 5:
                    patents += "..."
                report.append(f"| {issue_type} | {count} | {patents} |\n")
        else:
            report.append("✅ 未发现合规性问题\n")

        # 技术性问题统计
        report.append("\n## 3. 技术性问题统计\n")
        if self.issue_stats["technical_issues"]:
            report.append("| 问题类型 | 出现次数 | 影响专利 |\n")
            report.append("|----------|----------|----------|\n")

            issue_names = {
                "no_technical_problem": "缺少技术问题",
                "business_over_technical": "商业问题多于技术问题",
                "no_technical_effect": "缺少技术效果",
                "has_business_effect": "包含商业效果",
                "effect_not_quantified": "技术效果未量化"
            }

            for issue_type, count in self.issue_stats["technical_issues"].most_common():
                issue_name = issue_names.get(issue_type, issue_type)
                patents = ", ".join(self.issue_stats["common_problems"][issue_type][:5])
                if len(self.issue_stats["common_problems"][issue_type]) > 5:
                    patents += "..."
                report.append(f"| {issue_name} | {count} | {patents} |\n")

        # 共性问题分析
        report.append("\n## 4. 共性问题分析\n")

        # 找出最常见的问题
        all_issues = []
        for issue_type, patents in self.issue_stats["common_problems"].items():
            if len(patents) >= 3:  # 至少3个专利有此问题
                all_issues.append((issue_type, len(patents), patents))

        all_issues.sort(key=lambda x: x[1], reverse=True)

        if all_issues:
            report.append("### 4.1 高频问题(影响≥3个专利)\n")
            for issue_type, count, patents in all_issues[:10]:
                issue_name = {
                    "svg_only": "仅有SVG格式图片",
                    "no_technical_problem": "缺少技术问题",
                    "business_over_technical": "商业问题多于技术问题",
                    "no_technical_effect": "缺少技术效果",
                    "has_business_effect": "包含商业效果",
                    "effect_not_quantified": "技术效果未量化"
                }.get(issue_type, issue_type)

                report.append(f"\n**{issue_name}** (影响{count}个专利)\n")
                report.append(f"- 影响专利: {', '.join(patents)}\n")

                # 提供改进建议
                if issue_type == "svg_only":
                    report.append(f"- 改进建议: 将SVG图片转换为PNG格式(300 DPI)\n")
                elif issue_type in ["no_technical_problem", "business_over_technical"]:
                    report.append(f"- 改进建议: 在背景技术中强调技术问题,如计算效率、响应时间、准确率等\n")
                elif issue_type in ["no_technical_effect", "has_business_effect"]:
                    report.append(f"- 改进建议: 删除商业指标,增加技术指标(响应时间、准确率、内存占用等)\n")
                elif issue_type == "effect_not_quantified":
                    report.append(f"- 改进建议: 量化技术效果,如'响应时间<80ms'、'准确率>95%'\n")

        # 优先改进建议
        report.append("\n## 5. 优先改进建议\n")

        # 高风险专利
        high_risk_patents = [p for p in self.patents_data if p.get("quality", {}).get("risk_level") == "high"]
        if high_risk_patents:
            report.append(f"\n### 5.1 高风险专利({len(high_risk_patents)}个) - 必须改进\n")
            for patent in sorted(high_risk_patents, key=lambda x: x.get("quality", {}).get("overall_score", 0))[:5]:
                patent_id = patent["patent_id"]
                score = patent.get("quality", {}).get("overall_score", 0)
                report.append(f"- **{patent_id}** (评分{score}/100)\n")
                report.append(f"  - 详细报告: `docs/patents/reviews/{patent_id}/review-report.md`\n")

        # 中风险专利
        medium_risk_patents = [p for p in self.patents_data if p.get("quality", {}).get("risk_level") == "medium"]
        if medium_risk_patents:
            report.append(f"\n### 5.2 中风险专利({len(medium_risk_patents)}个) - 建议优化\n")
            report.append("重点优化技术性描述和文档质量\n")

        return "".join(report)

def main():
    print("正在分析所有专利的审查结果...")
    print("-" * 60)

    analyzer = IssueAnalyzer()
    analyzer.load_all_reviews()

    print(f"已加载 {len(analyzer.patents_data)} 个专利的审查结果")

    # 分析问题
    analyzer.analyze_compliance_issues()
    analyzer.analyze_technical_issues()

    # 生成报告
    report = analyzer.generate_report()

    # 保存报告
    output_dir = Path("docs/patents/reviews/summary")
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / "issue-analysis.md"
    output_file.write_text(report, encoding='utf-8')

    print(f"\n✅ 问题汇总报告已生成: {output_file}")

    # 打印摘要
    print("\n" + "=" * 60)
    print("问题汇总摘要")
    print("=" * 60)
    print(f"合规性问题类型: {len(analyzer.issue_stats['compliance_issues'])}")
    print(f"技术性问题类型: {len(analyzer.issue_stats['technical_issues'])}")
    print(f"共性问题数量: {len([p for p in analyzer.issue_stats['common_problems'].values() if len(p) >= 3])}")

if __name__ == "__main__":
    main()
