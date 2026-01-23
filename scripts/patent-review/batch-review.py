#!/usr/bin/env python3
"""
批量专利审查脚本

功能:
1. 批量运行所有审查工具
2. 生成每个专利的完整审查报告
3. 生成汇总统计

用法:
python batch-review.py --all                    # 审查所有专利
python batch-review.py --patents P01 P02 P03    # 审查指定专利
"""

import sys
import subprocess
from pathlib import Path
import json
from typing import List, Dict, Any

class BatchReviewer:
    """批量审查器"""

    def __init__(self):
        self.patents_dir = Path("docs/patents/patents")
        self.scripts_dir = Path("scripts/patent-review")
        self.results = []

    def get_all_patents(self) -> List[str]:
        """获取所有专利目录"""
        patents = []
        for patent_dir in self.patents_dir.iterdir():
            if patent_dir.is_dir() and patent_dir.name.startswith("P"):
                patents.append(str(patent_dir))
        return sorted(patents)

    def review_patent(self, patent_dir: str) -> Dict[str, Any]:
        """审查单个专利"""
        patent_id = Path(patent_dir).name.split('-')[0]
        print(f"\n{'='*60}")
        print(f"开始审查专利: {patent_id}")
        print(f"{'='*60}")

        result = {
            "patent_id": patent_id,
            "patent_dir": patent_dir,
            "steps": {}
        }

        # 步骤1: 合规性检查
        print(f"\n[1/5] 运行合规性检查...")
        try:
            subprocess.run(
                ["python3", str(self.scripts_dir / "compliance-checker.py"), patent_dir],
                check=True,
                capture_output=True
            )
            result["steps"]["compliance"] = "success"
            print("✅ 合规性检查完成")
        except subprocess.CalledProcessError as e:
            result["steps"]["compliance"] = "failed"
            print(f"❌ 合规性检查失败: {e}")

        # 步骤2: 技术性分析
        print(f"\n[2/5] 运行技术性分析...")
        try:
            subprocess.run(
                ["python3", str(self.scripts_dir / "technical-analyzer.py"), patent_dir],
                check=True,
                capture_output=True
            )
            result["steps"]["technical"] = "success"
            print("✅ 技术性分析完成")
        except subprocess.CalledProcessError as e:
            result["steps"]["technical"] = "failed"
            print(f"❌ 技术性分析失败: {e}")

        # 步骤3: 现有技术检索
        print(f"\n[3/5] 生成检索策略...")
        try:
            subprocess.run(
                ["python3", str(self.scripts_dir / "prior-art-searcher.py"), patent_dir],
                check=True,
                capture_output=True
            )
            result["steps"]["prior_art"] = "success"
            print("✅ 检索策略生成完成")
        except subprocess.CalledProcessError as e:
            result["steps"]["prior_art"] = "failed"
            print(f"❌ 检索策略生成失败: {e}")

        # 步骤4: 质量评分
        print(f"\n[4/5] 运行质量评分...")
        try:
            subprocess.run(
                ["python3", str(self.scripts_dir / "quality-scorer.py"), patent_dir],
                check=True,
                capture_output=True
            )
            result["steps"]["quality"] = "success"
            print("✅ 质量评分完成")
        except subprocess.CalledProcessError as e:
            result["steps"]["quality"] = "failed"
            print(f"❌ 质量评分失败: {e}")

        # 步骤5: 生成综合报告
        print(f"\n[5/5] 生成综合报告...")
        try:
            subprocess.run(
                ["python3", str(self.scripts_dir / "report-generator.py"), patent_dir],
                check=True,
                capture_output=True
            )
            result["steps"]["report"] = "success"
            print("✅ 综合报告生成完成")
        except subprocess.CalledProcessError as e:
            result["steps"]["report"] = "failed"
            print(f"❌ 综合报告生成失败: {e}")

        # 读取质量评分结果
        quality_file = Path("docs/patents/reviews") / patent_id / "quality-score.json"
        if quality_file.exists():
            quality_data = json.loads(quality_file.read_text(encoding='utf-8'))
            result["overall_score"] = quality_data.get("overall_score", 0)
            result["risk_level"] = quality_data.get("risk_level", "unknown")
            result["success_rate"] = quality_data.get("estimated_success_rate", "未评估")

        print(f"\n✅ 专利 {patent_id} 审查完成")
        if "overall_score" in result:
            print(f"   综合评分: {result['overall_score']}/100")
            print(f"   风险等级: {result['risk_level'].upper()}")

        return result

    def generate_summary(self):
        """生成汇总报告"""
        print(f"\n{'='*60}")
        print("生成汇总报告")
        print(f"{'='*60}")

        summary = {
            "total_patents": len(self.results),
            "completed": sum(1 for r in self.results if all(s == "success" for s in r["steps"].values())),
            "risk_distribution": {
                "high": 0,
                "medium": 0,
                "low": 0,
                "unknown": 0
            },
            "average_score": 0,
            "patents": []
        }

        total_score = 0
        for result in self.results:
            patent_summary = {
                "patent_id": result["patent_id"],
                "overall_score": result.get("overall_score", 0),
                "risk_level": result.get("risk_level", "unknown"),
                "success_rate": result.get("success_rate", "未评估")
            }
            summary["patents"].append(patent_summary)

            risk_level = result.get("risk_level", "unknown")
            summary["risk_distribution"][risk_level] += 1

            if "overall_score" in result:
                total_score += result["overall_score"]

        if summary["completed"] > 0:
            summary["average_score"] = round(total_score / summary["completed"], 1)

        # 保存汇总报告
        summary_dir = Path("docs/patents/reviews/summary")
        summary_dir.mkdir(parents=True, exist_ok=True)

        summary_file = summary_dir / "batch-review-summary.json"
        with open(summary_file, 'w', encoding='utf-8') as f:
            json.dump(summary, f, ensure_ascii=False, indent=2)

        print(f"\n汇总统计:")
        print(f"  总专利数: {summary['total_patents']}")
        print(f"  完成审查: {summary['completed']}")
        print(f"  平均评分: {summary['average_score']}/100")
        print(f"\n风险分布:")
        print(f"  高风险: {summary['risk_distribution']['high']}个")
        print(f"  中风险: {summary['risk_distribution']['medium']}个")
        print(f"  低风险: {summary['risk_distribution']['low']}个")

        print(f"\n汇总报告已保存到: {summary_file}")

        # 生成Markdown汇总报告
        self.generate_markdown_summary(summary, summary_dir)

    def generate_markdown_summary(self, summary: Dict[str, Any], output_dir: Path):
        """生成Markdown格式的汇总报告"""
        report = []

        report.append("# 专利批量审查汇总报告\n")
        report.append(f"**审查日期**: {Path('docs/patents/reviews/P12/review-report.md').stat().st_mtime}\n")
        report.append(f"**总专利数**: {summary['total_patents']}\n")
        report.append(f"**完成审查**: {summary['completed']}\n")
        report.append(f"**平均评分**: {summary['average_score']}/100\n")

        report.append("\n## 风险分布\n")
        report.append(f"- 🔴 高风险: {summary['risk_distribution']['high']}个\n")
        report.append(f"- 🟡 中风险: {summary['risk_distribution']['medium']}个\n")
        report.append(f"- 🟢 低风险: {summary['risk_distribution']['low']}个\n")

        report.append("\n## 专利列表\n")
        report.append("| 专利ID | 综合评分 | 风险等级 | 预估成功率 |\n")
        report.append("|--------|----------|----------|------------|\n")

        for patent in sorted(summary["patents"], key=lambda x: x["overall_score"], reverse=True):
            risk_emoji = {"high": "🔴", "medium": "🟡", "low": "🟢", "unknown": "⚪"}.get(patent["risk_level"], "⚪")
            report.append(f"| {patent['patent_id']} | {patent['overall_score']}/100 | {risk_emoji} {patent['risk_level'].upper()} | {patent['success_rate']} |\n")

        # 高风险专利
        high_risk = [p for p in summary["patents"] if p["risk_level"] == "high"]
        if high_risk:
            report.append("\n## 🔴 高风险专利(需要改进)\n")
            for patent in high_risk:
                report.append(f"- **{patent['patent_id']}**: 评分{patent['overall_score']}/100\n")
                report.append(f"  - 查看详细报告: `docs/patents/reviews/{patent['patent_id']}/review-report.md`\n")

        # 中风险专利
        medium_risk = [p for p in summary["patents"] if p["risk_level"] == "medium"]
        if medium_risk:
            report.append("\n## 🟡 中风险专利(建议优化)\n")
            for patent in medium_risk:
                report.append(f"- **{patent['patent_id']}**: 评分{patent['overall_score']}/100\n")

        # 低风险专利
        low_risk = [p for p in summary["patents"] if p["risk_level"] == "low"]
        if low_risk:
            report.append("\n## 🟢 低风险专利(质量良好)\n")
            for patent in low_risk:
                report.append(f"- **{patent['patent_id']}**: 评分{patent['overall_score']}/100\n")

        markdown_file = output_dir / "batch-review-summary.md"
        markdown_file.write_text("".join(report), encoding='utf-8')
        print(f"Markdown汇总报告已保存到: {markdown_file}")

def main():
    if len(sys.argv) < 2:
        print("用法:")
        print("  python batch-review.py --all                    # 审查所有专利")
        print("  python batch-review.py --patents P01 P02 P03    # 审查指定专利")
        sys.exit(1)

    reviewer = BatchReviewer()

    if sys.argv[1] == "--all":
        patent_dirs = reviewer.get_all_patents()
        print(f"将审查所有 {len(patent_dirs)} 个专利")
    elif sys.argv[1] == "--patents":
        patent_ids = sys.argv[2:]
        patent_dirs = [str(reviewer.patents_dir / f"{pid}-*") for pid in patent_ids]
        # 展开通配符
        from glob import glob
        patent_dirs = []
        for pid in patent_ids:
            matches = glob(str(reviewer.patents_dir / f"{pid}-*"))
            if matches:
                patent_dirs.extend(matches)
        print(f"将审查 {len(patent_dirs)} 个指定专利")
    else:
        print("错误: 无效的参数")
        sys.exit(1)

    # 审查每个专利
    for patent_dir in patent_dirs:
        result = reviewer.review_patent(patent_dir)
        reviewer.results.append(result)

    # 生成汇总报告
    reviewer.generate_summary()

    print(f"\n{'='*60}")
    print("✅ 批量审查完成")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
