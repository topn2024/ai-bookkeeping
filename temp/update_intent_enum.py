# -*- coding: utf-8 -*-
"""
更新VoiceIntentType枚举，添加AI智能中心相关意图
"""

AI_INTENT_SECTION = '''  navigateToAI,         // AI导航：打开智能中心、AI设置
  navigateToBillReminder,// 账单提醒导航：打开账单提醒、信用卡提醒
  navigateToMonitor,    // 监控导航：打开系统监控、性能监控
  searchFunction,       // 功能搜索：找功能、哪里可以

  // ==================== AI智能中心相关 ====================
  // 智能分类
  openSmartCategory,    // 打开智能分类中心
  viewCategoryLearning, // 查看分类学习记录
  trainCategory,        // 重新训练分类模型

  // 趋势预测
  viewTrendPrediction,  // 查看消费趋势预测
  predictNextMonth,     // 预测下月消费

  // 异常检测
  openAnomalySettings,  // 打开异常检测设置
  viewAnomalyTransactions,// 查看异常交易
  enableAnomalyDetection, // 开启异常检测
  disableAnomalyDetection,// 关闭异常检测

  // 自然语言搜索
  smartSearch,          // 智能搜索：用自然语言搜索
  searchByDescription,  // 按描述搜索

  // 对话助手
  openDialogSettings,   // 打开对话助手设置
  viewDialogHistory,    // 查看对话历史

  // 语音配置
  openVoiceConfig,      // 打开语音配置中心
  setWakeWord,          // 设置唤醒词
  setVoiceLanguage,     // 设置语音语言

  // AI成本监控
  viewAICost,           // 查看AI成本
  viewAIUsage,          // 查看AI使用量

  // 学习报告
  viewLearningReport,   // 查看智能学习报告
  viewAccuracyTrend,    // 查看准确率趋势

'''

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 查找插入点
    old_text = '''  navigateToUser,       // 用户导航：打开登录、关于、帮助
  searchFunction,       // 功能搜索：找功能、哪里可以

  // ==================== 直接操作（无需进入页面） ===================='''

    new_text = '''  navigateToUser,       // 用户导航：打开登录、关于、帮助
''' + AI_INTENT_SECTION + '''
  // ==================== 直接操作（无需进入页面） ===================='''

    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("VoiceIntentType枚举更新完成！")
    else:
        print("未找到目标文本，尝试模糊匹配...")
        # 尝试只匹配关键部分
        old_text2 = 'searchFunction,       // 功能搜索：找功能、哪里可以\n\n  // ==================== 直接操作'
        new_text2 = AI_INTENT_SECTION + '  // ==================== 直接操作'
        if old_text2 in content:
            content = content.replace(old_text2, new_text2)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print("VoiceIntentType枚举更新完成（模糊匹配）！")
        else:
            print("仍然未找到匹配")

if __name__ == '__main__':
    main()
