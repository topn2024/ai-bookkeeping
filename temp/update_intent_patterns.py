# -*- coding: utf-8 -*-
"""
更新意图识别规则库，添加AI智能中心相关规则
"""

AI_PATTERNS = '''
    // ==================== AI智能中心意图 ====================
    VoiceIntentType.navigateToAI: [
      r'(打开|进入).*(智能中心|AI中心|AI设置)',
      r'(智能|AI).*(中心|设置)',
    ],
    VoiceIntentType.navigateToBillReminder: [
      r'(打开|进入).*(账单提醒|定期账单)',
      r'(信用卡|账单).*(提醒|到期)',
    ],
    VoiceIntentType.navigateToMonitor: [
      r'(打开|进入).*(系统监控|性能监控|应用状态)',
      r'(监控|健康).*(状态|报告)',
    ],
    VoiceIntentType.openSmartCategory: [
      r'(打开|进入).*(智能分类|分类中心)',
      r'(智能分类).*(设置|配置)',
    ],
    VoiceIntentType.viewCategoryLearning: [
      r'(查看|看看).*(分类学习|学习记录)',
      r'(分类).*(学习|训练).*(记录|历史)',
    ],
    VoiceIntentType.trainCategory: [
      r'(重新|再次).*(训练|学习).*(分类)',
      r'(分类).*(模型).*(训练|更新)',
    ],
    VoiceIntentType.viewTrendPrediction: [
      r'(查看|看看).*(趋势预测|消费预测)',
      r'(预测).*(消费|支出)',
    ],
    VoiceIntentType.predictNextMonth: [
      r'(预测).*(下个月|下月).*(消费|支出)',
      r'(下个月|下月).*(预计|大概).*(花多少|消费)',
    ],
    VoiceIntentType.openAnomalySettings: [
      r'(打开|进入).*(异常检测|异常设置)',
      r'(异常).*(检测|交易).*(设置|配置)',
    ],
    VoiceIntentType.viewAnomalyTransactions: [
      r'(查看|看看).*(异常交易|可疑交易)',
      r'(有没有|是否有).*(异常|可疑).*(交易)',
    ],
    VoiceIntentType.enableAnomalyDetection: [
      r'(开启|打开).*(异常检测)',
    ],
    VoiceIntentType.disableAnomalyDetection: [
      r'(关闭|关掉).*(异常检测)',
    ],
    VoiceIntentType.smartSearch: [
      r'(智能搜索|自然语言搜索)',
      r'(帮我找|搜索).*(交易|账单|消费)',
    ],
    VoiceIntentType.searchByDescription: [
      r'(按描述|根据描述).*(搜索|查找)',
    ],
    VoiceIntentType.openDialogSettings: [
      r'(打开|进入).*(对话助手|对话设置)',
      r'(对话).*(助手|设置|配置)',
    ],
    VoiceIntentType.viewDialogHistory: [
      r'(查看|看看).*(对话历史|对话记录)',
    ],
    VoiceIntentType.openVoiceConfig: [
      r'(打开|进入).*(语音配置|语音设置)',
      r'(语音).*(配置|设置)',
    ],
    VoiceIntentType.setWakeWord: [
      r'(设置|更改).*(唤醒词)',
    ],
    VoiceIntentType.setVoiceLanguage: [
      r'(设置|更改).*(语音语言|识别语言)',
    ],
    VoiceIntentType.viewAICost: [
      r'(查看|看看).*(AI成本|AI费用)',
      r'(AI).*(花了|消耗).*(多少)',
    ],
    VoiceIntentType.viewAIUsage: [
      r'(查看|看看).*(AI使用|AI用量)',
      r'(AI).*(调用|使用).*(次数|情况)',
    ],
    VoiceIntentType.viewLearningReport: [
      r'(查看|看看).*(学习报告|智能学习)',
      r'(AI).*(学习|训练).*(效果|报告)',
    ],
    VoiceIntentType.viewAccuracyTrend: [
      r'(查看|看看).*(准确率|识别率)',
      r'(分类|识别).*(准确率|趋势)',
    ],

'''

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 在查询意图之前插入
    old_text = '    // ==================== 查询意图 ===================='
    new_text = AI_PATTERNS + '    // ==================== 查询意图 ===================='

    if old_text in content:
        content = content.replace(old_text, new_text)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("意图识别规则更新完成！")
    else:
        print("未找到目标文本")

if __name__ == '__main__':
    main()
