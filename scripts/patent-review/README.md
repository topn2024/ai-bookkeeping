# 专利审查工具集

本目录包含用于专利授权可行性审查的自动化工具。

## 工具列表

### 1. compliance-checker.py
**功能**: 法律合规性检查
- 检查必要技术特征
- 检查权利要求清楚性
- 检查说明书支持
- 检查文档结构完整性

**输出**: 合规性检查报告(JSON格式)

### 2. technical-analyzer.py
**功能**: 技术性分析(AI辅助)
- 识别技术问题 vs 商业问题
- 分析技术手段
- 评估技术效果
- 提取技术特征

**输出**: 技术性分析报告(JSON格式)

### 3. prior-art-searcher.py
**功能**: 现有技术检索
- 检索中国专利数据库
- 检索学术文献(知网、万方)
- 检索开源项目(GitHub)
- 生成对比分析

**输出**: 现有技术检索报告(JSON格式)

### 4. quality-scorer.py
**功能**: 质量评分
- 五维评分(法律合规性、技术性、文档质量、现有技术对比、商业价值)
- 生成雷达图
- 预估授权成功率(AI估计)

**输出**: 质量评分报告(JSON + 可视化图表)

### 5. report-generator.py
**功能**: 生成综合审查报告
- 整合所有工具的输出
- 生成Markdown格式的审查报告
- 区分客观事实和AI判断
- 提供改进建议

**输出**: 综合审查报告(Markdown格式)

## 使用方法

### 单个专利审查
```bash
# 完整审查流程
python scripts/patent-review/review-patent.py --patent-id P12

# 仅运行特定工具
python scripts/patent-review/compliance-checker.py --patent-id P12
python scripts/patent-review/technical-analyzer.py --patent-id P12
```

### 批量审查
```bash
# 审查所有专利
python scripts/patent-review/batch-review.py --all

# 审查特定类别
python scripts/patent-review/batch-review.py --category core-technology
```

## 输出目录结构

```
docs/patents/reviews/
├── P01-fifo-money-age/
│   ├── compliance-check.json
│   ├── technical-analysis.json
│   ├── prior-art-search.json
│   ├── quality-score.json
│   ├── review-report.md
│   └── radar-chart.png
├── P02-multimodal-bookkeeping/
│   └── ...
└── summary/
    ├── all-patents-summary.md
    ├── high-risk-patents.md
    └── statistics.json
```

## 依赖安装

```bash
pip install -r scripts/patent-review/requirements.txt
```

## 注意事项

1. **AI判断声明**: 所有AI辅助判断都会明确标注为"AI意见",不作为最终法律结论
2. **数据来源**: 所有引用的法律条文、检索结果都提供可追溯的来源
3. **人工复核**: 建议对关键专利的AI判断进行人工复核
4. **专业咨询**: 高价值专利建议咨询专业代理人

## 开发状态

- [x] 工具目录创建
- [x] compliance-checker.py - 法律合规性检查
- [x] technical-analyzer.py - 技术性分析(AI辅助)
- [x] prior-art-searcher.py - 现有技术检索策略生成
- [x] quality-scorer.py - 质量评分(AI辅助)
- [x] report-generator.py - 综合报告生成
- [x] batch-review.py - 批量审查脚本
