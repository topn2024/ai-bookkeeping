# -*- coding: utf-8 -*-
"""
更新页面路由映射表，添加AI智能中心和新增页面的路由
"""

# 在"用户相关"之前插入新的路由
NEW_ROUTES = '''
    // ========== 2.0新增 - 钱龄分析（8个） ==========
    '钱龄': NavigationTarget(route: '/money-age', displayName: '钱龄详情'),
    '钱龄详情': NavigationTarget(route: '/money-age', displayName: '钱龄详情'),
    '资金年龄': NavigationTarget(route: '/money-age', displayName: '钱龄详情'),
    '钱龄趋势': NavigationTarget(route: '/money-age/trend', displayName: '钱龄趋势'),
    '钱龄历史': NavigationTarget(route: '/money-age/trend', displayName: '钱龄趋势'),
    'FIFO资源池': NavigationTarget(route: '/money-age/fifo', displayName: 'FIFO资源池'),
    '资金池': NavigationTarget(route: '/money-age/fifo', displayName: 'FIFO资源池'),

    // ========== 2.0新增 - 小金库（9个） ==========
    '小金库': NavigationTarget(route: '/vault', displayName: '小金库概览'),
    '小金库概览': NavigationTarget(route: '/vault', displayName: '小金库概览'),
    '小金库详情': NavigationTarget(route: '/vault/detail', displayName: '小金库详情'),
    '资金分配': NavigationTarget(route: '/vault/allocate', displayName: '资金分配'),
    '创建小金库': NavigationTarget(route: '/vault/create', displayName: '创建小金库'),
    '零基预算': NavigationTarget(route: '/vault/zero-based', displayName: '零基预算分配'),

    // ========== 2.0新增 - 习惯培养（7个） ==========
    '财务健康': NavigationTarget(route: '/financial-health', displayName: '财务健康仪表盘'),
    '健康度': NavigationTarget(route: '/financial-health', displayName: '财务健康仪表盘'),
    '订阅分析': NavigationTarget(route: '/subscription-waste', displayName: '订阅浪费识别'),
    '拿铁因子': NavigationTarget(route: '/latte-factor', displayName: '拿铁因子分析'),
    '小额消费': NavigationTarget(route: '/latte-factor', displayName: '拿铁因子分析'),
    '应急金': NavigationTarget(route: '/emergency-fund', displayName: '应急金目标'),
    '打卡': NavigationTarget(route: '/check-in', displayName: '连续打卡'),
    '记账打卡': NavigationTarget(route: '/check-in', displayName: '连续打卡'),

    // ========== 2.0新增 - 账单提醒（6个） ==========
    '定期账单': NavigationTarget(route: '/bill-reminder', displayName: '账单提醒列表'),
    '信用卡提醒': NavigationTarget(route: '/bill-reminder/credit-card', displayName: '信用卡还款提醒'),
    '账单日历': NavigationTarget(route: '/bill-reminder/calendar', displayName: '账单日历视图'),
    '添加账单提醒': NavigationTarget(route: '/bill-reminder/add', displayName: '添加定期账单'),

    // ========== 2.0新增 - AI智能中心（10个） ==========
    'AI中心': NavigationTarget(route: '/ai-center', displayName: 'AI智能中心'),
    '智能中心': NavigationTarget(route: '/ai-center', displayName: 'AI智能中心'),
    '智能分类': NavigationTarget(route: '/ai-center/category', displayName: '智能分类中心'),
    '分类学习': NavigationTarget(route: '/ai-center/category-learning', displayName: '分类反馈学习'),
    '消费预测': NavigationTarget(route: '/ai-center/prediction', displayName: '消费趋势预测'),
    '趋势预测': NavigationTarget(route: '/ai-center/prediction', displayName: '消费趋势预测'),
    '异常检测': NavigationTarget(route: '/ai-center/anomaly', displayName: '异常检测设置'),
    '异常交易': NavigationTarget(route: '/ai-center/anomaly-detail', displayName: '异常交易详情'),
    '智能搜索': NavigationTarget(route: '/ai-center/smart-search', displayName: '自然语言搜索'),
    '对话助手': NavigationTarget(route: '/ai-center/dialog', displayName: '对话助手设置'),
    '语音配置': NavigationTarget(route: '/ai-center/voice-config', displayName: '语音配置中心'),
    'AI成本': NavigationTarget(route: '/ai-center/cost', displayName: 'AI成本监控'),
    '学习报告': NavigationTarget(route: '/ai-center/learning-report', displayName: '智能学习报告'),

    // ========== 2.0新增 - 系统监控（6个） ==========
    '应用状态': NavigationTarget(route: '/monitor/health', displayName: '应用健康状态'),
    '性能监控': NavigationTarget(route: '/monitor/performance', displayName: '性能监控'),
    '系统日志': NavigationTarget(route: '/monitor/logs', displayName: '系统日志'),
    '告警历史': NavigationTarget(route: '/monitor/alerts', displayName: '告警历史'),
    'AI监控': NavigationTarget(route: '/monitor/ai', displayName: 'AI服务监控'),
    '诊断报告': NavigationTarget(route: '/monitor/diagnosis', displayName: '诊断报告'),

    // ========== 2.0新增 - 位置服务（6个） ==========
    '位置设置': NavigationTarget(route: '/settings/location', displayName: '位置服务设置'),
    '常驻地点': NavigationTarget(route: '/settings/location/frequent', displayName: '常驻地点设置'),
    '地理围栏': NavigationTarget(route: '/settings/location/geofence', displayName: '地理围栏管理'),
    '位置分析': NavigationTarget(route: '/settings/location/analysis', displayName: '位置分析报告'),
    '异地消费': NavigationTarget(route: '/settings/location/travel', displayName: '异地消费记录'),

    // ========== 2.0新增 - 安全隐私（6个） ==========
    '隐私设置': NavigationTarget(route: '/settings/privacy', displayName: '隐私模式设置'),
    '应用锁': NavigationTarget(route: '/settings/app-lock', displayName: '应用锁设置'),
    'PIN码': NavigationTarget(route: '/settings/pin', displayName: 'PIN码设置'),
    '安全日志': NavigationTarget(route: '/settings/audit-log', displayName: '安全审计日志'),
    '数据管理': NavigationTarget(route: '/settings/data', displayName: '数据管理'),

'''

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 更新注释：从48个页面改为119个页面
    content = content.replace(
        "/// 覆盖1.x版本全部48个页面",
        "/// 覆盖2.0版本全部119个页面"
    )
    content = content.replace(
        "// ==================== 完整页面路由映射（48个页面） ====================",
        "// ==================== 完整页面路由映射（119个页面） ===================="
    )

    # 在"用户相关"之前插入新路由
    old_text = "    // ========== 用户相关（6个） =========="
    new_text = NEW_ROUTES + "    // ========== 用户相关（6个） =========="

    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("页面路由映射表更新完成！")
    else:
        print("未找到目标文本")

if __name__ == '__main__':
    main()
