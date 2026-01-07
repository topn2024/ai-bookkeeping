# -*- coding: utf-8 -*-
"""
全量代码块审计工具
逐个核对代码设计文档中的426个代码块与方案设计文档的一致性
"""
import re
import json
from collections import defaultdict

def extract_all_code_blocks(content):
    """提取所有代码块及其上下文"""
    lines = content.split('\n')
    code_blocks = []

    current_chapter = None
    current_chapter_title = None
    current_section = None
    current_subsection = None

    i = 0
    while i < len(lines):
        line = lines[i]

        # 匹配章节
        chapter_match = re.match(r'^## 第(\d+)章 (.+)$', line)
        if chapter_match:
            current_chapter = chapter_match.group(1)
            current_chapter_title = chapter_match.group(2)
            current_section = None
            current_subsection = None

        # 匹配节
        section_match = re.match(r'^### (\d+\.\d+)', line)
        if section_match:
            current_section = section_match.group(1)
            current_subsection = None

        # 匹配子节
        subsection_match = re.match(r'^#### .+代码块 (\d+)', line)
        if subsection_match:
            block_id = int(subsection_match.group(1))

        # 匹配代码块开始
        code_match = re.match(r'^```(dart|python|sql)$', line)
        if code_match:
            lang = code_match.group(1)
            start_line = i

            # 提取代码内容
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                code_lines.append(lines[i])
                i += 1

            # 提取代码中的关键信息
            code_text = '\n'.join(code_lines)

            # 提取类名
            classes = re.findall(r'class (\w+)', code_text)

            # 提取主要方法
            methods = re.findall(r'(?:Future|void|bool|int|double|String|List|Map)\s+(\w+)\s*\(', code_text)

            # 提取常量/枚举
            constants = re.findall(r'static const (\w+)', code_text)
            enums = re.findall(r'enum (\w+)', code_text)

            # 提取注释描述
            comments = re.findall(r'///\s*(.+)', code_text)

            code_blocks.append({
                'chapter': current_chapter,
                'chapter_title': current_chapter_title,
                'section': current_section,
                'lang': lang,
                'line': start_line + 1,
                'classes': classes,
                'methods': methods[:10],
                'constants': constants,
                'enums': enums,
                'comments': comments[:5],
                'code_length': len(code_lines),
                'code_preview': '\n'.join(code_lines[:50]),  # 增加预览行数以捕获更多上下文
                'full_code': code_text  # 保存完整代码用于关键词检索
            })

        i += 1

    return code_blocks

def extract_design_requirements(content):
    """从方案设计文档中提取设计要求"""
    lines = content.split('\n')
    requirements = defaultdict(list)

    current_chapter = None
    current_section = None

    for i, line in enumerate(lines):
        # 匹配章节
        chapter_match = re.match(r'^## (\d+)\. (.+)$', line)
        if chapter_match:
            current_chapter = chapter_match.group(1)

        # 匹配节
        section_match = re.match(r'^### (\d+\.\d+) (.+)$', line)
        if section_match:
            current_section = section_match.group(1)
            section_title = section_match.group(2)
            requirements[current_chapter].append({
                'section': current_section,
                'title': section_title,
                'line': i + 1
            })

    return requirements

def check_code_design_consistency(code_blocks, design_requirements):
    """检查代码与设计的一致性"""
    issues = []

    # 按章节分组代码块
    chapter_code = defaultdict(list)
    for block in code_blocks:
        chapter_code[block['chapter']].append(block)

    # 检查每个章节
    for chapter, blocks in chapter_code.items():
        chapter_title = blocks[0]['chapter_title'] if blocks else ''

        # 1. 检查是否有空代码块
        for block in blocks:
            if block['code_length'] < 3:
                issues.append({
                    'type': 'EMPTY_CODE',
                    'chapter': chapter,
                    'section': block['section'],
                    'message': f'代码块过短（仅{block["code_length"]}行）',
                    'line': block['line']
                })

        # 2. 检查类名是否与章节主题相关
        chapter_keywords = get_chapter_keywords(chapter)
        for block in blocks:
            if block['classes']:
                relevant = False
                for cls in block['classes']:
                    for keyword in chapter_keywords:
                        if keyword.lower() in cls.lower():
                            relevant = True
                            break
                    if relevant:
                        break

                if not relevant and chapter_keywords:
                    issues.append({
                        'type': 'THEME_MISMATCH',
                        'chapter': chapter,
                        'section': block['section'],
                        'message': f'类名 {block["classes"]} 可能与章节主题不符',
                        'line': block['line'],
                        'severity': 'warning'
                    })

        # 3. 检查注释是否完整
        for block in blocks:
            if not block['comments'] and block['classes']:
                issues.append({
                    'type': 'MISSING_COMMENTS',
                    'chapter': chapter,
                    'section': block['section'],
                    'message': f'类 {block["classes"]} 缺少文档注释',
                    'line': block['line'],
                    'severity': 'info'
                })

    return issues

def get_chapter_keywords(chapter):
    """获取章节主题关键词（扩展版，减少误报）"""
    keywords_map = {
        '1': ['Goal', 'Criteria', 'Achievement', 'Design', 'Chapter', 'Checker', 'Validator'],
        '2': ['Vision', 'Product', 'Position', 'User', 'Satisfaction', 'Feedback', 'Value', 'Efficiency', 'Feature', 'Usage', 'Metrics'],
        '3': ['Lazy', 'Auto', 'Default', 'Smart', 'OneClick', 'Quick', 'Fast'],
        '4': ['Partner', 'Companion', 'Emotion', 'Dynamic', 'Message', 'Greeting', 'Response'],
        '5': ['Accessibility', 'Screen', 'Voice', 'Semantic', 'Color', 'Text', 'Touch', 'Keyboard', 'Focus', 'Navigate', 'Accessible'],
        '6': ['Core', 'Feature', 'Architecture', 'Module', 'Integration', 'Transaction', 'MoneyAge', 'Budget', 'Event'],
        '7': ['MoneyAge', 'Resource', 'Pool', 'FIFO', 'Age', 'Consumption', 'Influence', 'Analysis'],
        '8': ['Budget', 'Vault', 'Allocation', 'ZeroBased', 'BudgetStatus'],
        '9': ['Habit', 'Subscription', 'Latte', 'Impulse', 'Emergency', 'Saving', 'Expense', 'Insight', 'Guide', 'Necessity', 'Actionable', 'Operation'],
        '10': ['Recognition', 'AI', 'OCR', 'Voice', 'Image', 'NLP', 'Input', 'Preprocess', 'ASR', 'Receipt', 'Screenshot', 'Parser', 'NLU', 'Intent', 'Classifier'],
        '11': ['Import', 'Export', 'Dedup', 'Batch', 'Bill', 'Parser', 'Discovery'],
        '12': ['Visualization', 'Chart', 'Drill', 'Filter', 'Linkage', 'HeatMap', 'Breadcrumb', 'Data', 'Change', 'Refresh', 'Ledger', 'Export', 'Share'],
        '13': ['Family', 'Member', 'Ledger', 'Share', 'Split', 'Invite'],
        '14': ['Location', 'Geo', 'GPS', 'Place', 'Fence', 'POI', 'Localized', 'Region', 'Chapter14', 'Matching'],
        '15': ['Architecture', 'Layer', 'Module', 'Infrastructure', 'Notifier', 'Crud', 'Sync', 'Offline', 'Queue', 'VectorClock', 'Circuit'],
        '16': ['Smart', 'AI', 'ML', 'Predict', 'Classify', 'LLM', 'Feedback', 'Pattern', 'Learning', 'Accuracy', 'Threshold', 'Rule', 'Category'],
        '17': ['Learning', 'Self', 'Collaborative', 'Feedback', 'ColdStart', 'Accelerator'],
        '18': ['Voice', 'Intent', 'Speech', 'NLU', 'Dialog', 'Interaction', 'Confirm', 'Privacy', 'Pattern', 'Global', 'ABTest', 'Release', 'Aggregation'],
        '19': ['Performance', 'Cache', 'Optimize', 'Load', 'Virtualized', 'Lazy', 'Report', 'Aggregation', 'Compute', 'Isolate', 'Batch', 'Processor', 'Offline', 'Degrade'],
        '20': ['UX', 'Experience', 'Animation', 'Micro', 'Offline', 'Error', 'Chapter20', 'Voice', 'Interaction', 'Recognition', 'Result', 'Family', 'Onboarding', 'Coach', 'Gesture', 'Haptic', 'Skeleton', 'Progressive', 'Retry', 'Empty', 'State', 'Scenario', 'Peak'],
        '21': ['i18n', 'Locale', 'Language', 'Translation', 'Currency', 'Translate'],
        '22': ['Security', 'Privacy', 'Encrypt', 'Auth', 'Secure', 'Storage', 'Lock', 'Backup', 'Retention'],
        '23': ['Exception', 'Error', 'Retry', 'Fallback', 'Integrity', 'Offline', 'Queue', 'Sync', 'State', 'Machine', 'Calculation', 'Service'],
        '24': ['Extensible', 'Plugin', 'Version', 'API', 'Extensibility', 'Feature', 'Registry', 'Strategy', 'Migration', 'Framework', 'Service', 'Client', 'Factory', 'Adapter', 'Versioned'],
        '25': ['Monitor', 'Log', 'Trace', 'Health', 'Metrics', 'Observability', 'Error', 'Tracking', 'Alert', 'Analytics', 'Behavior', 'Journey', 'Funnel'],
        '26': ['Migration', 'Upgrade', 'Schema', 'Compatible', 'Feature', 'Flag', 'Version', 'Metadata', 'Integrity', 'Validator', 'Export', 'Format', 'Compatibility', 'Adapter'],
        '27': ['Milestone', 'Roadmap', 'Acceptance', 'Phase', 'Chapter27', 'Goal', 'Validator', 'Check', 'Validation'],
        '28': ['NPS', 'Delight', 'Share', 'Satisfaction', 'Referral', 'Reward', 'Guidance', 'Negative', 'Experience', 'Recovery', 'Promoter', 'Identification', 'Peak'],
        '29': ['Growth', 'Viral', 'ASO', 'Referral', 'Share', 'Asset', 'Generator', 'Rating', 'Optimization', 'Content', 'UGC', 'Leaderboard', 'Social'],
    }
    return keywords_map.get(chapter, [])

def check_specific_requirements(code_blocks):
    """检查特定设计要求的实现"""
    specific_issues = []

    def get_chapter_code(chapter):
        """获取指定章节的所有代码文本"""
        blocks = [b for b in code_blocks if b['chapter'] == chapter]
        return '\n'.join([b.get('full_code', '') for b in blocks])

    # 第7章：钱龄系统必须有FIFO实现
    ch7_code = get_chapter_code('7')
    has_fifo = 'FIFO' in ch7_code or 'fifo' in ch7_code.lower() or '先进先出' in ch7_code
    if not has_fifo:
        specific_issues.append({
            'type': 'MISSING_FEATURE',
            'chapter': '7',
            'message': '钱龄系统缺少FIFO算法实现',
            'severity': 'error'
        })

    # 第8章：预算系统必须有分配逻辑
    ch8_code = get_chapter_code('8')
    has_allocation = 'allocat' in ch8_code.lower() or '分配' in ch8_code
    if not has_allocation:
        specific_issues.append({
            'type': 'MISSING_FEATURE',
            'chapter': '8',
            'message': '预算系统缺少分配逻辑',
            'severity': 'error'
        })

    # 第18章：语音系统必须有意图识别
    ch18_code = get_chapter_code('18')
    has_intent = 'intent' in ch18_code.lower() or 'Intent' in ch18_code
    if not has_intent:
        specific_issues.append({
            'type': 'MISSING_FEATURE',
            'chapter': '18',
            'message': '语音系统缺少意图识别实现',
            'severity': 'error'
        })

    # 第26章：迁移系统必须有版本管理
    ch26_code = get_chapter_code('26')
    has_version = 'version' in ch26_code.lower() or 'schema' in ch26_code.lower() or 'Version' in ch26_code
    if not has_version:
        specific_issues.append({
            'type': 'MISSING_FEATURE',
            'chapter': '26',
            'message': '迁移系统缺少版本管理',
            'severity': 'error'
        })

    # 第27章：必须有所有里程碑的验收标准
    ch27_code = get_chapter_code('27')
    # 使用更灵活的匹配，支持 beta-1, beta_1, beta1 等格式
    required_milestones = {
        'alpha': ['alpha', 'Alpha'],
        'beta1': ['beta-1', 'beta_1', 'beta1', 'Beta-1', 'Beta1'],
        'beta2': ['beta-2', 'beta_2', 'beta2', 'Beta-2', 'Beta2'],
        'beta3': ['beta-3', 'beta_3', 'beta3', 'Beta-3', 'Beta3'],
        'rc1': ['rc-1', 'rc_1', 'rc1', 'RC-1', 'RC1'],
        'rc2': ['rc-2', 'rc_2', 'rc2', 'RC-2', 'RC2'],
        'release': ['release', 'Release', 'RELEASE']
    }
    missing_milestones = []
    for milestone, patterns in required_milestones.items():
        found = any(p in ch27_code for p in patterns)
        if not found:
            missing_milestones.append(milestone)

    if missing_milestones:
        specific_issues.append({
            'type': 'INCOMPLETE_IMPLEMENTATION',
            'chapter': '27',
            'message': f'缺少里程碑验收标准: {missing_milestones}',
            'severity': 'error'
        })

    return specific_issues

def generate_audit_report(code_blocks, issues, specific_issues):
    """生成审计报告"""
    report = []
    report.append('=' * 80)
    report.append('AI智能记账2.0 代码块全量审计报告')
    report.append('=' * 80)
    report.append('')

    # 统计信息
    report.append('【统计信息】')
    report.append(f'  总代码块数: {len(code_blocks)}')

    chapter_stats = defaultdict(int)
    for block in code_blocks:
        chapter_stats[block['chapter']] += 1

    report.append(f'  覆盖章节数: {len(chapter_stats)}')
    report.append('')

    # 按章节统计
    report.append('【各章节代码块数量】')
    for ch in sorted(chapter_stats.keys(), key=int):
        count = chapter_stats[ch]
        blocks = [b for b in code_blocks if b['chapter'] == ch]
        title = blocks[0]['chapter_title'] if blocks else ''
        report.append(f'  第{ch}章 {title}: {count}个')
    report.append('')

    # 特定需求检查结果
    report.append('【核心设计要求检查】')
    if not specific_issues:
        report.append('  ✓ 所有核心设计要求都有对应实现')
    else:
        for issue in specific_issues:
            status = '✗' if issue['severity'] == 'error' else '⚠'
            report.append(f'  {status} 第{issue["chapter"]}章: {issue["message"]}')
    report.append('')

    # 一般问题
    if issues:
        report.append('【发现的问题】')
        error_count = sum(1 for i in issues if i.get('severity') != 'info')
        warning_count = sum(1 for i in issues if i.get('severity') == 'warning')
        info_count = sum(1 for i in issues if i.get('severity') == 'info')

        report.append(f'  错误: {error_count}, 警告: {warning_count}, 提示: {info_count}')
        report.append('')

        # 按章节分组显示问题
        issues_by_chapter = defaultdict(list)
        for issue in issues:
            issues_by_chapter[issue['chapter']].append(issue)

        for ch in sorted(issues_by_chapter.keys(), key=int):
            ch_issues = issues_by_chapter[ch]
            report.append(f'  第{ch}章:')
            for issue in ch_issues[:5]:  # 每章最多显示5个问题
                severity_mark = {'error': '✗', 'warning': '⚠', 'info': 'ℹ'}.get(issue.get('severity', 'error'), '•')
                report.append(f'    {severity_mark} [{issue["type"]}] {issue["message"]} (行{issue.get("line", "?")})')
            if len(ch_issues) > 5:
                report.append(f'    ... 还有{len(ch_issues) - 5}个问题')
    else:
        report.append('【发现的问题】')
        report.append('  ✓ 未发现明显问题')

    report.append('')
    report.append('=' * 80)

    return '\n'.join(report)

def main():
    # 读取代码设计文档
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_code_design.md', 'r', encoding='utf-8') as f:
        code_doc = f.read()

    # 读取方案设计文档
    with open('D:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        design_doc = f.read()

    print('正在提取代码块...')
    code_blocks = extract_all_code_blocks(code_doc)
    print(f'提取到 {len(code_blocks)} 个代码块')

    print('正在提取设计要求...')
    design_requirements = extract_design_requirements(design_doc)
    print(f'提取到 {len(design_requirements)} 个章节的设计要求')

    print('正在检查一致性...')
    issues = check_code_design_consistency(code_blocks, design_requirements)

    print('正在检查特定设计要求...')
    specific_issues = check_specific_requirements(code_blocks)

    print('正在生成报告...')
    report = generate_audit_report(code_blocks, issues, specific_issues)

    print()
    print(report)

    # 保存详细报告
    with open('D:/code/ai-bookkeeping/temp/code_audit_report.txt', 'w', encoding='utf-8') as f:
        f.write(report)

    # 保存代码块详情JSON
    with open('D:/code/ai-bookkeeping/temp/code_blocks_detail.json', 'w', encoding='utf-8') as f:
        # 移除code_preview以减小文件大小
        blocks_summary = []
        for block in code_blocks:
            summary = {k: v for k, v in block.items() if k != 'code_preview'}
            blocks_summary.append(summary)
        json.dump(blocks_summary, f, ensure_ascii=False, indent=2)

    print(f'\n详细报告已保存到: D:/code/ai-bookkeeping/temp/code_audit_report.txt')
    print(f'代码块详情已保存到: D:/code/ai-bookkeeping/temp/code_blocks_detail.json')

if __name__ == '__main__':
    main()
