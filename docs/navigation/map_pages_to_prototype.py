#!/usr/bin/env python3
"""
将代码中的页面与原型文档进行映射，生成人类可读的对照表
"""

import os
import re
from pathlib import Path

def extract_prototype_pages(prototype_file):
    """从原型文档中提取页面名称"""
    pages = {}

    with open(prototype_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取表格中的页面
    pattern = r'\|\s*(\d+\.\d+)\s*\|\s*([^|]+)\s*\|'
    matches = re.findall(pattern, content)

    for code, name in matches:
        name = name.strip()
        pages[code] = name

    return pages

def file_name_to_class_name(file_name):
    """将文件名转换为类名"""
    parts = file_name.replace('_page', '').split('_')
    return ''.join(word.capitalize() for word in parts) + 'Page'

def find_dart_pages(pages_dir):
    """查找所有页面文件（包括子目录）"""
    pages = []
    for file in Path(pages_dir).rglob('*.dart'):
        if file.stem != 'main_navigation':
            class_name = file_name_to_class_name(file.stem)
            pages.append({
                'file': str(file.relative_to(pages_dir)),
                'class': class_name
            })
    return sorted(pages, key=lambda x: x['class'])

def load_navigation_data(analysis_file):
    """加载导航分析数据"""
    unreferenced = set()

    with open(analysis_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 提取未被引用的页面
    in_unreferenced = False
    for line in content.split('\n'):
        if '## 完全未被引用的页面' in line:
            in_unreferenced = True
            continue
        if in_unreferenced and line.startswith('##'):
            break
        if in_unreferenced and line.strip().startswith('-'):
            # 格式: - AaSplitPage - `app/lib/pages/aa_split_page.dart`
            parts = line.strip().lstrip('- ').split(' - ')
            if parts:
                page = parts[0].strip()
                unreferenced.add(page)

    return unreferenced

def fuzzy_match_prototype(class_name, prototype_pages):
    """模糊匹配原型页面"""
    # 移除Page后缀
    name = class_name.replace('Page', '')

    # 匹配规则
    mappings = {
        'Home': '1.01',
        'Trends': '1.02',
        'AddTransaction': '1.03',
        'BudgetCenter': '1.04',
        'Profile': '1.05',
        'MoneyAgeDetail': '2.01',
        'MoneyAgeUpgrade': '2.02',
        'MoneyAgeTrend': '2.03',
        'MoneyAgeInfluence': '2.04',
        'MoneyAgeStage': '2.05',
        'TransactionMoneyAge': '2.06',
        'FifoResourcePool': '2.07',
        'MoneyAgeBudgetLink': '2.08',
        'VaultOverview': '3.01',
        'VaultDetail': '3.02',
        'VaultAllocation': '3.03',
        'VaultCreate': '3.04',
        'VaultAiSuggestion': '3.05',
        'VaultHealth': '3.06',
        'VaultMoneyAgeLink': '3.07',
        'VaultSpendingBlock': '3.08',
        'VaultZeroBased': '3.09',
        'AccountList': '4.01',
        'TransactionList': '4.02',
        'TransactionDetail': '4.03',
        'ManualTransactionDetail': '4.04',
        'DebtManagement': '4.05',
        'ImportBill': '5.01',
        'DuplicateDetection': '5.02',
        'TransactionComparison': '5.03',
        'ExportBill': '5.04',
        'PdfExportPreview': '5.05',
        'BankBillImport': '5.06',
        'BatchEdit': '5.07',
        'ImportHistory': '5.08',
        'SmartFormatDetection': '5.09',
        'FieldMapping': '5.10',
        'ThreeLayerDuplicateDetail': '5.11',
        'ImportPreview': '5.12',
        'ImportProgress': '5.13',
        'ExportAdvancedConfig': '5.14',
        'ImportSuccess': '5.15',
        'VoicePrepare': '6.01',
        'VoiceRecording': '6.02',
        'VoiceResult': '6.03',
        'MultiTransactionRecognition': '6.04',
        'ImageRecognition': '6.05',
        'DialogHistory': '6.06',
        'ReceiptItemDetail': '6.07',
        'PaymentScreenshotRecognition': '6.08',
        'AaSplitConfirmation': '6.09',
        'LowConfidenceConfirmation': '6.10',
        'OfflineModePrompt': '6.11',
        'ContinuousDialogBookkeeping': '6.12',
        'MonthlyReport': '7.01',
        'InsightAnalysis': '7.02',
        'AnnualSummary': '7.03',
        'BudgetReport': '7.04',
        'CategoryPieChartDrilldown': '7.05',
        'TrendChartDrilldown': '7.06',
        'ConsumptionHeatmap': '7.07',
        'DrilldownNavigation': '7.08',
        'DataFilter': '7.09',
        'ChartShare': '7.10',
        'Settings': '8.01',
        'ThemeSettings': '8.02',
        'LanguageSettings': '8.03',
        'CurrencySettings': '8.04',
        'RegionSettings': '8.05',
        'AiLanguageSettings': '8.06',
        'NotificationSettings': '8.07',
        'DataSync': '8.08',
        'CategoryManagement': '8.09',
        'AccountManagement': '8.10',
        'MembershipService': '8.11',
        'AboutApp': '8.12',
        'SecuritySettings': '8.13',
        'LocationServiceSettings': '8.14',
        'ResidentLocationSettings': '8.15',
        'GeofenceManagement': '8.16',
        'LocationAnalysisReport': '8.17',
        'RemoteConsumptionRecord': '8.18',
        'LocationSavingsSuggestion': '8.19',
        'AppLockSettings': '8.20',
        'PinCodeSettings': '8.21',
        'PrivacyModeSettings': '8.22',
        'BackupManagement': '8.23',
        'SecurityAuditLog': '8.24',
        'DataManagement': '8.25',
        'CategoryDetail': '9.01',
        'SearchResult': '9.02',
        'AdvancedFilter': '9.03',
        'TimeComparison': '9.04',
        'TagFilter': '9.05',
        'FinancialHealthDashboard': '10.01',
        'SubscriptionWasteIdentification': '10.02',
        'LatteFactorAnalysis': '10.03',
        'ImpulseConsumptionConfirmation': '10.04',
        'EmergencyFundGoal': '10.05',
        'MoneyAgeAdvancement': '10.06',
        'ContinuousCheckIn': '10.07',
        'NetworkError': '11.01',
        'SyncConflictResolution': '11.02',
        'DataIntegrityCheck': '11.03',
        'OfflineOperationQueue': '11.04',
        'ErrorDialog': '11.05',
        'RetryStatusPrompt': '11.06',
        'AppHealthStatus': '12.01',
        'PerformanceMonitoring': '12.02',
        'SystemLog': '12.03',
        'AlertHistory': '12.04',
        'AiServiceMonitoring': '12.05',
        'DiagnosticReport': '12.06',
        'BillReminderList': '13.01',
        'AddRecurringBill': '13.02',
        'CreditCardPaymentReminder': '13.03',
        'DueNotificationDetail': '13.04',
        'SmartBillSuggestion': '13.05',
        'BillCalendarView': '13.06',
        'SmartCategoryCenter': '14.01',
        'CategoryFeedbackLearning': '14.02',
        'ConsumptionTrendPrediction': '14.03',
        'AnomalyDetectionSettings': '14.04',
        'AnomalyTransactionDetail': '14.05',
        'NaturalLanguageSearch': '14.06',
        'DialogAssistantSettings': '14.07',
        'VoiceConfigCenter': '14.08',
        'AiCostMonitor': '14.09',
        'AiLearningReport': '14.10',
        'LedgerList': '15.01',
        'CreateLedger': '15.02',
        'MemberManagement': '15.03',
        'InviteMember': '15.04',
        'PermissionSettings': '15.05',
        'FamilyBudget': '15.06',
        'FamilyStatistics': '15.07',
        'LedgerSettings': '15.08',
        'NpsSurveyDialog': '16.01',
        'DelightfulMomentCelebration': '16.02',
        'ShareCardGeneration': '16.03',
        'InviteFriend': '16.04',
        'AchievementShare': '16.05',
        'FeedbackCollection': '16.06',
        'AnnualReportShare': '16.07',
        'SocialViralActivity': '16.08',
    }

    code = mappings.get(name)
    if code and code in prototype_pages:
        return code, prototype_pages[code]

    return None, None

def generate_report(pages, prototype_pages, unreferenced):
    """生成映射报告"""
    report = []
    report.append("# 页面映射报告\n\n")
    report.append(f"**代码页面总数**: {len(pages)}\n")
    report.append(f"**原型页面总数**: {len(prototype_pages)}\n")
    report.append(f"**未被引用页面数**: {len(unreferenced)}\n\n")

    # 统计
    matched = 0
    unmatched = 0
    unreferenced_count = 0
    needs_entry = []
    should_delete = []

    # 临时存储表格行
    table_rows = []

    for page in pages:
        class_name = page['class']
        file_name = page['file']
        is_referenced = class_name not in unreferenced

        code, cn_name = fuzzy_match_prototype(class_name, prototype_pages)

        if code:
            matched += 1
            status = "✅" if is_referenced else "⚠️"
            suggestion = "正常" if is_referenced else "需添加入口"
            if not is_referenced:
                needs_entry.append((file_name, class_name, code, cn_name))
            table_rows.append(f"| {file_name} | {class_name} | {code} | {cn_name} | {status} | {suggestion} |\n")
        else:
            unmatched += 1
            if is_referenced:
                table_rows.append(f"| {file_name} | {class_name} | - | 未匹配 | ✅ | 检查是否需要 |\n")
            else:
                unreferenced_count += 1
                should_delete.append((file_name, class_name))
                table_rows.append(f"| {file_name} | {class_name} | - | 未匹配 | ❌ | **可能需要删除** |\n")

    # 添加统计
    report.append(f"**已匹配页面**: {matched} (代码实现了原型设计的页面)\n")
    report.append(f"**未匹配页面**: {unmatched} (代码中有但原型中没有的页面)\n")
    report.append(f"**未被引用且未匹配**: {unreferenced_count} (强烈建议删除)\n\n")

    # 添加关键发现
    report.append("## 关键发现\n\n")

    if should_delete:
        report.append(f"### ❌ 建议删除的页面 ({len(should_delete)}个)\n\n")
        report.append("这些页面既没有在原型中定义，也没有被任何其他页面引用，可能是死代码：\n\n")
        for file_name, class_name in should_delete:
            report.append(f"- `{file_name}` ({class_name})\n")
        report.append("\n")

    if needs_entry:
        report.append(f"### ⚠️ 需要添加入口的页面 ({len(needs_entry)}个)\n\n")
        report.append("这些页面在原型中有定义，但没有被任何页面引用，需要添加导航入口：\n\n")
        for file_name, class_name, code, cn_name in needs_entry:
            report.append(f"- `{file_name}` ({class_name}) - {code} {cn_name}\n")
        report.append("\n")

    # 添加表格
    report.append("## 完整页面对照表\n\n")
    report.append("| 文件名 | 类名 | 原型编号 | 中文名称 | 是否被引用 | 建议 |\n")
    report.append("|--------|------|----------|----------|------------|------|\n")
    report.extend(table_rows)

    return ''.join(report)

def main():
    base_dir = Path(__file__).parent.parent
    pages_dir = base_dir / 'app' / 'lib' / 'pages'
    prototype_file = base_dir / 'docs' / 'prototype' / 'PAGE_INDEX.md'
    analysis_file = base_dir / 'docs' / 'navigation_analysis_final.md'
    output_file = base_dir / 'docs' / 'page_mapping_report.md'

    # 提取原型页面
    prototype_pages = extract_prototype_pages(prototype_file)

    # 查找代码页面
    code_pages = find_dart_pages(pages_dir)

    # 加载导航数据
    unreferenced = load_navigation_data(analysis_file)

    # 生成报告
    report = generate_report(code_pages, prototype_pages, unreferenced)

    # 保存报告
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"✅ 映射报告已生成: {output_file}")
    print(f"   代码页面: {len(code_pages)}")
    print(f"   原型页面: {len(prototype_pages)}")
    print(f"   未被引用: {len(unreferenced)}")

if __name__ == '__main__':
    main()
