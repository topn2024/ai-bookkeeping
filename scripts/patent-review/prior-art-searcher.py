#!/usr/bin/env python3
"""
现有技术检索工具

功能:
1. 检索中国专利数据库(需要API接入)
2. 检索学术文献(知网、万方)(需要API接入)
3. 检索开源项目(GitHub)
4. 生成对比分析

注意: 本工具提供检索框架,实际检索需要接入真实API
输出: JSON格式的现有技术检索报告
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any
import re

class PriorArtSearcher:
    """现有技术检索器"""

    def __init__(self, patent_dir: str):
        self.patent_dir = Path(patent_dir)
        self.patent_id = self.patent_dir.name.split('-')[0]
        self.results = {
            "patent_id": self.patent_id,
            "patent_dir": str(self.patent_dir),
            "disclaimer": "⚠️ 本检索报告基于关键词提取,实际检索需接入专利数据库API",
            "search_keywords": [],
            "patent_search": {
                "status": "keywords_only",
                "note": "需要接入国家知识产权局专利检索API",
                "keywords": []
            },
            "literature_search": {
                "status": "keywords_only",
                "note": "需要接入CNKI、万方等学术数据库API",
                "keywords": []
            },
            "github_search": {
                "status": "keywords_only",
                "note": "可通过GitHub API检索,但需要人工筛选相关性",
                "keywords": []
            },
            "recommendations": []
        }

    def load_specification(self) -> str:
        """加载说明书内容"""
        spec_file = self.patent_dir / "specification.md"
        if not spec_file.exists():
            return ""
        return spec_file.read_text(encoding='utf-8')

    def load_metadata(self) -> Dict[str, Any]:
        """加载元数据"""
        metadata_file = self.patent_dir / "metadata.json"
        if not metadata_file.exists():
            return {}
        return json.loads(metadata_file.read_text(encoding='utf-8'))

    def extract_search_keywords(self, content: str, metadata: Dict[str, Any]) -> List[str]:
        """提取检索关键词"""
        keywords = []

        # 从元数据提取
        if "keywords" in metadata:
            keywords.extend(metadata["keywords"])

        # 从技术领域提取
        tech_field_match = re.search(r'### 技术领域(.*?)(?=###|$)', content, re.DOTALL)
        if tech_field_match:
            tech_field = tech_field_match.group(1)
            # 提取关键技术词
            tech_keywords = re.findall(r'([\u4e00-\u9fa5]{2,6}(?:技术|方法|系统|算法|模型))', tech_field)
            keywords.extend(tech_keywords[:5])

        # 从发明名称提取
        if "title" in metadata:
            title = metadata["title"]
            # 处理title可能是dict的情况
            if isinstance(title, dict):
                title = title.get("zh", "")
            # 移除"一种"、"基于"等常见词
            title_clean = re.sub(r'(一种|基于|用于|的|及|和)', ' ', title)
            title_keywords = [w for w in title_clean.split() if len(w) >= 2]
            keywords.extend(title_keywords[:3])

        # 去重并返回
        unique_keywords = []
        for kw in keywords:
            if kw and kw not in unique_keywords:
                unique_keywords.append(kw)

        return unique_keywords[:10]  # 最多10个关键词

    def generate_patent_search_strategy(self, keywords: List[str]) -> Dict[str, Any]:
        """生成专利检索策略"""
        strategy = {
            "status": "keywords_only",
            "note": "需要接入国家知识产权局专利检索API (http://epub.cnipa.gov.cn/)",
            "keywords": keywords,
            "search_fields": [
                "发明名称",
                "摘要",
                "权利要求",
                "说明书"
            ],
            "search_formula": " OR ".join([f"({kw})" for kw in keywords[:5]]),
            "filters": {
                "专利类型": "发明专利",
                "法律状态": "不限",
                "申请日": "近10年"
            },
            "manual_steps": [
                "1. 访问国家知识产权局专利检索系统",
                "2. 使用上述关键词组合检索",
                "3. 筛选相关度高的专利(至少5-10件)",
                "4. 下载专利全文进行详细对比",
                "5. 记录专利号、申请日、技术方案要点"
            ]
        }
        return strategy

    def generate_literature_search_strategy(self, keywords: List[str]) -> Dict[str, Any]:
        """生成学术文献检索策略"""
        strategy = {
            "status": "keywords_only",
            "note": "需要接入CNKI、万方、维普等学术数据库API",
            "keywords": keywords,
            "databases": [
                {
                    "name": "中国知网(CNKI)",
                    "url": "https://www.cnki.net/",
                    "search_fields": ["主题", "关键词", "摘要"]
                },
                {
                    "name": "万方数据",
                    "url": "https://www.wanfangdata.com.cn/",
                    "search_fields": ["主题", "关键词"]
                }
            ],
            "search_formula": " + ".join(keywords[:3]),
            "filters": {
                "文献类型": "学术期刊",
                "发表时间": "近5年",
                "学科分类": "计算机科学"
            },
            "manual_steps": [
                "1. 访问CNKI或万方数据库",
                "2. 使用关键词组合检索",
                "3. 筛选相关度高的文献(至少3-5篇)",
                "4. 下载全文阅读技术方案",
                "5. 记录文献标题、作者、发表时间、技术要点"
            ]
        }
        return strategy

    def generate_github_search_strategy(self, keywords: List[str]) -> Dict[str, Any]:
        """生成GitHub检索策略"""
        # 将中文关键词转换为可能的英文关键词
        keyword_translations = {
            "记账": "bookkeeping accounting",
            "语音": "voice speech",
            "多模态": "multimodal",
            "隐私": "privacy",
            "联邦学习": "federated learning",
            "游戏化": "gamification",
            "激励": "incentive reward",
            "预测": "prediction forecast",
            "分析": "analysis analytics"
        }

        english_keywords = []
        for kw in keywords:
            for cn, en in keyword_translations.items():
                if cn in kw:
                    english_keywords.extend(en.split())

        # 去重
        english_keywords = list(set(english_keywords))[:5]

        strategy = {
            "status": "keywords_only",
            "note": "可通过GitHub API检索,但需要人工判断相关性",
            "chinese_keywords": keywords[:5],
            "english_keywords": english_keywords,
            "search_query": " ".join(english_keywords),
            "search_filters": {
                "language": "Python OR JavaScript OR Java",
                "stars": ">100",
                "pushed": ">2020-01-01"
            },
            "manual_steps": [
                "1. 访问 https://github.com/search",
                f"2. 搜索: {' '.join(english_keywords)}",
                "3. 筛选相关开源项目(至少2-3个)",
                "4. 阅读README和核心代码",
                "5. 记录项目名称、star数、技术实现方式"
            ]
        }
        return strategy

    def generate_recommendations(self, keywords: List[str]):
        """生成检索建议"""
        self.results["recommendations"] = [
            {
                "priority": "high",
                "type": "必须执行",
                "message": "进行专利检索以评估新颖性和创造性",
                "steps": [
                    f"使用关键词: {', '.join(keywords[:5])}",
                    "在国家知识产权局专利检索系统检索",
                    "重点关注申请日早于本专利的相关专利",
                    "至少找到5-10件相关专利进行对比"
                ]
            },
            {
                "priority": "medium",
                "type": "建议执行",
                "message": "检索学术文献了解技术背景",
                "steps": [
                    "在CNKI或万方检索相关学术论文",
                    "了解该技术领域的研究现状",
                    "识别可能的现有技术组合"
                ]
            },
            {
                "priority": "low",
                "type": "可选执行",
                "message": "检索开源项目了解实现方式",
                "steps": [
                    "在GitHub检索相关开源项目",
                    "了解常见的技术实现方式",
                    "评估本专利的技术方案是否为常规手段"
                ]
            }
        ]

    def run_search(self) -> Dict[str, Any]:
        """运行检索"""
        print(f"正在生成检索策略: {self.patent_id}")
        print(f"专利目录: {self.patent_dir}")
        print("-" * 60)

        content = self.load_specification()
        metadata = self.load_metadata()

        if not content:
            print("错误: 无法加载说明书")
            return self.results

        # 提取关键词
        keywords = self.extract_search_keywords(content, metadata)
        self.results["search_keywords"] = keywords

        print(f"提取的检索关键词: {', '.join(keywords)}")

        # 生成检索策略
        self.results["patent_search"] = self.generate_patent_search_strategy(keywords)
        self.results["literature_search"] = self.generate_literature_search_strategy(keywords)
        self.results["github_search"] = self.generate_github_search_strategy(keywords)

        # 生成建议
        self.generate_recommendations(keywords)

        return self.results

    def print_summary(self):
        """打印检索摘要"""
        print("\n" + "=" * 60)
        print("现有技术检索策略")
        print("=" * 60)
        print(f"⚠️ {self.results['disclaimer']}")
        print()

        print(f"检索关键词({len(self.results['search_keywords'])}个):")
        for i, kw in enumerate(self.results['search_keywords'], 1):
            print(f"  {i}. {kw}")

        print(f"\n专利检索: {self.results['patent_search']['status']}")
        print(f"  检索式: {self.results['patent_search']['search_formula']}")

        print(f"\n学术文献检索: {self.results['literature_search']['status']}")
        print(f"  检索式: {self.results['literature_search']['search_formula']}")

        print(f"\nGitHub检索: {self.results['github_search']['status']}")
        print(f"  英文关键词: {', '.join(self.results['github_search']['english_keywords'])}")

        if self.results["recommendations"]:
            print(f"\n检索建议:")
            for rec in self.results["recommendations"]:
                print(f"  [{rec['priority'].upper()}] {rec['message']}")

def main():
    if len(sys.argv) < 2:
        print("用法: python prior-art-searcher.py <专利目录路径>")
        print("示例: python prior-art-searcher.py docs/patents/patents/P12-游戏化激励")
        sys.exit(1)

    patent_dir = sys.argv[1]

    if not os.path.exists(patent_dir):
        print(f"错误: 专利目录不存在: {patent_dir}")
        sys.exit(1)

    # 运行检索
    searcher = PriorArtSearcher(patent_dir)
    results = searcher.run_search()
    searcher.print_summary()

    # 保存结果
    output_dir = Path("docs/patents/reviews") / searcher.patent_id
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / "prior-art-search.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n检索策略已保存到: {output_file}")

if __name__ == "__main__":
    main()
