# -*- coding: utf-8 -*-
"""
逐章核对代码块与设计内容一致性
检查每个章节的代码块是否实现了该章节描述的设计要求
"""
import re
from collections import defaultdict

# 每个章节的核心设计要求（从设计文档提取）
CHAPTER_DESIGN_REQUIREMENTS = {
    '1': {
        'title': '设计概述',
        'requirements': [
            ('目标达成检测框架', ['GoalChecker', 'ValidationResult', 'validate']),
            ('设计原则定义', ['Design', 'Principle', 'Criteria']),
        ]
    },
    '2': {
        'title': '产品定位与愿景',
        'requirements': [
            ('用户满意度追踪', ['Satisfaction', 'Score', 'Feedback']),
            ('用户价值指标', ['Value', 'Metrics', 'Efficiency']),
            ('懒人记账理念', ['Lazy', 'Auto', 'Smart', 'Default']),
        ]
    },
    '4': {
        'title': '伙伴化设计原则',
        'requirements': [
            ('情感化消息', ['Emotion', 'Message', 'Greeting']),
            ('动态问候', ['Dynamic', 'Greeting', 'Time']),
            ('鼓励性反馈', ['Encourage', 'Feedback', 'Positive']),
        ]
    },
    '5': {
        'title': '无障碍设计',
        'requirements': [
            ('色彩对比度', ['Color', 'Contrast', 'Accessible']),
            ('文字缩放', ['Text', 'Scale', 'Font']),
            ('触摸目标', ['Touch', 'Target', 'Size']),
            ('键盘导航', ['Keyboard', 'Navigation', 'Focus']),
            ('屏幕阅读器', ['Screen', 'Reader', 'Semantic']),
        ]
    },
    '6': {
        'title': '核心功能架构',
        'requirements': [
            ('模块集成', ['Module', 'Integration', 'Event']),
            ('交易事件', ['Transaction', 'Event', 'Created']),
            ('钱龄集成', ['MoneyAge', 'Integration']),
            ('预算集成', ['Budget', 'Integration']),
        ]
    },
    '7': {
        'title': '钱龄智能分析系统',
        'requirements': [
            ('资源池模型', ['ResourcePool', 'remaining', 'consume']),
            ('FIFO消费算法', ['FIFO', 'oldest', 'sort']),
            ('钱龄计算', ['MoneyAge', 'Calculator', 'age']),
            ('钱龄等级', ['MoneyAgeLevel', 'danger', 'warning', 'good']),
            ('钱龄统计', ['Statistics', 'average', 'trend']),
        ]
    },
    '8': {
        'title': '零基预算与小金库系统',
        'requirements': [
            ('小金库模型', ['Vault', 'Budget', 'allocation']),
            ('预算分配', ['allocat', 'distribute', 'assign']),
            ('零基预算', ['ZeroBased', 'zero']),
            ('预算追踪', ['track', 'spent', 'remaining']),
        ]
    },
    '9': {
        'title': '金融习惯培养系统',
        'requirements': [
            ('订阅追踪', ['Subscription', 'recurring', 'track']),
            ('拿铁因子', ['Latte', 'Factor', 'small']),
            ('冲动消费', ['Impulse', 'alert', 'warning']),
            ('应急金', ['Emergency', 'Fund', 'goal']),
            ('储蓄习惯', ['Saving', 'Habit', 'goal']),
        ]
    },
    '10': {
        'title': 'AI智能识别系统',
        'requirements': [
            ('语音识别', ['Voice', 'Speech', 'ASR']),
            ('图像识别', ['Image', 'OCR', 'Receipt']),
            ('自然语言理解', ['NLU', 'Intent', 'Entity']),
            ('多交易检测', ['Multi', 'Transaction', 'Detect']),
        ]
    },
    '11': {
        'title': '数据导入导出系统',
        'requirements': [
            ('账单解析', ['Bill', 'Parser', 'parse']),
            ('去重处理', ['Dedup', 'duplicate', 'hash']),
            ('批量导入', ['Batch', 'Import', 'bulk']),
            ('数据导出', ['Export', 'format']),
        ]
    },
    '12': {
        'title': '数据联动与可视化',
        'requirements': [
            ('数据可视化', ['Chart', 'Visualization', 'graph']),
            ('热力图', ['HeatMap', 'heat']),
            ('数据下钻', ['Drill', 'down', 'detail']),
            ('筛选过滤', ['Filter', 'criteria']),
            ('数据联动', ['Linkage', 'sync', 'update']),
        ]
    },
    '14': {
        'title': '地理位置智能化应用',
        'requirements': [
            ('位置服务', ['Location', 'GPS', 'coordinate']),
            ('地理围栏', ['Fence', 'Geo', 'boundary']),
            ('POI匹配', ['POI', 'Place', 'nearby']),
            ('位置预算', ['Localized', 'Budget', 'region']),
        ]
    },
    '15': {
        'title': '技术架构设计',
        'requirements': [
            ('分层架构', ['Layer', 'Architecture', 'Module']),
            ('状态管理', ['Notifier', 'State', 'Provider']),
            ('离线队列', ['Offline', 'Queue', 'sync']),
            ('基础设施', ['Infrastructure', 'Service']),
        ]
    },
    '16': {
        'title': '智能化技术方案',
        'requirements': [
            ('LLM集成', ['LLM', 'AI', 'model']),
            ('反馈收集', ['Feedback', 'collect']),
            ('模式分析', ['Pattern', 'Analysis']),
            ('增量学习', ['Incremental', 'Learning']),
            ('准确率监控', ['Accuracy', 'Monitor']),
        ]
    },
    '17': {
        'title': '自学习与协同学习系统',
        'requirements': [
            ('自学习', ['Self', 'Learning', 'learn']),
            ('协同学习', ['Collaborative', 'share']),
            ('冷启动', ['ColdStart', 'Accelerator']),
            ('反馈循环', ['Feedback', 'loop']),
        ]
    },
    '18': {
        'title': '智能语音交互系统',
        'requirements': [
            ('语音交互', ['Voice', 'Interaction', 'Speech']),
            ('意图识别', ['Intent', 'recognize', 'classify']),
            ('对话管理', ['Dialog', 'Confirm', 'context']),
            ('NLU引擎', ['NLU', 'Engine', 'parse']),
        ]
    },
    '19': {
        'title': '性能设计与优化',
        'requirements': [
            ('性能优化', ['Performance', 'Optimize', 'Cache']),
            ('虚拟列表', ['Virtualized', 'List', 'lazy']),
            ('批量处理', ['Batch', 'Processor']),
            ('降级策略', ['Degrade', 'Fallback']),
        ]
    },
    '20': {
        'title': '用户体验设计',
        'requirements': [
            ('微交互', ['Micro', 'Animation', 'Haptic']),
            ('骨架屏', ['Skeleton', 'Loading']),
            ('空状态', ['Empty', 'State']),
            ('错误处理UI', ['Error', 'Retry', 'UI']),
            ('引导流程', ['Onboarding', 'Coach', 'Guide']),
        ]
    },
    '21': {
        'title': '国际化与本地化',
        'requirements': [
            ('多语言支持', ['Locale', 'Language', 'i18n']),
            ('翻译服务', ['Translation', 'Translate']),
            ('货币格式', ['Currency', 'Format']),
        ]
    },
    '22': {
        'title': '安全与隐私',
        'requirements': [
            ('安全存储', ['Secure', 'Storage', 'Encrypt']),
            ('应用锁', ['Lock', 'Auth', 'Biometric']),
            ('数据备份', ['Backup', 'Restore']),
            ('隐私保护', ['Privacy', 'Retention']),
        ]
    },
    '23': {
        'title': '异常处理与容错设计',
        'requirements': [
            ('异常处理', ['Exception', 'Error', 'Handle']),
            ('重试机制', ['Retry', 'Backoff']),
            ('熔断器', ['CircuitBreaker', 'Fallback']),
            ('数据完整性', ['Integrity', 'Validate']),
        ]
    },
    '24': {
        'title': '可扩展性与演进架构',
        'requirements': [
            ('插件架构', ['Plugin', 'Extension', 'Module']),
            ('策略模式', ['Strategy', 'Pattern']),
            ('版本兼容', ['Version', 'Compatible', 'Migration']),
            ('API演进', ['API', 'Versioned', 'Adapter']),
        ]
    },
    '25': {
        'title': '可观测性与监控',
        'requirements': [
            ('日志系统', ['Log', 'Logger', 'Trace']),
            ('指标收集', ['Metrics', 'Monitor', 'Health']),
            ('错误追踪', ['Error', 'Tracking', 'Report']),
            ('告警系统', ['Alert', 'Notification']),
        ]
    },
    '26': {
        'title': '版本迁移策略',
        'requirements': [
            ('版本管理', ['Version', 'Metadata']),
            ('Schema迁移', ['Schema', 'Migration', 'Upgrade']),
            ('数据迁移', ['Data', 'Migration', 'Transform']),
            ('兼容适配', ['Compatible', 'Adapter']),
            ('特性开关', ['Feature', 'Flag']),
        ]
    },
    '27': {
        'title': '实施路线图',
        'requirements': [
            ('里程碑定义', ['Milestone', 'Alpha', 'Beta', 'Release']),
            ('验收标准', ['Acceptance', 'Criteria']),
            ('目标验证', ['Goal', 'Validator', 'Check']),
        ]
    },
    '28': {
        'title': '用户口碑与NPS提升设计',
        'requirements': [
            ('NPS追踪', ['NPS', 'Score', 'Satisfaction']),
            ('推荐激励', ['Referral', 'Reward']),
            ('负面体验恢复', ['Negative', 'Recovery']),
            ('峰值体验', ['Peak', 'Delight']),
        ]
    },
    '29': {
        'title': '低成本获客与自然增长设计',
        'requirements': [
            ('分享功能', ['Share', 'Asset', 'Social']),
            ('应用评分', ['Rating', 'Review']),
            ('增长策略', ['Growth', 'Viral']),
            ('ASO优化', ['ASO', 'Optimization']),
        ]
    },
}


def extract_chapter_code_blocks(content):
    """提取每个章节的代码块"""
    lines = content.split('\n')
    chapter_blocks = defaultdict(list)

    current_chapter = None
    current_chapter_title = None

    i = 0
    while i < len(lines):
        line = lines[i]

        # 匹配章节
        chapter_match = re.match(r'^## 第(\d+)章 (.+)$', line)
        if chapter_match:
            current_chapter = chapter_match.group(1)
            current_chapter_title = chapter_match.group(2)

        # 匹配代码块开始
        code_match = re.match(r'^```(dart|python|sql)$', line)
        if code_match and current_chapter:
            lang = code_match.group(1)
            start_line = i

            # 提取代码内容
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                code_lines.append(lines[i])
                i += 1

            code_text = '\n'.join(code_lines)
            chapter_blocks[current_chapter].append({
                'lang': lang,
                'code': code_text,
                'line': start_line + 1,
                'length': len(code_lines)
            })

        i += 1

    return chapter_blocks


def check_chapter_requirements(chapter, blocks, requirements):
    """检查章节代码块是否满足设计要求"""
    results = []
    all_code = '\n'.join([b['code'] for b in blocks])

    for req_name, keywords in requirements:
        found_keywords = []
        missing_keywords = []

        for keyword in keywords:
            if keyword.lower() in all_code.lower():
                found_keywords.append(keyword)
            else:
                missing_keywords.append(keyword)

        # 至少找到一半的关键词才算满足
        coverage = len(found_keywords) / len(keywords) if keywords else 0
        passed = coverage >= 0.5

        results.append({
            'requirement': req_name,
            'passed': passed,
            'coverage': coverage,
            'found': found_keywords,
            'missing': missing_keywords
        })

    return results


def generate_detailed_report(chapter_blocks, design_requirements):
    """生成详细的逐章核对报告"""
    report = []
    report.append('=' * 80)
    report.append('AI智能记账2.0 逐章代码块核对报告')
    report.append('=' * 80)
    report.append('')

    total_passed = 0
    total_requirements = 0
    chapter_results = {}

    for chapter, config in sorted(design_requirements.items(), key=lambda x: int(x[0])):
        title = config['title']
        requirements = config['requirements']
        blocks = chapter_blocks.get(chapter, [])

        if not blocks:
            report.append(f'\n第{chapter}章 {title}: ⚠ 无代码块')
            continue

        results = check_chapter_requirements(chapter, blocks, requirements)
        chapter_passed = sum(1 for r in results if r['passed'])
        chapter_total = len(results)

        total_passed += chapter_passed
        total_requirements += chapter_total

        pass_rate = (chapter_passed / chapter_total * 100) if chapter_total else 0
        status = '✓' if pass_rate >= 80 else ('⚠' if pass_rate >= 50 else '✗')

        chapter_results[chapter] = {
            'title': title,
            'blocks': len(blocks),
            'passed': chapter_passed,
            'total': chapter_total,
            'rate': pass_rate,
            'results': results
        }

        report.append(f'\n{status} 第{chapter}章 {title}')
        report.append(f'   代码块数: {len(blocks)}, 设计要求满足率: {chapter_passed}/{chapter_total} ({pass_rate:.0f}%)')

        for r in results:
            req_status = '✓' if r['passed'] else '✗'
            report.append(f'   {req_status} {r["requirement"]} (覆盖{r["coverage"]*100:.0f}%)')
            if not r['passed'] and r['missing']:
                report.append(f'      缺失关键词: {", ".join(r["missing"])}')

    # 总结
    report.append('\n' + '=' * 80)
    report.append('总结')
    report.append('=' * 80)

    overall_rate = (total_passed / total_requirements * 100) if total_requirements else 0
    report.append(f'设计要求总数: {total_requirements}')
    report.append(f'满足要求数: {total_passed}')
    report.append(f'总体满足率: {overall_rate:.1f}%')

    # 列出需要关注的章节
    report.append('\n需要关注的章节:')
    for chapter, data in sorted(chapter_results.items(), key=lambda x: x[1]['rate']):
        if data['rate'] < 80:
            report.append(f'  第{chapter}章 {data["title"]}: {data["rate"]:.0f}% ({data["passed"]}/{data["total"]})')

    return '\n'.join(report), chapter_results


def main():
    # 读取代码设计文档
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_code_design.md', 'r', encoding='utf-8') as f:
        code_doc = f.read()

    print('正在提取代码块...')
    chapter_blocks = extract_chapter_code_blocks(code_doc)
    print(f'提取完成，共{sum(len(b) for b in chapter_blocks.values())}个代码块，覆盖{len(chapter_blocks)}个章节')

    print('正在逐章核对设计要求...')
    report, results = generate_detailed_report(chapter_blocks, CHAPTER_DESIGN_REQUIREMENTS)

    print('\n' + report)

    # 保存报告
    with open('D:/code/ai-bookkeeping/temp/chapter_audit_report.txt', 'w', encoding='utf-8') as f:
        f.write(report)

    print(f'\n报告已保存到: D:/code/ai-bookkeeping/temp/chapter_audit_report.txt')


if __name__ == '__main__':
    main()
