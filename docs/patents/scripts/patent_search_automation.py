#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
专利现有技术自动化检索工具
用于生成检索查询、记录结果、分析相关性
"""

import json
import os
import re
from datetime import datetime
from typing import List, Dict, Any

class PatentSearchAutomation:
    """专利检索自动化工具"""

    def __init__(self, patent_id: str, strategy_file: str):
        """
        初始化检索工具

        Args:
            patent_id: 专利ID（如P05）
            strategy_file: 检索策略文件路径
        """
        self.patent_id = patent_id
        self.strategy_file = strategy_file
        self.search_queries = []
        self.search_results = []

    def load_strategy(self) -> Dict[str, Any]:
        """加载检索策略"""
        with open(self.strategy_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # 提取检索式
        queries = re.findall(r'```\n(.+?)\n```', content, re.DOTALL)

        strategy = {
            'patent_id': self.patent_id,
            'queries': queries,
            'databases': self._extract_databases(content),
            'keywords': self._extract_keywords(content)
        }

        return strategy

    def _extract_databases(self, content: str) -> List[str]:
        """提取检索数据库"""
        databases = []
        if '国家知识产权局' in content:
            databases.append('CNIPA')
        if 'CNKI' in content or '中国知网' in content:
            databases.append('CNKI')
        if '万方' in content:
            databases.append('Wanfang')
        if 'Google Scholar' in content:
            databases.append('Google Scholar')
        if 'Google Patents' in content:
            databases.append('Google Patents')
        return databases

    def _extract_keywords(self, content: str) -> Dict[str, List[str]]:
        """提取关键词"""
        keywords = {
            'chinese': [],
            'english': []
        }

        # 提取中文关键词
        cn_section = re.search(r'### 2\.1 中文关键词(.+?)### 2\.2', content, re.DOTALL)
        if cn_section:
            # 提取列表项
            cn_keywords = re.findall(r'- (.+)', cn_section.group(1))
            keywords['chinese'] = [kw.strip() for kw in cn_keywords if kw.strip()]

        # 提取英文关键词
        en_section = re.search(r'### 2\.2 英文关键词(.+?)---', content, re.DOTALL)
        if en_section:
            en_keywords = re.findall(r'- (.+)', en_section.group(1))
            keywords['english'] = [kw.strip() for kw in en_keywords if kw.strip()]

        return keywords

    def generate_search_queries(self, database: str) -> List[str]:
        """
        生成特定数据库的检索查询

        Args:
            database: 数据库名称（CNIPA, CNKI, Google Scholar等）

        Returns:
            检索查询列表
        """
        strategy = self.load_strategy()
        queries = []

        if database == 'CNIPA':
            # 国家知识产权局检索式
            for query in strategy['queries']:
                if 'AND' in query and 'OR' in query:
                    queries.append(query.strip())

        elif database == 'CNKI':
            # CNKI检索式（支持高级检索）
            for query in strategy['queries']:
                # 转换为CNKI格式
                cnki_query = query.replace('OR', '+').replace('AND', '*')
                queries.append(cnki_query.strip())

        elif database == 'Google Scholar':
            # Google Scholar检索式（简化）
            for query in strategy['queries']:
                # 转换为Google Scholar格式
                gs_query = query.replace('OR', '|').replace('AND', '')
                queries.append(gs_query.strip())

        return queries

    def create_search_record_template(self) -> Dict[str, Any]:
        """创建检索记录模板"""
        return {
            'patent_id': self.patent_id,
            'search_date': datetime.now().strftime('%Y-%m-%d'),
            'searcher': '',
            'database': '',
            'query': '',
            'total_results': 0,
            'relevant_results': 0,
            'highly_relevant': [],
            'notes': ''
        }

    def save_search_record(self, record: Dict[str, Any], output_file: str):
        """保存检索记录"""
        records = []

        # 读取现有记录
        if os.path.exists(output_file):
            with open(output_file, 'r', encoding='utf-8') as f:
                records = json.load(f)

        # 添加新记录
        records.append(record)

        # 保存
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(records, f, ensure_ascii=False, indent=2)

    def analyze_relevance(self, document: Dict[str, Any]) -> float:
        """
        分析文献相关性

        Args:
            document: 文献信息（标题、摘要等）

        Returns:
            相关性评分（0-1）
        """
        strategy = self.load_strategy()
        keywords = strategy['keywords']

        # 提取文献文本
        text = document.get('title', '') + ' ' + document.get('abstract', '')
        text = text.lower()

        # 计算关键词匹配度
        cn_matches = sum(1 for kw in keywords['chinese'] if kw.lower() in text)
        en_matches = sum(1 for kw in keywords['english'] if kw.lower() in text)

        total_keywords = len(keywords['chinese']) + len(keywords['english'])
        if total_keywords == 0:
            return 0.0

        relevance = (cn_matches + en_matches) / total_keywords
        return min(relevance, 1.0)

    def generate_search_report(self, records: List[Dict[str, Any]], output_file: str):
        """生成检索报告"""
        report = f"""# {self.patent_id} 现有技术检索报告

**专利ID**: {self.patent_id}
**检索日期**: {datetime.now().strftime('%Y-%m-%d')}

---

## 1. 检索概况

"""

        # 统计
        total_results = sum(r['total_results'] for r in records)
        relevant_results = sum(r['relevant_results'] for r in records)

        report += f"""- 检索数据库: {len(set(r['database'] for r in records))}个
- 检索式数量: {len(records)}个
- 检索结果总数: {total_results}篇
- 相关文献数: {relevant_results}篇

---

## 2. 检索记录

"""

        for i, record in enumerate(records, 1):
            report += f"""### 检索{i}

- 数据库: {record['database']}
- 检索式: `{record['query']}`
- 结果数: {record['total_results']}篇
- 相关数: {record['relevant_results']}篇

"""

        report += """---

## 3. 相关文献列表

（待补充）

---

## 4. 新颖性评估

（待补充）

---

## 5. 创造性评估

（待补充）

---

## 6. 综合评估

（待补充）
"""

        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(report)


def main():
    """主函数"""
    import sys

    if len(sys.argv) < 2:
        print("用法: python3 patent_search_automation.py <patent_id>")
        print("示例: python3 patent_search_automation.py P05")
        sys.exit(1)

    patent_id = sys.argv[1]

    # 查找检索策略文件
    base_dir = os.path.dirname(os.path.abspath(__file__))
    patents_dir = os.path.dirname(base_dir)
    strategy_dir = os.path.join(patents_dir, 'reviews', 'search-strategies')

    # 查找匹配的策略文件
    strategy_files = [f for f in os.listdir(strategy_dir) if f.startswith(patent_id)]

    if not strategy_files:
        print(f"错误: 未找到{patent_id}的检索策略文件")
        sys.exit(1)

    strategy_file = os.path.join(strategy_dir, strategy_files[0])

    # 创建检索工具
    tool = PatentSearchAutomation(patent_id, strategy_file)

    # 加载策略
    strategy = tool.load_strategy()

    print(f"=== {patent_id} 检索策略 ===\n")
    print(f"数据库: {', '.join(strategy['databases'])}")
    print(f"\n检索式数量: {len(strategy['queries'])}")
    print(f"\n中文关键词: {len(strategy['keywords']['chinese'])}个")
    print(f"英文关键词: {len(strategy['keywords']['english'])}个")

    # 生成检索查询
    print(f"\n=== 生成检索查询 ===\n")
    for db in strategy['databases']:
        queries = tool.generate_search_queries(db)
        print(f"{db}:")
        for i, query in enumerate(queries[:3], 1):  # 只显示前3个
            print(f"  {i}. {query[:100]}...")
        print()

    # 创建检索记录模板
    print("=== 检索记录模板 ===\n")
    template = tool.create_search_record_template()
    print(json.dumps(template, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
