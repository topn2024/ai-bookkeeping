#!/usr/bin/env python3
"""
综合审查报告生成工具

功能:
1. 整合所有工具的输出
2. 生成Markdown格式的综合审查报告
3. 区分客观事实和AI判断
4. 提供改进建议

输出: Markdown格式的综合审查报告
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

class ReportGenerator:
    """综合审查报告生成器"""

    def __init__(self, patent_dir: str):
        self.patent_dir = Path(patent_dir)
        self.patent_id = self.patent_dir.name.split('-')[0]
        self.review_dir = Path("docs/patents/reviews") / self.patent_id

        self.compliance_data = {}
        self.technical_data = {}
        self.prior_art_data = {}
        self.quality_data = {}
        self.metadata = {}

    def load_all_data(self):
        """加载所有分析数据"""
        # 加载元数据
        metadata_file = self.patent_dir / "metadata.json"
        if metadata_file.exists():
            self.metadata = json.loads(metadata_file.read_text(encoding='utf-8'))

        # 加载各项分析结果
        compliance_file = self.review_dir / "compliance-check.json"
        if compliance_file.exists():
            self.compliance_data = json.loads(compliance_file.read_text(encoding='utf-8'))

        technical_file = self.review_dir / "technical-analysis.json"
        if technical_file.exists():
            self.technical_data = json.loads(technical_file.read_text(encoding='utf-8'))

        prior_art_file = self.review_dir / "prior-art-search.json"
        if prior_art_file.exists():
            self.prior_art_data = json.loads(prior_art_file.read_text(encoding='utf-8'))

        quality_file = self.review_dir / "quality-score.json"
        if quality_file.exists():
            self.quality_data = json.loads(quality_file.read_text(encoding='utf-8'))

    def generate_report(self) -> str:
        """生成综合报告"""
        report = []

        # 标题
        title = self.metadata.get("title", {})
        if isinstance(title, dict):
            title = title.get("zh", f"专利{self.patent_id}")
        report.append(f"# {self.patent_id} 专利授权可行性审查报告\n")

        # 免责声明
        report.append("## ⚠️ 重要声明\n")
        report.append("本报告由AI辅助审查工具生成,包含以下内容:\n")
        report.append("- **客观事实**: 法律条文、文档结构检查结果\n")
        report.append("- **AI分析**: 技术特征提取、区别特征识别\n")
        report.append("- **AI意见**: 创造性判断、技术效果评估、风险评估\n")
        report.append("\n**本报告不构成最终法律结论,建议关键专利咨询专业代理人。**\n")

        # 基本信息
        report.append("## 1. 专利基本信息\n")
        report.append(f"- **专利ID**: {self.patent_id}\n")
        report.append(f"- **发明名称**: {title}\n")
        inventors = self.metadata.get("inventors", [])
        if inventors:
            report.append(f"- **发明人**: {', '.join(inventors)}\n")
        applicant = self.metadata.get("applicant", "")
        if applicant:
            report.append(f"- **申请人**: {applicant}\n")
        category = self.metadata.get("category", "")
        if category:
            report.append(f"- **技术类别**: {category}\n")
        report.append(f"- **审查日期**: {datetime.now().strftime('%Y-%m-%d')}\n")

        # 综合评分
        if self.quality_data:
            report.append("\n## 2. 综合评分(AI评估)\n")
            report.append(f"⚠️ {self.quality_data.get('disclaimer', '')}\n\n")

            scores = self.quality_data.get("scores", {})
            report.append("### 2.1 五维评分\n")
            report.append("| 维度 | 得分 | 权重 | 加权得分 |\n")
            report.append("|------|------|------|----------|\n")

            dimension_names = {
                "legal_compliance": "法律合规性",
                "technical_nature": "技术性",
                "document_quality": "文档质量",
                "prior_art_risk": "现有技术风险",
                "business_value": "商业价值"
            }

            for key, name in dimension_names.items():
                if key in scores:
                    score_data = scores[key]
                    score = score_data.get("score", 0)
                    weight = score_data.get("weight", 0)
                    weighted = score * weight
                    report.append(f"| {name} | {score}/100 | {weight*100:.0f}% | {weighted:.1f} |\n")

            overall_score = self.quality_data.get("overall_score", 0)
            risk_level = self.quality_data.get("risk_level", "unknown").upper()
            success_rate = self.quality_data.get("estimated_success_rate", "未评估")

            report.append(f"\n### 2.2 综合结果\n")
            report.append(f"- **综合评分**: {overall_score}/100\n")
            report.append(f"- **风险等级**: {risk_level}\n")
            report.append(f"- **预估授权成功率**: {success_rate}\n")

        # 法律合规性检查
        if self.compliance_data:
            report.append("\n## 3. 法律合规性检查(客观)\n")

            summary = self.compliance_data.get("summary", {})
            report.append(f"- **总检查项**: {summary.get('total_checks', 0)}\n")
            report.append(f"- **通过检查**: {summary.get('passed_checks', 0)}\n")
            report.append(f"- **错误数量**: {summary.get('total_issues', 0)}\n")
            report.append(f"- **警告数量**: {summary.get('total_warnings', 0)}\n")
            report.append(f"- **总体结果**: {'✅ 通过' if summary.get('overall_passed', False) else '❌ 未通过'}\n")

            # 错误列表
            issues = self.compliance_data.get("issues", [])
            if issues:
                report.append("\n### 3.1 错误列表\n")
                for i, issue in enumerate(issues, 1):
                    report.append(f"{i}. **[{issue.get('severity', '').upper()}]** {issue.get('message', '')}\n")
                    report.append(f"   - 法律依据: {issue.get('legal_basis', '')}\n")

            # 警告列表
            warnings = self.compliance_data.get("warnings", [])
            if warnings:
                report.append("\n### 3.2 警告列表\n")
                for i, warning in enumerate(warnings, 1):
                    report.append(f"{i}. **[{warning.get('severity', '').upper()}]** {warning.get('message', '')}\n")
                    report.append(f"   - 法律依据: {warning.get('legal_basis', '')}\n")

        # 技术性分析
        if self.technical_data:
            report.append("\n## 4. 技���性分析(AI分析)\n")
            report.append(f"⚠️ {self.technical_data.get('disclaimer', '')}\n\n")

            analysis = self.technical_data.get("analysis", {})

            # 技术特征
            features_data = analysis.get("technical_features", {})
            features = features_data.get("features", [])
            if features:
                report.append(f"### 4.1 技术特征({len(features)}个)\n")
                for i, feature in enumerate(features[:5], 1):
                    report.append(f"{i}. **{feature.get('type', '')}**: {feature.get('name', '')}\n")
                    desc = feature.get('description', '')
                    if desc:
                        report.append(f"   - {desc}\n")

            # 技术问题分析
            problem_data = analysis.get("technical_problem", {})
            tech_problems = problem_data.get("technical_problems", [])
            biz_problems = problem_data.get("business_problems", [])

            report.append(f"\n### 4.2 技术问题识别\n")
            report.append(f"- **技术问题**: {len(tech_problems)}个\n")
            report.append(f"- **商业问题**: {len(biz_problems)}个\n")
            report.append(f"- **风险等级**: {problem_data.get('risk_level', 'unknown').upper()}\n")

            if tech_problems:
                report.append("\n**技术问题列表**:\n")
                for prob in tech_problems[:3]:
                    report.append(f"- {prob.get('keyword', '')}: {prob.get('context', '')[:100]}...\n")

            if biz_problems:
                report.append("\n**商业问题列表**:\n")
                for prob in biz_problems[:3]:
                    report.append(f"- {prob.get('keyword', '')}: {prob.get('context', '')[:100]}...\n")

            # 技术效果分析
            effect_data = analysis.get("technical_effects", {})
            tech_effects = effect_data.get("technical_effects", [])
            biz_effects = effect_data.get("business_effects", [])

            report.append(f"\n### 4.3 技术效果分析\n")
            report.append(f"- **技术效果**: {len(tech_effects)}个\n")
            report.append(f"- **商业效果**: {len(biz_effects)}个\n")
            report.append(f"- **是否量化**: {'是' if effect_data.get('quantified', False) else '否'}\n")

            # AI意见
            ai_opinions = self.technical_data.get("ai_opinions", [])
            if ai_opinions:
                report.append(f"\n### 4.4 AI判断意见({len(ai_opinions)}条)\n")
                for i, opinion in enumerate(ai_opinions, 1):
                    severity = opinion.get('severity', '').upper()
                    message = opinion.get('message', '')
                    legal_basis = opinion.get('legal_basis', '')
                    recommendation = opinion.get('recommendation', '')

                    report.append(f"{i}. **[{severity}]** {message}\n")
                    report.append(f"   - 法律依据: {legal_basis}\n")
                    report.append(f"   - 建议: {recommendation}\n")

        # 现有技术检索
        if self.prior_art_data:
            report.append("\n## 5. 现有技术检索策略\n")
            report.append(f"⚠️ {self.prior_art_data.get('disclaimer', '')}\n\n")

            keywords = self.prior_art_data.get("search_keywords", [])
            if keywords:
                report.append(f"### 5.1 检索关键词({len(keywords)}个)\n")
                report.append(", ".join(keywords) + "\n")

            patent_search = self.prior_art_data.get("patent_search", {})
            if patent_search:
                report.append(f"\n### 5.2 专利检索策略\n")
                report.append(f"- **检索式**: {patent_search.get('search_formula', '')}\n")
                report.append(f"- **状态**: {patent_search.get('status', '')}\n")
                report.append(f"- **说明**: {patent_search.get('note', '')}\n")

        # 改进建议
        if self.quality_data:
            recommendations = self.quality_data.get("recommendations", [])
            if recommendations:
                report.append("\n## 6. 改进建议\n")

                high_priority = [r for r in recommendations if r.get("priority") == "high"]
                medium_priority = [r for r in recommendations if r.get("priority") == "medium"]
                low_priority = [r for r in recommendations if r.get("priority") == "low"]

                if high_priority:
                    report.append("\n### 6.1 必须改进(高优先级)\n")
                    for rec in high_priority:
                        report.append(f"- **{rec.get('dimension', '')}**: {rec.get('message', '')}\n")
                        report.append(f"  - 行动: {rec.get('action', '')}\n")

                if medium_priority:
                    report.append("\n### 6.2 建议优化(中优先级)\n")
                    for rec in medium_priority:
                        report.append(f"- **{rec.get('dimension', '')}**: {rec.get('message', '')}\n")
                        report.append(f"  - 行动: {rec.get('action', '')}\n")

                if low_priority:
                    report.append("\n### 6.3 可选改进(低优先级)\n")
                    for rec in low_priority:
                        report.append(f"- **{rec.get('dimension', '')}**: {rec.get('message', '')}\n")
                        report.append(f"  - 行动: {rec.get('action', '')}\n")

        # 结论
        report.append("\n## 7. 审查结论\n")

        if self.quality_data:
            overall_score = self.quality_data.get("overall_score", 0)
            risk_level = self.quality_data.get("risk_level", "unknown")

            if risk_level == "low":
                report.append("✅ **总体评估**: 专利质量较好,授权可行性较高\n")
            elif risk_level == "medium":
                report.append("⚠️ **总体评估**: 专利质量中等,存在一定风险,建议改进\n")
            else:
                report.append("❌ **总体评估**: 专利质量较低,授权风险较高,必须改进\n")

            report.append(f"\n**综合评分**: {overall_score}/100\n")
            report.append(f"**风险等级**: {risk_level.upper()}\n")
            report.append(f"**预估授权成功率**: {self.quality_data.get('estimated_success_rate', '未评估')}\n")

        report.append("\n---\n")
        report.append(f"**审查工具**: AI辅助专利审查系统 v1.0\n")
        report.append(f"**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

        return "".join(report)

    def save_report(self, report: str):
        """保存报告"""
        output_file = self.review_dir / "review-report.md"
        output_file.write_text(report, encoding='utf-8')
        return output_file

def main():
    if len(sys.argv) < 2:
        print("用法: python report-generator.py <专利目录路径>")
        print("示例: python report-generator.py docs/patents/patents/P12-游戏化激励")
        sys.exit(1)

    patent_dir = sys.argv[1]

    if not os.path.exists(patent_dir):
        print(f"错误: 专利目录不存在: {patent_dir}")
        sys.exit(1)

    # 生成报告
    generator = ReportGenerator(patent_dir)
    generator.load_all_data()

    print(f"正在生成综合审查报告: {generator.patent_id}")
    print(f"专利目录: {generator.patent_dir}")
    print("-" * 60)

    report = generator.generate_report()
    output_file = generator.save_report(report)

    print(f"\n✅ 综合审查报告已生成: {output_file}")
    print(f"\n报告预览:")
    print("=" * 60)
    # 打印前30行
    lines = report.split('\n')
    for line in lines[:30]:
        print(line)
    if len(lines) > 30:
        print(f"\n... (共{len(lines)}行,完整内容请查看文件)")

if __name__ == "__main__":
    main()
