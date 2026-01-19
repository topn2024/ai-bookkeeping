#!/usr/bin/env python3
"""
专利质量评分工具(AI辅助)

功能:
1. 整合前面工具的分析结果
2. 五维评分(法律合规性、技术性、文档质量、现有技术对比、商业价值)
3. 生成雷达图(可选)
4. 预估授权成功率(AI估计)

输出: JSON格式的质量评分报告
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any

class QualityScorer:
    """专利质量评分器(AI辅助)"""

    def __init__(self, patent_dir: str):
        self.patent_dir = Path(patent_dir)
        self.patent_id = self.patent_dir.name.split('-')[0]
        self.review_dir = Path("docs/patents/reviews") / self.patent_id

        self.results = {
            "patent_id": self.patent_id,
            "patent_dir": str(self.patent_dir),
            "disclaimer": "⚠️ 以下评分为AI辅助评估,非最终法律结论",
            "scores": {
                "legal_compliance": {"score": 0, "max": 100, "weight": 0.3},
                "technical_nature": {"score": 0, "max": 100, "weight": 0.25},
                "document_quality": {"score": 0, "max": 100, "weight": 0.2},
                "prior_art_risk": {"score": 0, "max": 100, "weight": 0.15},
                "business_value": {"score": 0, "max": 100, "weight": 0.1}
            },
            "overall_score": 0,
            "risk_level": "unknown",
            "estimated_success_rate": "未评估",
            "key_issues": [],
            "recommendations": []
        }

    def load_compliance_check(self) -> Dict[str, Any]:
        """加载合规性检查结果"""
        file_path = self.review_dir / "compliance-check.json"
        if not file_path.exists():
            return {}
        return json.loads(file_path.read_text(encoding='utf-8'))

    def load_technical_analysis(self) -> Dict[str, Any]:
        """加载技术性分析结果"""
        file_path = self.review_dir / "technical-analysis.json"
        if not file_path.exists():
            return {}
        return json.loads(file_path.read_text(encoding='utf-8'))

    def load_prior_art_search(self) -> Dict[str, Any]:
        """加载现有技术检索结果"""
        file_path = self.review_dir / "prior-art-search.json"
        if not file_path.exists():
            return {}
        return json.loads(file_path.read_text(encoding='utf-8'))

    def score_legal_compliance(self, compliance_data: Dict[str, Any]) -> int:
        """评分:法律合规性(0-100)"""
        if not compliance_data:
            return 0

        score = 100

        # 检查是否通过所有检查
        if not compliance_data.get("passed", False):
            score -= 30

        # 扣除错误分数
        issues = compliance_data.get("issues", [])
        score -= len(issues) * 15  # 每个错误扣15分

        # 扣除警告分数
        warnings = compliance_data.get("warnings", [])
        score -= len(warnings) * 5  # 每个警告扣5分

        return max(0, score)

    def score_technical_nature(self, technical_data: Dict[str, Any]) -> int:
        """评分:技术性(0-100)"""
        if not technical_data:
            return 0

        score = 100
        analysis = technical_data.get("analysis", {})

        # 技术问题分析
        problem_analysis = analysis.get("technical_problem", {})
        tech_problems = len(problem_analysis.get("technical_problems", []))
        biz_problems = len(problem_analysis.get("business_problems", []))

        if tech_problems == 0:
            score -= 40  # 没有技术问题,严重扣分
        elif biz_problems > tech_problems:
            score -= 25  # 商业问题多于技术问题

        # 技术效果分析
        effect_analysis = analysis.get("technical_effects", {})
        tech_effects = len(effect_analysis.get("technical_effects", []))
        biz_effects = len(effect_analysis.get("business_effects", []))

        if tech_effects == 0:
            score -= 30  # 没有技术效果
        elif biz_effects > 0:
            score -= 10  # 有商业效果

        if not effect_analysis.get("quantified", False):
            score -= 15  # 技术效果未量化

        # 技术特征
        features = analysis.get("technical_features", {}).get("features", [])
        if len(features) < 3:
            score -= 10  # 技术特征太少

        return max(0, score)

    def score_document_quality(self, compliance_data: Dict[str, Any], technical_data: Dict[str, Any]) -> int:
        """评分:文档质量(0-100)"""
        score = 100

        # 基于合规性检查
        if compliance_data:
            checks = compliance_data.get("checks", {})

            # 说明书结构
            spec_check = checks.get("specification", {})
            if not spec_check.get("passed", False):
                score -= 20

            # 权利要求
            claims_check = checks.get("claims", {})
            if not claims_check.get("passed", False):
                score -= 20

            # 摘要
            abstract_check = checks.get("abstract", {})
            if not abstract_check.get("passed", False):
                score -= 10

            # 附图
            figures_check = checks.get("figures", {})
            if not figures_check.get("passed", False):
                score -= 10

        # 基于技术分析
        if technical_data:
            # 技术特征数量
            features = technical_data.get("analysis", {}).get("technical_features", {}).get("features", [])
            if len(features) >= 5:
                score += 10  # 技术特征丰富,加分
            elif len(features) < 2:
                score -= 15

        return max(0, min(100, score))

    def score_prior_art_risk(self, prior_art_data: Dict[str, Any]) -> int:
        """评分:现有技术风险(0-100,分数越高风险越低)"""
        # 由于没有实际检索结果,给予中等分数
        # 实际使用时需要根据检索到的现有技术进行评估
        if not prior_art_data:
            return 50  # 未检索,中等风险

        # 如果有检索关键词,说明至少做了准备
        keywords = prior_art_data.get("search_keywords", [])
        if len(keywords) > 0:
            return 60  # 有检索策略,风险略低

        return 50

    def score_business_value(self, technical_data: Dict[str, Any]) -> int:
        """评分:商业价值(0-100)"""
        # 这是一个主观评分,基于技术特征的数量和复杂度
        if not technical_data:
            return 50

        score = 50  # 基础分

        # 技术特征越多,商业价值可能越高
        features = technical_data.get("analysis", {}).get("technical_features", {}).get("features", [])
        score += min(30, len(features) * 5)

        # 有算法描述,加分
        means = technical_data.get("analysis", {}).get("technical_means", {})
        if means.get("algorithms", {}).get("found", False):
            score += 10

        # 有数据结构,加分
        if len(means.get("data_structures", [])) > 0:
            score += 10

        return min(100, score)

    def calculate_overall_score(self) -> float:
        """计算总分"""
        total = 0
        for dimension, data in self.results["scores"].items():
            total += data["score"] * data["weight"]
        return round(total, 1)

    def determine_risk_level(self, overall_score: float) -> str:
        """判断风险等级"""
        if overall_score >= 80:
            return "low"
        elif overall_score >= 60:
            return "medium"
        else:
            return "high"

    def estimate_success_rate(self, overall_score: float, risk_level: str) -> str:
        """预估授权成功率(AI估计)"""
        if risk_level == "low":
            return "75-85%(AI估计)"
        elif risk_level == "medium":
            return "55-70%(AI估计)"
        else:
            return "30-50%(AI估计)"

    def extract_key_issues(self, compliance_data: Dict[str, Any], technical_data: Dict[str, Any]):
        """提取关键问题"""
        issues = []

        # 从合规性检查提取
        if compliance_data:
            for issue in compliance_data.get("issues", []):
                issues.append({
                    "type": "compliance",
                    "severity": issue.get("severity", "error"),
                    "message": issue.get("message", ""),
                    "legal_basis": issue.get("legal_basis", "")
                })

        # 从技术分析提取
        if technical_data:
            for opinion in technical_data.get("ai_opinions", []):
                if opinion.get("severity") == "high":
                    issues.append({
                        "type": "technical",
                        "severity": "high",
                        "message": opinion.get("message", ""),
                        "legal_basis": opinion.get("legal_basis", "")
                    })

        self.results["key_issues"] = issues

    def generate_recommendations(self):
        """生成改进建议"""
        recommendations = []

        scores = self.results["scores"]

        # 法律合规性建议
        if scores["legal_compliance"]["score"] < 80:
            recommendations.append({
                "dimension": "法律合规性",
                "priority": "high",
                "message": "存在合规性问题,必须解决",
                "action": "查看compliance-check.json中的issues列表"
            })

        # 技术性建议
        if scores["technical_nature"]["score"] < 70:
            recommendations.append({
                "dimension": "技术性",
                "priority": "high",
                "message": "技术性不足,存在被认定为商业方法的风险",
                "action": "强化技术问题、技术手段、技术效果的描述"
            })

        # 文档质量建议
        if scores["document_quality"]["score"] < 80:
            recommendations.append({
                "dimension": "文档质量",
                "priority": "medium",
                "message": "文档质量需要改进",
                "action": "完善说明书结构、权利要求、附图等"
            })

        # 现有技术建议
        if scores["prior_art_risk"]["score"] < 70:
            recommendations.append({
                "dimension": "现有技术",
                "priority": "medium",
                "message": "需要进行现有技术检索",
                "action": "使用prior-art-search.json中的检索策略进行检索"
            })

        self.results["recommendations"] = recommendations

    def run_scoring(self) -> Dict[str, Any]:
        """运行评分"""
        print(f"正在评分专利: {self.patent_id}")
        print(f"专利目录: {self.patent_dir}")
        print("-" * 60)

        # 加载各项分析结果
        compliance_data = self.load_compliance_check()
        technical_data = self.load_technical_analysis()
        prior_art_data = self.load_prior_art_search()

        # 计算各维度分数
        self.results["scores"]["legal_compliance"]["score"] = self.score_legal_compliance(compliance_data)
        self.results["scores"]["technical_nature"]["score"] = self.score_technical_nature(technical_data)
        self.results["scores"]["document_quality"]["score"] = self.score_document_quality(compliance_data, technical_data)
        self.results["scores"]["prior_art_risk"]["score"] = self.score_prior_art_risk(prior_art_data)
        self.results["scores"]["business_value"]["score"] = self.score_business_value(technical_data)

        # 计算总分
        self.results["overall_score"] = self.calculate_overall_score()

        # 判断风险等级
        self.results["risk_level"] = self.determine_risk_level(self.results["overall_score"])

        # 预估成功率
        self.results["estimated_success_rate"] = self.estimate_success_rate(
            self.results["overall_score"],
            self.results["risk_level"]
        )

        # 提取关键问题
        self.extract_key_issues(compliance_data, technical_data)

        # 生成建议
        self.generate_recommendations()

        return self.results

    def print_summary(self):
        """打印评分摘要"""
        print("\n" + "=" * 60)
        print("专利质量评分(AI辅助)")
        print("=" * 60)
        print(f"⚠️ {self.results['disclaimer']}")
        print()

        print("五维评分:")
        scores = self.results["scores"]
        print(f"  1. 法律合规性: {scores['legal_compliance']['score']}/100 (权重{scores['legal_compliance']['weight']*100:.0f}%)")
        print(f"  2. 技术性:     {scores['technical_nature']['score']}/100 (权重{scores['technical_nature']['weight']*100:.0f}%)")
        print(f"  3. 文档质量:   {scores['document_quality']['score']}/100 (权重{scores['document_quality']['weight']*100:.0f}%)")
        print(f"  4. 现有技术:   {scores['prior_art_risk']['score']}/100 (权重{scores['prior_art_risk']['weight']*100:.0f}%)")
        print(f"  5. 商业价值:   {scores['business_value']['score']}/100 (权重{scores['business_value']['weight']*100:.0f}%)")

        print(f"\n综合评分: {self.results['overall_score']}/100")
        print(f"风险等级: {self.results['risk_level'].upper()}")
        print(f"预估授权成功率: {self.results['estimated_success_rate']}")

        if self.results["key_issues"]:
            print(f"\n关键问题({len(self.results['key_issues'])}个):")
            for i, issue in enumerate(self.results["key_issues"][:5], 1):
                print(f"  {i}. [{issue['severity'].upper()}] {issue['message']}")

        if self.results["recommendations"]:
            print(f"\n改进建议:")
            for rec in self.results["recommendations"]:
                print(f"  [{rec['priority'].upper()}] {rec['dimension']}: {rec['message']}")

def main():
    if len(sys.argv) < 2:
        print("用法: python quality-scorer.py <专利目录路径>")
        print("示例: python quality-scorer.py docs/patents/patents/P12-游戏化激励")
        sys.exit(1)

    patent_dir = sys.argv[1]

    if not os.path.exists(patent_dir):
        print(f"错误: 专利目录不存在: {patent_dir}")
        sys.exit(1)

    # 运行评分
    scorer = QualityScorer(patent_dir)
    results = scorer.run_scoring()
    scorer.print_summary()

    # 保存结果
    output_dir = Path("docs/patents/reviews") / scorer.patent_id
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / "quality-score.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n评分结果已保存到: {output_file}")

if __name__ == "__main__":
    main()
