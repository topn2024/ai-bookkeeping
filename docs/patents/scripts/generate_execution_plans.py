#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量生成专利检索执行方案
"""

import os

# 专利数据
patents_data = {
    'P05': {
        'name': 'LLM语音交互',
        'full_name': '基于大语言模型的智能语音记账交互方法',
        'score': 71.5,
        'risk': '中等',
        'time': 14,
        'queries_cn': [
            '(大语言模型 OR LLM OR GPT OR BERT OR Transformer) AND (语音交互 OR 语音对话 OR 语音助手) AND (意图识别 OR 意图理解 OR 自然语言理解)',
            '(语音记账 OR 智能记账 OR 自动记账) AND (对话系统 OR 多轮对话 OR 对话管理)',
            '(语音识别 OR ASR) AND (大语言模型 OR LLM) AND (财务 OR 记账 OR 账本)'
        ],
        'queries_en': [
            '"Large Language Model" AND ("Voice Interaction" OR "Voice Dialog") AND ("Intent Recognition" OR "Intent Understanding")',
            '"Voice Bookkeeping" AND ("Dialog System" OR "Multi-turn Dialog")',
            '"Speech Recognition" AND "LLM" AND ("Financial" OR "Bookkeeping")'
        ],
        'keywords_cn': ['大语言模型', 'LLM', '语音交互', '意图识别', '多轮对话', '记账', '语音识别', '自然语言理解'],
        'keywords_en': ['Large Language Model', 'LLM', 'Voice Interaction', 'Intent Recognition', 'Multi-turn Dialog', 'Bookkeeping'],
        'competitors': ['阿里巴巴', '腾讯', '字节跳动', '科大讯飞', '百度'],
        'ipc': ['G06F16/332', 'G06F40/30', 'G10L15/00', 'G10L15/22', 'G06Q40/00']
    },
    'P11': {
        'name': '离线增量同步',
        'full_name': '基于金额精度保护的离线增量同步方法',
        'score': 71.5,
        'risk': '中等',
        'time': 14,
        'queries_cn': [
            '(离线同步 OR 增量同步 OR 数据同步) AND (金额精度 OR Decimal OR 高精度) AND (冲突解决 OR CRDT OR 分布式一致性)',
            '(财务数据 OR 金额数据 OR 账本) AND (离线同步 OR 增量同步) AND (精度保护 OR Decimal)',
            '(CRDT OR 无冲突复制) AND (事务原子性 OR 原子操作) AND (数据同步 OR 分布式同步)'
        ],
        'queries_en': [
            '"Offline Sync" AND ("Decimal Precision" OR "High Precision") AND ("CRDT" OR "Conflict Resolution")',
            '"Financial Data" AND "Offline Synchronization" AND "Decimal"',
            '"CRDT" AND "Transaction Atomicity" AND "Data Synchronization"'
        ],
        'keywords_cn': ['离线同步', '增量同步', '金额精度', 'Decimal', 'CRDT', '冲突解决', '事务原子性', '分布式一致性'],
        'keywords_en': ['Offline Sync', 'Incremental Sync', 'Decimal Precision', 'CRDT', 'Conflict Resolution', 'Transaction Atomicity'],
        'competitors': ['阿里巴巴', '腾讯', '华为', '字节跳动'],
        'ipc': ['G06F16/27', 'G06F16/23', 'G06F9/46', 'G06Q40/00', 'H04L67/1095']
    },
    'P12': {
        'name': '游戏化激励',
        'full_name': '基于行为分析的游戏化记账激励系统',
        'score': 78.0,
        'risk': '中高',
        'time': 12,
        'queries_cn': [
            '(游戏化 OR Gamification OR 游戏化设计) AND (激励系统 OR 激励机制 OR 用户激励) AND (行为分析 OR 用户行为)',
            '(记账 OR 财务管理 OR 账本) AND (游戏化 OR 激励系统) AND (用户留存 OR 用户活跃)',
            '(成就系统 OR 等级系统 OR 积分系统 OR 排行榜) AND (动态难度 OR 自适应) AND (用户行为 OR 行为分析)'
        ],
        'queries_en': [
            '"Gamification" AND ("Incentive System" OR "Motivation") AND "Behavior Analysis"',
            '"Bookkeeping" AND "Gamification" AND ("User Retention" OR "User Engagement")',
            '"Achievement System" AND "Dynamic Difficulty" AND "Behavior Analysis"'
        ],
        'keywords_cn': ['游戏化', '激励系统', '行为分析', '记账', '用户留存', '成就系统', '等级系统', '积分系统'],
        'keywords_en': ['Gamification', 'Incentive System', 'Behavior Analysis', 'Bookkeeping', 'User Retention', 'Achievement System'],
        'competitors': ['阿里巴巴（蚂蚁森林）', '腾讯（微信运动）', 'Keep', 'Forest', 'Habitica'],
        'ipc': ['G06Q30/02', 'G06Q50/00', 'G06F3/01', 'A63F13/00']
    },
    'P18': {
        'name': '消费趋势预测',
        'full_name': '基于时间序列分析的消费趋势预测方法',
        'score': 86.8,
        'risk': '低',
        'time': 12,
        'queries_cn': [
            '(时间序列 OR 时序分析 OR 时间序列预测) AND (消费预测 OR 消费趋势 OR 支出预测) AND (LSTM OR 长短期记忆网络 OR 循环神经网络)',
            '(财务预测 OR 预算预测 OR 支出预测) AND (深度学习 OR 神经网络 OR 机器学习) AND (趋势分析 OR 趋势预测)',
            '(LSTM OR RNN OR 循环神经网络) AND (季节性分解 OR 周期性分析) AND (异常检测 OR 异常识别)'
        ],
        'queries_en': [
            '"Time Series" AND ("Spending Prediction" OR "Consumption Forecast") AND "LSTM"',
            '"Financial Forecasting" AND "Deep Learning" AND "Trend Analysis"',
            '"LSTM" AND "Seasonal Decomposition" AND "Anomaly Detection"'
        ],
        'keywords_cn': ['时间序列', '消费预测', 'LSTM', '趋势分析', '季节性分解', '异常检测', '深度学习'],
        'keywords_en': ['Time Series', 'Spending Prediction', 'LSTM', 'Trend Analysis', 'Seasonal Decomposition', 'Anomaly Detection'],
        'competitors': ['阿里巴巴', '腾讯', '京东', '蚂蚁金服', '百度'],
        'ipc': ['G06Q40/00', 'G06Q30/02', 'G06N3/04', 'G06N3/08', 'G06F17/18']
    }
}

def generate_execution_plan(patent_id, data):
    """生成检索执行方案"""

    template = f"""# {patent_id}-{data['name']} 现有技术检索执行方案

**专利ID**: {patent_id}
**专利名称**: {data['full_name']}
**检索日期**: 2026-01-19
**检索人**: [待填写]
**优先级**: ⭐⭐⭐⭐⭐（第一优先级）
**当前评分**: {data['score']}/100
**风险等级**: {data['risk']}
**预计检索时间**: {data['time']}小时

---

## 1. 检索准备

### 1.1 检索目标

**主要目标**:
1. 确认是否存在相同或高度相似的技术方案
2. 评估新颖性和创造性
3. 识别潜在的驳回风险
4. 为专利优化提供依据

---

## 2. 检索步骤

### 步骤1: 国家知识产权局检索（3-4小时）

**数据库**: http://pss-system.cnipa.gov.cn

**检索式1**:
```
{data['queries_cn'][0]}
```

**检索式2**:
```
{data['queries_cn'][1]}
```

**检索式3**:
```
{data['queries_cn'][2]}
```

**检索步骤**:
1. 登录国家知识产权局专利检索系统
2. 选择"高级检索"
3. 在"摘要"字段输入检索式
4. 筛选2015-2026年的专利
5. 浏览前50条结果，标记相关专利
6. 记录检索结果

**记录模板**:
| 检索式 | 结果数 | 相关数 | 高度相关 | 备注 |
|--------|--------|--------|----------|------|
| 检索式1 | | | | |
| 检索式2 | | | | |
| 检索式3 | | | | |

### 步骤2: CNKI学术文献检索（2-3小时）

**数据库**: https://www.cnki.net

**检索式**（转换为CNKI格式，使用+和*）:
- 检索式1: 将OR替换为+，AND替换为*
- 检索式2: 同上
- 检索式3: 同上

**记录模板**:
| 检索式 | 结果数 | 相关数 | 高引用 | 备注 |
|--------|--------|--------|--------|------|
| 检索式1 | | | | |
| 检索式2 | | | | |
| 检索式3 | | | | |

### 步骤3: Google Scholar检索（2-3小时）

**数据库**: https://scholar.google.com

**检索式1（英文）**:
```
{data['queries_en'][0]}
```

**检索式2**:
```
{data['queries_en'][1]}
```

**检索式3**:
```
{data['queries_en'][2]}
```

**记录模板**:
| 检索式 | 结果数 | 相关数 | 高引用 | 备注 |
|--------|--------|--------|--------|------|
| 检索式1 | | | | |
| 检索式2 | | | | |
| 检索式3 | | | | |

### 步骤4: Google Patents检索（1-2小时）

**数据库**: https://patents.google.com

使用英文检索式，筛选2015-2026年的国际专利。

**记录模板**:
| 检索式 | 结果数 | 相关数 | 高度相关 | 备注 |
|--------|--------|--------|----------|------|
| 检索式1 | | | | |
| 检索式2 | | | | |

### 步骤5: 竞争对手检索（1小时）

**重点关注公司**:
{chr(10).join(f'- {comp}' for comp in data['competitors'])}

**检索方法**:
在CNIPA中搜索: 申请人="[公司名]" AND [相关关键词]

### 步骤6: 引文检索（1小时）

选择3-5篇高度相关的专利/论文，查看其引用和被引文献。

---

## 3. 相关文献记录模板

### 3.1 高度相关文献

**文献1**:
- 文献编号: [专利号/论文编号]
- 标题: [标题]
- 申请人/作者: [姓名]
- 公开日期: [YYYY-MM-DD]
- 相关度: 高
- 相关技术点: [列表]
- 差异点: [与本专利的差异]
- 影响评估:
  - 对新颖性的影响: [高/中/低]
  - 对创造性的影响: [高/中/低]

---

## 4. 新颖性评估

### 4.1 对比分析

**最接近的现有技术**: [文献编号]

**差异点总结**:
1. [差异点1]
2. [差异点2]
3. [差异点3]

### 4.2 新颖性结论

**新颖性等级**: [高/中/低/无]

**理由**: [详细说明]

---

## 5. 创造性评估

### 5.1 最接近现有技术

**文献编号**: [编号]

### 5.2 区别特征

1. [区别特征1]
2. [区别特征2]
3. [区别特征3]

### 5.3 创造性结论

**创造性等级**: [高/中/低/无]

**理由**: [详细说明]

---

## 6. 综合评估

### 6.1 授权可行性

**授权可行性**: [高/中/低]

**预计授权概率**: [XX%]

### 6.2 风险提示

**主要风险**:
1. [风险1]
2. [风险2]

### 6.3 优化建议

**必须优化**:
1. [建议1]
2. [建议2]

---

## 7. 检索总结

### 7.1 检索统计

| 数据库 | 检索式数 | 结果总数 | 相关文献数 | 高度相关数 |
|--------|----------|----------|------------|------------|
| CNIPA | 3 | | | |
| CNKI | 3 | | | |
| Google Scholar | 3 | | | |
| Google Patents | 2 | | | |
| 竞争对手 | - | | | |
| 引文检索 | - | | | |
| **总计** | **11+** | | | |

### 7.2 时间统计

| 阶段 | 预计时间 | 实际时间 | 备注 |
|------|----------|----------|------|
| CNIPA检索 | 3-4小时 | | |
| CNKI检索 | 2-3小时 | | |
| Google Scholar | 2-3小时 | | |
| Google Patents | 1-2小时 | | |
| 竞争对手检索 | 1小时 | | |
| 引文检索 | 1小时 | | |
| 整理分析 | 2小时 | | |
| **总计** | **{data['time']}小时** | | |

---

## 8. 附录

### 8.1 检索关键词清单

**中文关键词**:
{', '.join(data['keywords_cn'])}

**英文关键词**:
{', '.join(data['keywords_en'])}

### 8.2 IPC分类号

{chr(10).join(f'- {ipc}' for ipc in data['ipc'])}

---

**文档创建日期**: 2026-01-19
**预计检索完成日期**: [填写]
**预计报告完成日期**: [填写]
"""

    return template

def main():
    """主函数"""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(os.path.dirname(base_dir), 'reviews', 'search-execution')

    # 创建输出目录
    os.makedirs(output_dir, exist_ok=True)

    # 生成执行方案
    for patent_id in ['P05', 'P11', 'P12', 'P18']:
        data = patents_data[patent_id]
        content = generate_execution_plan(patent_id, data)

        output_file = os.path.join(output_dir, f'{patent_id}-execution-plan.md')
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)

        print(f'✅ 已生成: {patent_id}-execution-plan.md')

    print(f'\n所有执行方案已生成到: {output_dir}')

if __name__ == '__main__':
    main()
