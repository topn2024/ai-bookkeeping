#!/usr/bin/env python3
"""
专利技术性分析工具(AI辅助)

功能:
1. 识别技术问题 vs 商业问题
2. 分析技术手段
3. 评估技术效果
4. 提取技术特征
5. 判断是否符合《专利审查指南》对计算机程序发明的要求

输出: JSON格式的技术性分析报告(标注为AI意见)
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any
import re

class TechnicalAnalyzer:
    """专利技术性分析器(AI辅助)"""

    def __init__(self, patent_dir: str):
        self.patent_dir = Path(patent_dir)
        self.patent_id = self.patent_dir.name.split('-')[0]
        self.results = {
            "patent_id": self.patent_id,
            "patent_dir": str(self.patent_dir),
            "disclaimer": "⚠️ 以下为AI辅助分析意见,非最终法律结论",
            "analysis": {},
            "ai_opinions": [],
            "recommendations": []
        }

    def load_specification(self) -> str:
        """加载说明书内容"""
        spec_file = self.patent_dir / "specification.md"
        if not spec_file.exists():
            return ""
        return spec_file.read_text(encoding='utf-8')

    def extract_technical_features(self, content: str) -> Dict[str, Any]:
        """提取技术特征(AI分析)"""
        analysis = {
            "name": "技术特征提取",
            "type": "AI分析",
            "features": []
        }

        # 查找算法描述
        algorithm_pattern = r'算法\s*\d+[：:](.*?)(?=算法\s*\d+|###|$)'
        algorithms = re.findall(algorithm_pattern, content, re.DOTALL)

        for i, algo in enumerate(algorithms[:5], 1):  # 最多提取5个算法
            # 提取算法名称
            name_match = re.search(r'^(.*?)(?:\n|输入)', algo.strip())
            algo_name = name_match.group(1).strip() if name_match else f"算法{i}"

            analysis["features"].append({
                "type": "算法",
                "name": algo_name,
                "description": algo[:200].strip() + "..." if len(algo) > 200 else algo.strip()
            })

        # 查找数据结构
        data_structure_pattern = r'(struct|class|interface|数据结构)\s+(\w+)\s*\{'
        structures = re.findall(data_structure_pattern, content)

        for struct_type, struct_name in structures[:5]:
            analysis["features"].append({
                "type": "数据结构",
                "name": struct_name,
                "description": f"{struct_type} {struct_name}"
            })

        return analysis

    def analyze_technical_problem(self, content: str) -> Dict[str, Any]:
        """分析技术问题(AI判断)"""
        analysis = {
            "name": "技术问题识别",
            "type": "AI判断",
            "technical_problems": [],
            "business_problems": [],
            "risk_level": "low"
        }

        # 商业问题关键词
        business_keywords = [
            "用户留存", "用户满意度", "商业价值", "市场份额",
            "收入", "利润", "转化率", "活跃度", "粘性"
        ]

        # 技术问题关键词
        technical_keywords = [
            "计算效率", "响应时间", "内存占用", "CPU占用",
            "准确率", "召回率", "吞吐量", "并发", "延迟",
            "算法复杂度", "数据结构", "系统性能"
        ]

        # 在背景技术和发明内容中查找问题描述
        background_match = re.search(r'### 背景技术(.*?)(?=###|$)', content, re.DOTALL)
        invention_match = re.search(r'### 发明内容(.*?)(?=###|$)', content, re.DOTALL)

        problem_text = ""
        if background_match:
            problem_text += background_match.group(1)
        if invention_match:
            problem_text += invention_match.group(1)

        # 检测商业问题
        for keyword in business_keywords:
            if keyword in problem_text:
                analysis["business_problems"].append({
                    "keyword": keyword,
                    "context": self._extract_context(problem_text, keyword)
                })

        # 检测技术问题
        for keyword in technical_keywords:
            if keyword in problem_text:
                analysis["technical_problems"].append({
                    "keyword": keyword,
                    "context": self._extract_context(problem_text, keyword)
                })

        # AI判断风险等级
        if len(analysis["business_problems"]) > len(analysis["technical_problems"]):
            analysis["risk_level"] = "high"
            self.results["ai_opinions"].append({
                "type": "technical_problem_risk",
                "severity": "high",
                "message": "AI判断:背景技术中商业问题描述多于技术问题,存在被认定为商业方法的风险",
                "legal_basis": "《专利审查指南》第二部分第九章第5.2节",
                "recommendation": "建议重点强调技术问题,如计算效率、系统性能、算法创新等"
            })
        elif len(analysis["technical_problems"]) == 0:
            analysis["risk_level"] = "high"
            self.results["ai_opinions"].append({
                "type": "no_technical_problem",
                "severity": "high",
                "message": "AI判断:未明确识别到技术问题",
                "legal_basis": "《专利审查指南》第二部分第九章第5.2节",
                "recommendation": "必须明确说明解决的技术问题"
            })
        else:
            analysis["risk_level"] = "low"

        return analysis

    def analyze_technical_effects(self, content: str) -> Dict[str, Any]:
        """分析技术效果(AI判断)"""
        analysis = {
            "name": "技术效果分析",
            "type": "AI判断",
            "technical_effects": [],
            "business_effects": [],
            "quantified": False,
            "risk_level": "low"
        }

        # 技术效果关键词
        technical_effect_keywords = [
            "响应时间", "计算时间", "处理速度", "内存占用",
            "准确率", "召回率", "精确率", "F1值",
            "吞吐量", "并发数", "延迟", "带宽"
        ]

        # 商业效果关键词
        business_effect_keywords = [
            "用户满意度", "留存率", "转化率", "活跃度",
            "收入", "成本", "市场份额", "用户体验"
        ]

        # 在技术效果部分查找
        effect_match = re.search(r'(技术效果|有益效果)(.*?)(?=###|##|$)', content, re.DOTALL)
        effect_text = effect_match.group(2) if effect_match else content

        # 检测技术效果
        for keyword in technical_effect_keywords:
            if keyword in effect_text:
                context = self._extract_context(effect_text, keyword)
                # 检查是否量化
                quantified = bool(re.search(r'\d+%|\d+ms|\d+MB|\d+倍', context))
                analysis["technical_effects"].append({
                    "keyword": keyword,
                    "context": context,
                    "quantified": quantified
                })
                if quantified:
                    analysis["quantified"] = True

        # 检测商业效果
        for keyword in business_effect_keywords:
            if keyword in effect_text:
                analysis["business_effects"].append({
                    "keyword": keyword,
                    "context": self._extract_context(effect_text, keyword)
                })

        # AI判断
        if len(analysis["business_effects"]) > 0:
            analysis["risk_level"] = "medium"
            self.results["ai_opinions"].append({
                "type": "business_effect_risk",
                "severity": "medium",
                "message": f"AI判断:技术效果中包含{len(analysis['business_effects'])}个商业指标",
                "legal_basis": "《专利审查指南》第二部分第九章第5.2节",
                "recommendation": "建议删除商业指标,仅保留技术指标"
            })

        if not analysis["quantified"]:
            self.results["ai_opinions"].append({
                "type": "effect_not_quantified",
                "severity": "medium",
                "message": "AI判断:技术效果未量化",
                "legal_basis": "《专利审查指南》第二部分第二章第2.2.3节",
                "recommendation": "建议量化技术效果,如'响应时间<80ms'、'准确率>95%'"
            })

        return analysis

    def analyze_technical_means(self, content: str) -> Dict[str, Any]:
        """分析技术手段(AI分析)"""
        analysis = {
            "name": "技术手段分析",
            "type": "AI分析",
            "algorithms": [],
            "data_structures": [],
            "system_architecture": []
        }

        # 提取算法
        algorithm_count = len(re.findall(r'算法\s*\d+', content))
        analysis["algorithms"] = {
            "count": algorithm_count,
            "found": algorithm_count > 0
        }

        # 提取数据结构
        data_structure_keywords = ["struct", "class", "数据结构", "数据模型"]
        for keyword in data_structure_keywords:
            if keyword in content:
                analysis["data_structures"].append(keyword)

        # 提取系统架构
        architecture_keywords = ["架构", "模块", "组件", "系统设计"]
        for keyword in architecture_keywords:
            if keyword in content:
                analysis["system_architecture"].append(keyword)

        return analysis

    def _extract_context(self, text: str, keyword: str, context_length: int = 100) -> str:
        """提取关键词上下文"""
        pos = text.find(keyword)
        if pos == -1:
            return ""

        start = max(0, pos - context_length // 2)
        end = min(len(text), pos + len(keyword) + context_length // 2)

        context = text[start:end].strip()
        if start > 0:
            context = "..." + context
        if end < len(text):
            context = context + "..."

        return context

    def run_analysis(self) -> Dict[str, Any]:
        """运行技术性分析"""
        print(f"正在分析专利技术性: {self.patent_id}")
        print(f"专利目录: {self.patent_dir}")
        print("-" * 60)

        content = self.load_specification()
        if not content:
            print("错误: 无法加载说明书")
            return self.results

        # 运行各项分析
        self.results["analysis"]["technical_features"] = self.extract_technical_features(content)
        self.results["analysis"]["technical_problem"] = self.analyze_technical_problem(content)
        self.results["analysis"]["technical_effects"] = self.analyze_technical_effects(content)
        self.results["analysis"]["technical_means"] = self.analyze_technical_means(content)

        # 生成综合建议
        self._generate_recommendations()

        return self.results

    def _generate_recommendations(self):
        """生成改进建议"""
        # 基于AI判断生成建议
        high_risk_opinions = [op for op in self.results["ai_opinions"] if op["severity"] == "high"]
        medium_risk_opinions = [op for op in self.results["ai_opinions"] if op["severity"] == "medium"]

        if high_risk_opinions:
            self.results["recommendations"].append({
                "priority": "high",
                "type": "必须改进",
                "message": f"发现{len(high_risk_opinions)}个高风险问题,必须解决",
                "items": [op["recommendation"] for op in high_risk_opinions]
            })

        if medium_risk_opinions:
            self.results["recommendations"].append({
                "priority": "medium",
                "type": "建议优化",
                "message": f"发现{len(medium_risk_opinions)}个中风险问题,建议优化",
                "items": [op["recommendation"] for op in medium_risk_opinions]
            })

    def print_summary(self):
        """打印分析摘要"""
        print("\n" + "=" * 60)
        print("技术性分析摘要(AI辅助)")
        print("=" * 60)
        print(f"⚠️ {self.results['disclaimer']}")
        print()

        # 技术特征
        features = self.results["analysis"]["technical_features"]["features"]
        print(f"识别的技术特征: {len(features)}个")

        # 技术问题
        problem_analysis = self.results["analysis"]["technical_problem"]
        print(f"技术问题: {len(problem_analysis['technical_problems'])}个")
        print(f"商业问题: {len(problem_analysis['business_problems'])}个")
        print(f"风险等级: {problem_analysis['risk_level'].upper()}")

        # 技术效果
        effect_analysis = self.results["analysis"]["technical_effects"]
        print(f"技术效果: {len(effect_analysis['technical_effects'])}个")
        print(f"商业效果: {len(effect_analysis['business_effects'])}个")
        print(f"是否量化: {'是' if effect_analysis['quantified'] else '否'}")

        # AI意见
        if self.results["ai_opinions"]:
            print(f"\nAI判断意见: {len(self.results['ai_opinions'])}条")
            for i, opinion in enumerate(self.results["ai_opinions"], 1):
                print(f"  {i}. [{opinion['severity'].upper()}] {opinion['message']}")

        # 改进建议
        if self.results["recommendations"]:
            print(f"\n改进建议:")
            for rec in self.results["recommendations"]:
                print(f"  [{rec['priority'].upper()}] {rec['message']}")

def main():
    if len(sys.argv) < 2:
        print("用法: python technical-analyzer.py <专利目录路径>")
        print("示例: python technical-analyzer.py docs/patents/patents/P12-游戏化激励")
        sys.exit(1)

    patent_dir = sys.argv[1]

    if not os.path.exists(patent_dir):
        print(f"错误: 专利目录不存在: {patent_dir}")
        sys.exit(1)

    # 运行分析
    analyzer = TechnicalAnalyzer(patent_dir)
    results = analyzer.run_analysis()
    analyzer.print_summary()

    # 保存结果
    output_dir = Path("docs/patents/reviews") / analyzer.patent_id
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / "technical-analysis.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n分析结果已保存到: {output_file}")

if __name__ == "__main__":
    main()
