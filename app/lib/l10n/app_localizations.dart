import 'package:flutter/material.dart';

/// 支持的语言
enum AppLanguage {
  zhCN, // 简体中文
  zhTW, // 繁体中文
  en,   // 英语
  ja,   // 日语
  ko,   // 韩语
}

/// 语言信息
class LanguageInfo {
  final AppLanguage language;
  final String code;
  final String name;       // 本地名称
  final String nameEn;     // 英文名称
  final Locale locale;
  final String flag;

  const LanguageInfo({
    required this.language,
    required this.code,
    required this.name,
    required this.nameEn,
    required this.locale,
    required this.flag,
  });
}

/// 支持的语言列表
class AppLanguages {
  static const Map<AppLanguage, LanguageInfo> all = {
    AppLanguage.zhCN: LanguageInfo(
      language: AppLanguage.zhCN,
      code: 'zh_CN',
      name: '简体中文',
      nameEn: 'Simplified Chinese',
      locale: Locale('zh', 'CN'),
      flag: '🇨🇳',
    ),
    AppLanguage.zhTW: LanguageInfo(
      language: AppLanguage.zhTW,
      code: 'zh_TW',
      name: '繁體中文',
      nameEn: 'Traditional Chinese',
      locale: Locale('zh', 'TW'),
      flag: '🇹🇼',
    ),
    AppLanguage.en: LanguageInfo(
      language: AppLanguage.en,
      code: 'en',
      name: 'English',
      nameEn: 'English',
      locale: Locale('en'),
      flag: '🇺🇸',
    ),
    AppLanguage.ja: LanguageInfo(
      language: AppLanguage.ja,
      code: 'ja',
      name: '日本語',
      nameEn: 'Japanese',
      locale: Locale('ja'),
      flag: '🇯🇵',
    ),
    AppLanguage.ko: LanguageInfo(
      language: AppLanguage.ko,
      code: 'ko',
      name: '한국어',
      nameEn: 'Korean',
      locale: Locale('ko'),
      flag: '🇰🇷',
    ),
  };

  static LanguageInfo get(AppLanguage lang) => all[lang]!;
  static List<LanguageInfo> get list => all.values.toList();
  static List<Locale> get supportedLocales => all.values.map((l) => l.locale).toList();
}

/// 应用本地化字符串
class AppLocalizations {
  final AppLanguage currentLanguage;

  AppLocalizations(this.currentLanguage);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(AppLanguage.zhCN);
  }

  /// 获取当前语言的翻译
  String get(String key) {
    return _translations[currentLanguage]?[key] ?? _translations[AppLanguage.zhCN]?[key] ?? key;
  }

  // ============ 通用 ============
  String get appName => get('app_name');
  String get confirm => get('confirm');
  String get cancel => get('cancel');
  String get save => get('save');
  String get delete => get('delete');
  String get edit => get('edit');
  String get add => get('add');
  String get close => get('close');
  String get loading => get('loading');
  String get error => get('error');
  String get success => get('success');
  String get warning => get('warning');
  String get noData => get('no_data');
  String get retry => get('retry');

  // ============ 导航 ============
  String get home => get('home');
  String get statistics => get('statistics');
  String get addRecord => get('add_record');
  String get budget => get('budget');
  String get settings => get('settings');

  // ============ 记账 ============
  String get expense => get('expense');
  String get income => get('income');
  String get transfer => get('transfer');
  String get amount => get('amount');
  String get category => get('category');
  String get account => get('account');
  String get date => get('date');
  String get note => get('note');
  String get enterAmount => get('enter_amount');
  String get selectCategory => get('select_category');
  String get selectAccount => get('select_account');

  // ============ 统计 ============
  String get totalIncome => get('total_income');
  String get totalExpense => get('total_expense');
  String get balance => get('balance');
  String get daily => get('daily');
  String get weekly => get('weekly');
  String get monthly => get('monthly');
  String get yearly => get('yearly');

  // ============ 设置 ============
  String get profile => get('profile');
  String get language => get('language');
  String get currency => get('currency');
  String get theme => get('theme');
  String get darkMode => get('dark_mode');
  String get lightMode => get('light_mode');
  String get systemMode => get('system_mode');
  String get dataBackup => get('data_backup');
  String get dataExport => get('data_export');
  String get dataImport => get('data_import');
  String get about => get('about');
  String get logout => get('logout');
  String get login => get('login');
  String get register => get('register');

  // ============ 账户 ============
  String get cash => get('cash');
  String get bankCard => get('bank_card');
  String get creditCard => get('credit_card');
  String get eWallet => get('e_wallet');
  String get accountBalance => get('account_balance');

  // ============ 预算 ============
  String get budgetManagement => get('budget_management');
  String get monthlyBudget => get('monthly_budget');
  String get categoryBudget => get('category_budget');
  String get budgetRemaining => get('budget_remaining');
  String get budgetExceeded => get('budget_exceeded');

  // ============ 货币相关 ============
  String get currencySettings => get('currency_settings');
  String get defaultCurrency => get('default_currency');
  String get showCurrencySymbol => get('show_currency_symbol');

  // ============ 语言相关 ============
  String get languageSettings => get('language_settings');
  String get followSystem => get('follow_system');

  // ============ AA分摊 ============
  String get aaSplit => get('aa_split');
  String get aaDetected => get('aa_detected');
  String get totalAmount => get('total_amount');
  String get splitPeople => get('split_people');
  String get autoDetected => get('auto_detected');
  String get myShare => get('my_share');
  String get perPerson => get('per_person');
  String get bookkeepingMode => get('bookkeeping_mode');
  String get onlyMyShare => get('only_my_share');
  String get recordTotal => get('record_total');
  String get confirmSplit => get('confirm_split');
  String get splitMethod => get('split_method');
  String get evenSplit => get('even_split');
  String get proportionalSplit => get('proportional_split');
  String get customSplit => get('custom_split');
  String get yourShare => get('your_share');

  // ============ 无障碍设置 ============
  String get accessibilitySettings => get('accessibility_settings');
  String get fontSize => get('font_size');
  String get highContrast => get('high_contrast');
  String get boldText => get('bold_text');
  String get reduceMotion => get('reduce_motion');
  String get screenReader => get('screen_reader');
  String get largeTouchTarget => get('large_touch_target');
  String get largeTouch => get('large_touch');

  // ============ 智能建议 ============
  String get smartAdvice => get('smart_advice');
  String get todayAdvice => get('today_advice');
  String get manageAdvicePreference => get('manage_advice_preference');

  // ============ AI语言设置 ============
  String get aiLanguageSettings => get('ai_language_settings');
  String get aiReplyLanguage => get('ai_reply_language');
  String get voiceRecognitionLanguage => get('voice_recognition_language');
  String get aiLearningCurve => get('ai_learning_curve');
  String get aiVoice => get('ai_voice');
  String get maleVoice => get('male_voice');
  String get femaleVoice => get('female_voice');

  // ============ 应用设置 ============
  String get appLockSettings => get('app_lock_settings');
  String get batchTrainAI => get('batch_train_ai');

  // ============ 家庭功能 ============
  String get familyLeaderboard => get('family_leaderboard');
  String get weeklyRanking => get('weekly_ranking');
  String get monthlyRanking => get('monthly_ranking');
  String get savingsChampion => get('savings_champion');
  String get budgetMaster => get('budget_master');
  String get familySavingsGoal => get('family_savings_goal');
  String get contributeNow => get('contribute_now');
  String get goalAmount => get('goal_amount');
  String get currentProgress => get('current_progress');
  String get daysRemaining => get('days_remaining');

  // ============ 账本设置 ============
  String get ledgerSettings => get('ledger_settings');
  String get defaultLedger => get('default_ledger');
  String get ledgerName => get('ledger_name');
  String get ledgerIcon => get('ledger_icon');
  String get ledgerColor => get('ledger_color');
  String get archiveLedger => get('archive_ledger');

  // ============ 位置服务 ============
  String get locationServices => get('location_services');
  String get enableLocation => get('enable_location');
  String get locationAccuracy => get('location_accuracy');
  String get highAccuracy => get('high_accuracy');
  String get lowPower => get('low_power');
  String get geofenceAlerts => get('geofence_alerts');
  String get nearbyMerchants => get('nearby_merchants');

  // ============ 交易相关 ============
  String get duplicateTransaction => get('duplicate_transaction');
  String get transactionTime => get('transaction_time');
  String get transactionNote => get('transaction_note');
  String get transactionTags => get('transaction_tags');
  String get transactionLocation => get('transaction_location');
  String get transactionAttachments => get('transaction_attachments');

  // ============ 钱龄分析 ============
  String get moneyAgeTitle => get('money_age_title');
  String get moneyAgeDescription2 => get('money_age_description2');
  String get averageMoneyAge => get('average_money_age');
  String get moneyAgeHealth => get('money_age_health');
  String get poor => get('poor');

  // ============ 习惯追踪 ============
  String get habitTracking => get('habit_tracking');
  String get dailyStreak => get('daily_streak');
  String get weeklyGoal => get('weekly_goal');
  String get monthlyGoal => get('monthly_goal');

  // ============ 成就系统 ============
  String get achievementUnlocked => get('achievement_unlocked');
  String get viewAchievements => get('view_achievements');
  String get shareAchievement => get('share_achievement');
  String get achievementProgress => get('achievement_progress');

  // ============ 语音相关 ============
  String get listening => get('listening');
  String get voiceError => get('voice_error');
  String get speakNow => get('speak_now');

  // ============ 扫描相关 ============
  String get scanBill => get('scan_bill');
  String get recognizing => get('recognizing');
  String get recognitionFailed => get('recognition_failed');

  // ============ 同步相关 ============
  String get syncing => get('syncing');
  String get syncComplete => get('sync_complete');
  String get syncFailed => get('sync_failed');
  String get lastSynced => get('last_synced');
  String get syncNow => get('sync_now');

  // ============ 离线模式 ============
  String get offlineMode => get('offline_mode');
  String get offlineData => get('offline_data');
  String get pendingSync => get('pending_sync');
  String get offlineChanges => get('offline_changes');

  // ============ 隐私设置 ============
  String get privacySettings => get('privacy_settings');
  String get dataEncryption => get('data_encryption');
  String get biometricLock => get('biometric_lock');
  String get autoLock => get('auto_lock');
  String get lockTimeout => get('lock_timeout');

  // ============ 预算提醒 ============
  String get budgetWarning => get('budget_warning');
  String get budgetAlerts => get('budget_alerts');
  String get dailyReminder => get('daily_reminder');

  // ============ 导出格式 ============
  String get exportFormat => get('export_format');
  String get csvFormat => get('csv_format');
  String get excelFormat => get('excel_format');
  String get jsonFormat => get('json_format');

  // ============ 反馈相关 ============
  String get feedbackSubmitted => get('feedback_submitted');
  String get thankYouFeedback => get('thank_you_feedback');
  String get rateApp => get('rate_app');
  String get shareApp => get('share_app');

  // ============ 登录相关 ============
  String get upgradeRequired => get('upgrade_required');
  String get loginRequired => get('login_required');
  String get loginToUseFeature => get('login_to_use_feature');
  String get loginNow => get('login_now');
  String get continueAsGuest => get('continue_as_guest');

  // ============ 网络相关 ============
  String get connectionFailed => get('connection_failed');
  String get checkNetwork => get('check_network');

  // ============ 权限相关 ============
  String get permissionRequired => get('permission_required');
  String get locationPermission => get('location_permission');
  String get storagePermission => get('storage_permission');

  // ============ 删除相关 ============
  String get deleteWarning => get('delete_warning');
  String get permanentlyDelete => get('permanently_delete');
  String get moveToTrash => get('move_to_trash');

  // ============ 搜索相关 ============
  String get searchPlaceholder => get('search_placeholder');
  String get noResults => get('no_results');
  String get searchHistory => get('search_history');
  String get clearHistory => get('clear_history');

  // ============ 筛选排序 ============
  String get filterBy => get('filter_by');
  String get sortBy => get('sort_by');
  String get dateRange => get('date_range');
  String get amountRange => get('amount_range');
  String get categoryFilter => get('category_filter');
  String get ascending => get('ascending');
  String get descending => get('descending');
  String get byDate => get('by_date');
  String get byAmount => get('by_amount');
  String get byCategory => get('by_category');

  // ============ 批量操作 ============
  String get selectAll => get('select_all');
  String get deselectAll => get('deselect_all');
  String get selected => get('selected');
  String get batchDelete => get('batch_delete');
  String get batchEdit => get('batch_edit');

  // ============ 操作相关 ============
  String get redo => get('redo');
  String get actionUndone => get('action_undone');
  String get actionRedone => get('action_redone');

  // ============ 加载相关 ============
  String get loadMore => get('load_more');
  String get refreshing => get('refreshing');
  String get pullToRefresh => get('pull_to_refresh');
  String get releaseToRefresh => get('release_to_refresh');

  // ============ 空状态 ============
  String get emptyState => get('empty_state');
  String get addFirst => get('add_first');

  // ============ 问候语 ============
  String get welcomeBack => get('welcome_back');
  String get goodMorning => get('good_morning');
  String get goodAfternoon => get('good_afternoon');
  String get goodEvening => get('good_evening');

  // ============ 快捷操作 ============
  String get frequentCategories => get('frequent_categories');
  String get suggestedActions => get('suggested_actions');

  // ============ 数据导入导出 ============
  String get importData => get('import_data');
  String get exportData => get('export_data');

  // ============ 财务自由模拟器 ============
  String get financialFreedomSimulator => get('financial_freedom_simulator');
  String get yourFinancialFreedomJourney => get('your_financial_freedom_journey');
  String get estimatedTime => get('estimated_time');
  String get toAchieveFreedom => get('to_achieve_freedom');
  String get accelerateTip => get('accelerate_tip');
  String get adjustParameters => get('adjust_parameters');
  String get monthlySavings => get('monthly_savings');
  String get annualReturn => get('annual_return');
  String get targetPassiveIncome => get('target_passive_income');
  String get disclaimer => get('disclaimer');

  // ============ 家庭年度回顾 ============
  String get daysRecording => get('days_recording');
  String get familyDinners => get('family_dinners');
  String get tripsCount => get('trips_count');
  String get warmestMoment => get('warmest_moment');
  String get biggestGoal => get('biggest_goal');
  String get sharedTime => get('shared_time');
  String get yearlyWarmMoments => get('yearly_warm_moments');
  String get familyContributions => get('family_contributions');
  String get saveImage => get('save_image');
  String get shareToFamily => get('share_to_family');

  // ============ 家庭生日 ============
  String get education => get('education');
  String get hobbies => get('hobbies');
  String get growth => get('growth');
  String get generateBirthdayCard => get('generate_birthday_card');

  // ============ 家庭排行榜 ============
  String get recordLeaderboard => get('record_leaderboard');
  String get savingsLeaderboard => get('savings_leaderboard');
  String get badgesWall => get('badges_wall');
  String get leaderboard => get('leaderboard');

  // ============ 家庭储蓄目标 ============
  String get memberContribution => get('member_contribution');
  String get otherSavingsGoals => get('other_savings_goals');
  String get recentDeposits => get('recent_deposits');
  String get depositNow => get('deposit_now');

  // ============ 家庭简易模式 ============
  String get simpleMode => get('simple_mode');
  String get monthlySharedExpense => get('monthly_shared_expense');
  String get recentRecords => get('recent_records');
  String get viewAll => get('view_all');
  String get upgradeToFullMode => get('upgrade_to_full_mode');
  String get fullMode => get('full_mode');
  String get staySimple => get('stay_simple');

  // ============ 地理围栏 ============
  String get geofenceReminder => get('geofence_reminder');

  // ============ 首页布局 ============
  String get homeLayout => get('home_layout');
  String get reset => get('reset');

  // ============ 账本设置扩展 ============
  String get ledgerType => get('ledger_type');
  String get defaultVisibility => get('default_visibility');
  String get visibilityDesc => get('visibility_desc');
  String get hideAmount => get('hide_amount');
  String get hideAmountDesc => get('hide_amount_desc');
  String get notificationSettings => get('notification_settings');
  String get memberRecordNotify => get('member_record_notify');
  String get budgetOverflowAlert => get('budget_overflow_alert');
  String get dangerZone => get('danger_zone');
  String get leaveLedger => get('leave_ledger');
  String get deleteLedger => get('delete_ledger');
  String get onlyOwnerCanDelete => get('only_owner_can_delete');

  // ============ 位置分析 ============
  String get locationAnalysis => get('location_analysis');
  String get preciseLocationService => get('precise_location_service');
  String get residentLocations => get('resident_locations');
  String get locationAnalysisReport => get('location_analysis_report');
  String get remoteSpendingRecord => get('remote_spending_record');
  String get dataSecurityGuarantee => get('data_security_guarantee');

  // ============ 会员权限 ============
  String get member => get('member');
  String get memberBenefits => get('member_benefits');
  String get memberDesc => get('member_desc');
  String get memberPermissions => get('member_permissions');
  String get membershipService => get('membership_service');
  String get memberVoteStatus => get('member_vote_status');
  String get admin => get('admin');
  String get adminDesc => get('admin_desc');
  String get owner => get('owner');
  String get ownerDesc => get('owner_desc');
  String get viewer => get('viewer');
  String get viewerDesc => get('viewer_desc');
  String get currentPermissions => get('current_permissions');
  String get permissionSettings => get('permission_settings');
  String get selectRole => get('select_role');
  String get roleRecommendation => get('role_recommendation');

  // ============ 离线模式扩展 ============
  String get offlineModeActive => get('offline_mode_active');
  String get offlineModeDesc => get('offline_mode_desc');
  String get offlineModeFullDesc => get('offline_mode_full_desc');
  String get offlineVoice => get('offline_voice');
  String get offlineVoiceDesc => get('offline_voice_desc');
  String get online => get('online');
  String get networkUnavailable => get('network_unavailable');
  String get retryNetwork => get('retry_network');
  String get retryOnline => get('retry_online');
  String get continueOffline => get('continue_offline');
  String get useOffline => get('use_offline');

  // ============ 智能功能 ============
  String get smartRecommendation => get('smart_recommendation');
  String get discoverNewFeature => get('discover_new_feature');
  String get laterRemind => get('later_remind');
  String get aiParsing => get('ai_parsing');
  String get aiParsingOfflineDesc => get('ai_parsing_offline_desc');
  String get analyzing => get('analyzing');
  String get confidenceLevel => get('confidence_level');
  String get lowConfidenceTitle => get('low_confidence_title');
  String get recognitionResult => get('recognition_result');
  String get autoExtracted => get('auto_extracted');
  String get originalText => get('original_text');

  // ============ 语音助手 ============
  String get voiceAssistant => get('voice_assistant');
  String get voiceChat => get('voice_chat');
  String get voiceHistoryTitle => get('voice_history_title');
  String get voiceHistoryHint => get('voice_history_hint');
  String get noVoiceHistory => get('no_voice_history');
  String get typeOrSpeak => get('type_or_speak');
  String get askAnything => get('ask_anything');
  String get youCanAsk => get('you_can_ask');
  String get examples => get('examples');
  String get quickQuestions => get('quick_questions');
  String get continueAsking => get('continue_asking');
  String get continuousChat => get('continuous_chat');

  // ============ 自然语言输入 ============
  String get naturalLanguageInput => get('natural_language_input');
  String get smartTextInput => get('smart_text_input');
  String get inputHint => get('input_hint');
  String get inputToBookkeep => get('input_to_bookkeep');
  String get quickBookkeep => get('quick_bookkeep');
  String get quickBookkeeping => get('quick_bookkeeping');
  String get confirmBookkeeping => get('confirm_bookkeeping');
  String get basicRecording => get('basic_recording');

  // ============ 预算查询 ============
  String get budgetQuery => get('budget_query');
  String get budgetOverspentAlert => get('budget_overspent_alert');
  String get moneyAgeQuery => get('money_age_query');

  // ============ 账单提醒 ============
  String get billDueReminder => get('bill_due_reminder');
  String get remind => get('remind');

  // ============ 升级功能 ============
  String get upgradeMode => get('upgrade_mode');
  String get upgradeNotice => get('upgrade_notice');
  String get upgradeNoticeDesc => get('upgrade_notice_desc');
  String get upgradeDescription => get('upgrade_description');
  String get upgradeVote => get('upgrade_vote');
  String get choosePlan => get('choose_plan');
  String get startUpgrade => get('start_upgrade');
  String get completeUpgrade => get('complete_upgrade');
  String get waitingForVotes => get('waiting_for_votes');
  String get voteComplete => get('vote_complete');
  String get voteRules => get('vote_rules');
  String get feature => get('feature');
  String get discount => get('discount');

  // ============ 家庭邀请 ============
  String get inviteFamily => get('invite_family');
  String get createFamilyLedger => get('create_family_ledger');
  String get qrCodeInvite => get('qr_code_invite');
  String get showQRCode => get('show_qr_code');
  String get scanToJoin => get('scan_to_join');
  String get sendInviteLink => get('send_invite_link');
  String get shareLink => get('share_link');
  String get copyLink => get('copy_link');

  // ============ 安全设置 ============
  String get securitySettings => get('security_settings');
  String get securityLog => get('security_log');
  String get appLock => get('app_lock');
  String get setPin => get('set_pin');
  String get fingerprintUnlock => get('fingerprint_unlock');
  String get faceIdUnlock => get('face_id_unlock');
  String get preventScreenshot => get('prevent_screenshot');
  String get privacyMode => get('privacy_mode');
  String get pushNotification => get('push_notification');
  String get autoSync => get('auto_sync');
  String get autoSyncDesc => get('auto_sync_desc');

  // ============ 数据管理 ============
  String get dataManagement => get('data_management');
  String get saveChanges => get('save_changes');
  String get viewStats => get('view_stats');
  String get detailedStats => get('detailed_stats');
  String get getSuggestion => get('get_suggestion');
  String get savingsGoals => get('savings_goals');
  String get annualReview => get('annual_review');
  String get weeklyReport => get('weekly_report');

  // ============ 区域设置 ============
  String get regionSettings => get('region_settings');
  String get dateFormat => get('date_format');
  String get timeFormat => get('time_format');
  String get numberFormat => get('number_format');
  String get weekStartDay => get('week_start_day');

  // ============ 收据 ============
  String get receiptDetail => get('receipt_detail');
  String get subtotal => get('subtotal');
  String get remainingAmount => get('remaining_amount');

  // ============ 帮助 ============
  String get faq => get('faq');
  String get addNote => get('add_note');

  /// 翻译数据
  static const Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.zhCN: _zhCN,
    AppLanguage.zhTW: _zhTW,
    AppLanguage.en: _en,
    AppLanguage.ja: _ja,
    AppLanguage.ko: _ko,
  };

  // 简体中文
  static const Map<String, String> _zhCN = {
    // 通用
    'app_name': '鱼记',
    'confirm': '确认',
    'cancel': '取消',
    'save': '保存',
    'delete': '删除',
    'edit': '编辑',
    'add': '添加',
    'close': '关闭',
    'loading': '加载中...',
    'error': '错误',
    'success': '成功',
    'warning': '警告',
    'no_data': '暂无数据',
    'retry': '重试',
    // 导航
    'home': '首页',
    'statistics': '统计',
    'add_record': '记账',
    'budget': '预算',
    'settings': '我的',
    // 记账
    'expense': '支出',
    'income': '收入',
    'transfer': '转账',
    'amount': '金额',
    'category': '分类',
    'account': '账户',
    'date': '日期',
    'note': '备注',
    'enter_amount': '请输入金额',
    'select_category': '选择分类',
    'select_account': '选择账户',
    // 统计
    'total_income': '总收入',
    'total_expense': '总支出',
    'balance': '结余',
    'daily': '日',
    'weekly': '周',
    'monthly': '月',
    'yearly': '年',
    // 设置
    'profile': '我的',
    'language': '语言',
    'currency': '货币',
    'theme': '主题',
    'dark_mode': '深色模式',
    'light_mode': '浅色模式',
    'system_mode': '跟随系统',
    'data_backup': '数据备份',
    'data_export': '数据导出',
    'data_import': '数据导入',
    'about': '关于',
    'logout': '退出登录',
    'login': '登录',
    'register': '注册',
    // 账户
    'cash': '现金',
    'bank_card': '银行卡',
    'credit_card': '信用卡',
    'e_wallet': '电子钱包',
    'account_balance': '账户余额',
    // 预算
    'budget_management': '预算管理',
    'monthly_budget': '月度预算',
    'category_budget': '分类预算',
    'budget_remaining': '剩余预算',
    'budget_exceeded': '已超支',
    // 货币
    'currency_settings': '货币设置',
    'default_currency': '默认货币',
    'show_currency_symbol': '显示货币符号',
    // 语言
    'language_settings': '语言设置',
    'follow_system': '跟随系统',
    // AA分摊
    'aa_split': 'AA分摊',
    'aa_detected': '检测到AA消费',
    'total_amount': '总金额',
    'split_people': '分摊人数',
    'auto_detected': '自动检测',
    'my_share': '我的份额',
    'per_person': '人均',
    'bookkeeping_mode': '记账模式',
    'only_my_share': '只记我的份额',
    'record_total': '记录全部',
    'confirm_split': '确认分摊',
    'split_method': '分摊方式',
    'even_split': '平均分摊',
    'proportional_split': '按比例分摊',
    'custom_split': '自定义分摊',
    'your_share': '你的份额',
    // 无障碍设置
    'accessibility_settings': '无障碍设置',
    'font_size': '字体大小',
    'high_contrast': '高对比度',
    'bold_text': '粗体文字',
    'reduce_motion': '减少动画',
    'screen_reader': '屏幕阅读器支持',
    'large_touch_target': '大触控区域',
    'large_touch': '大触控',
    // 智能建议
    'smart_advice': '智能建议',
    'today_advice': '今日建议',
    'manage_advice_preference': '管理建议偏好',
    // AI语言设置
    'ai_language_settings': 'AI语言设置',
    'ai_reply_language': 'AI回复语言',
    'voice_recognition_language': '语音识别语言',
    'ai_learning_curve': 'AI学习曲线',
    'ai_voice': 'AI语音',
    'male_voice': '男声',
    'female_voice': '女声',
    // 应用设置
    'app_lock_settings': '应用锁设置',
    'batch_train_ai': '批量训练AI',
    // 家庭功能
    'family_leaderboard': '家庭排行榜',
    'weekly_ranking': '本周排名',
    'monthly_ranking': '本月排名',
    'savings_champion': '储蓄冠军',
    'budget_master': '预算达人',
    'family_savings_goal': '家庭储蓄目标',
    'contribute_now': '立即贡献',
    'goal_amount': '目标金额',
    'current_progress': '当前进度',
    'days_remaining': '剩余天数',
    // 账本设置
    'ledger_settings': '账本设置',
    'default_ledger': '默认账本',
    'ledger_name': '账本名称',
    'ledger_icon': '账本图标',
    'ledger_color': '账本颜色',
    'archive_ledger': '归档账本',
    // 位置服务
    'location_services': '位置服务',
    'enable_location': '启用位置',
    'location_accuracy': '定位精度',
    'high_accuracy': '高精度',
    'low_power': '低功耗',
    'geofence_alerts': '地理围栏提醒',
    'nearby_merchants': '附近商家',
    // 交易相关
    'duplicate_transaction': '复制交易',
    'transaction_time': '交易时间',
    'transaction_note': '交易备注',
    'transaction_tags': '交易标签',
    'transaction_location': '交易位置',
    'transaction_attachments': '交易附件',
    // 钱龄分析
    'money_age_title': '钱龄分析',
    'money_age_description2': '了解你的资金周转效率',
    'average_money_age': '平均钱龄',
    'money_age_health': '钱龄健康度',
    'poor': '较差',
    // 习惯追踪
    'habit_tracking': '习惯追踪',
    'daily_streak': '连续记账',
    'weekly_goal': '每周目标',
    'monthly_goal': '每月目标',
    // 成就系统
    'achievement_unlocked': '成就解锁',
    'view_achievements': '查看成就',
    'share_achievement': '分享成就',
    'achievement_progress': '成就进度',
    // 语音相关
    'listening': '正在聆听...',
    'voice_error': '语音识别失败',
    'speak_now': '请说话',
    // 扫描相关
    'scan_bill': '扫描账单',
    'recognizing': '识别中...',
    'recognition_failed': '识别失败',
    // 同步相关
    'syncing': '同步中...',
    'sync_complete': '同步完成',
    'sync_failed': '同步失败',
    'last_synced': '上次同步',
    'sync_now': '立即同步',
    // 离线模式
    'offline_mode': '离线模式',
    'offline_data': '离线数据',
    'pending_sync': '待同步',
    'offline_changes': '离线更改',
    // 隐私设置
    'privacy_settings': '隐私设置',
    'data_encryption': '数据加密',
    'biometric_lock': '生物识别锁',
    'auto_lock': '自动锁定',
    'lock_timeout': '锁定超时',
    // 预算提醒
    'budget_warning': '预算预警',
    'budget_alerts': '预算提醒',
    'daily_reminder': '每日提醒',
    // 导出格式
    'export_format': '导出格式',
    'csv_format': 'CSV格式',
    'excel_format': 'Excel格式',
    'json_format': 'JSON格式',
    // 反馈相关
    'feedback_submitted': '反馈已提交',
    'thank_you_feedback': '感谢您的反馈',
    'rate_app': '给应用评分',
    'share_app': '分享应用',
    // 登录相关
    'upgrade_required': '需要升级',
    'login_required': '需要登录',
    'login_to_use_feature': '登录后可使用此功能',
    'login_now': '立即登录',
    'continue_as_guest': '以访客身份继续',
    // 网络相关
    'connection_failed': '连接失败',
    'check_network': '请检查网络连接',
    // 权限相关
    'permission_required': '需要权限',
    'location_permission': '位置权限',
    'storage_permission': '存储权限',
    // 删除相关
    'delete_warning': '此操作无法撤销',
    'permanently_delete': '永久删除',
    'move_to_trash': '移至回收站',
    // 搜索相关
    'search_placeholder': '搜索...',
    'no_results': '无结果',
    'search_history': '搜索历史',
    'clear_history': '清除历史',
    // 筛选排序
    'filter_by': '筛选',
    'sort_by': '排序',
    'date_range': '日期范围',
    'amount_range': '金额范围',
    'category_filter': '分类筛选',
    'ascending': '升序',
    'descending': '降序',
    'by_date': '按日期',
    'by_amount': '按金额',
    'by_category': '按分类',
    // 批量操作
    'select_all': '全选',
    'deselect_all': '取消全选',
    'selected': '已选择',
    'batch_delete': '批量删除',
    'batch_edit': '批量编辑',
    // 操作相关
    'redo': '重做',
    'action_undone': '操作已撤销',
    'action_redone': '操作已重做',
    // 加载相关
    'load_more': '加载更多',
    'refreshing': '刷新中...',
    'pull_to_refresh': '下拉刷新',
    'release_to_refresh': '释放刷新',
    // 空状态
    'empty_state': '暂无数据',
    'add_first': '添加第一条记录',
    // 问候语
    'welcome_back': '欢迎回来',
    'good_morning': '早上好',
    'good_afternoon': '下午好',
    'good_evening': '晚上好',
    // 快捷操作
    'frequent_categories': '常用分类',
    'suggested_actions': '建议操作',
    // 数据导入导出
    'import_data': '导入数据',
    'export_data': '导出数据',
    // 财务自由模拟器
    'financial_freedom_simulator': '财务自由模拟器',
    'your_financial_freedom_journey': '你的财务自由之旅',
    'estimated_time': '预计时间',
    'to_achieve_freedom': '达成财务自由',
    'accelerate_tip': '加速建议',
    'adjust_parameters': '调整参数',
    'monthly_savings': '月储蓄额',
    'annual_return': '年化收益率',
    'target_passive_income': '目标被动收入',
    'disclaimer': '仅供参考，不构成理财建议',
    // 家庭年度回顾
    'days_recording': '天记录',
    'family_dinners': '家庭聚餐',
    'trips_count': '出行次数',
    'warmest_moment': '最温暖时刻',
    'biggest_goal': '最大目标',
    'shared_time': '共度时光',
    'yearly_warm_moments': '年度温暖时刻',
    'family_contributions': '家庭贡献',
    'save_image': '保存图片',
    'share_to_family': '分享给家人',
    // 家庭生日
    'education': '教育',
    'hobbies': '爱好',
    'growth': '成长',
    'generate_birthday_card': '生成生日贺卡',
    // 家庭排行榜
    'record_leaderboard': '记录排行榜',
    'savings_leaderboard': '储蓄排行榜',
    'badges_wall': '徽章墙',
    'leaderboard': '排行榜',
    // 家庭储蓄目标
    'member_contribution': '成员贡献',
    'other_savings_goals': '其他储蓄目标',
    'recent_deposits': '最近存款',
    'deposit_now': '立即存入',
    // 家庭简易模式
    'simple_mode': '简易模式',
    'monthly_shared_expense': '月度共享支出',
    'recent_records': '最近记录',
    'view_all': '查看全部',
    'upgrade_to_full_mode': '升级到完整模式',
    'full_mode': '完整模式',
    'stay_simple': '保持简洁',
    // 地理围栏
    'geofence_reminder': '地理围栏提醒',
    // 首页布局
    'home_layout': '首页布局',
    'reset': '重置',
    // 账本设置扩展
    'ledger_type': '账本类型',
    'default_visibility': '默认可见性',
    'visibility_desc': '设置默认的可见性范围',
    'hide_amount': '隐藏金额',
    'hide_amount_desc': '在列表中隐藏金额显示',
    'notification_settings': '通知设置',
    'member_record_notify': '成员记账通知',
    'budget_overflow_alert': '预算超支提醒',
    'danger_zone': '危险区域',
    'leave_ledger': '离开账本',
    'delete_ledger': '删除账本',
    'only_owner_can_delete': '仅所有者可删除',
    // 位置分析
    'location_analysis': '位置分析',
    'precise_location_service': '精准定位服务',
    'resident_locations': '常驻位置',
    'location_analysis_report': '位置分析报告',
    'remote_spending_record': '异地消费记录',
    'data_security_guarantee': '数据安全保障',
    // 会员权限
    'member': '成员',
    'member_benefits': '会员权益',
    'member_desc': '成员权限说明',
    'member_permissions': '成员权限',
    'membership_service': '会员服务',
    'member_vote_status': '成员投票状态',
    'admin': '管理员',
    'admin_desc': '管理员权限说明',
    'owner': '所有者',
    'owner_desc': '所有者权限说明',
    'viewer': '查看者',
    'viewer_desc': '查看者权限说明',
    'current_permissions': '当前权限',
    'permission_settings': '权限设置',
    'select_role': '选择角色',
    'role_recommendation': '角色推荐',
    // 离线模式扩展
    'offline_mode_active': '离线模式已启用',
    'offline_mode_desc': '离线模式说明',
    'offline_mode_full_desc': '离线模式下数据存储在本地，联网后自动同步',
    'offline_voice': '离线语音',
    'offline_voice_desc': '支持离线语音识别',
    'online': '在线',
    'network_unavailable': '网络不可用',
    'retry_network': '重试网络',
    'retry_online': '重新联网',
    'continue_offline': '继续离线使用',
    'use_offline': '离线使用',
    // 智能功能
    'smart_recommendation': '智能推荐',
    'discover_new_feature': '发现新功能',
    'later_remind': '稍后提醒',
    'ai_parsing': 'AI解析',
    'ai_parsing_offline_desc': '离线模式下AI解析不可用',
    'analyzing': '分析中...',
    'confidence_level': '置信度',
    'low_confidence_title': '低置信度',
    'recognition_result': '识别结果',
    'auto_extracted': '自动提取',
    'original_text': '原始文本',
    // 语音助手
    'voice_assistant': '语音助手',
    'voice_chat': '语音聊天',
    'voice_history_title': '语音历史',
    'voice_history_hint': '查看历史语音记录',
    'no_voice_history': '暂无语音历史',
    'type_or_speak': '输入或说话',
    'ask_anything': '问我任何问题',
    'you_can_ask': '你可以问我',
    'examples': '示例',
    'quick_questions': '快捷问题',
    'continue_asking': '继续提问',
    'continuous_chat': '连续对话',
    // 自然语言输入
    'natural_language_input': '自然语言输入',
    'smart_text_input': '智能文本输入',
    'input_hint': '输入提示',
    'input_to_bookkeep': '输入记账',
    'quick_bookkeep': '快速记账',
    'quick_bookkeeping': '快捷记账',
    'confirm_bookkeeping': '确认记账',
    'basic_recording': '基础记录',
    // 预算查询
    'budget_query': '预算查询',
    'budget_overspent_alert': '预算已超支',
    'money_age_query': '钱龄查询',
    // 账单提醒
    'bill_due_reminder': '账单到期提醒',
    'remind': '提醒',
    // 升级功能
    'upgrade_mode': '升级模式',
    'upgrade_notice': '升级通知',
    'upgrade_notice_desc': '有新版本可用',
    'upgrade_description': '升级说明',
    'upgrade_vote': '升级投票',
    'choose_plan': '选择方案',
    'start_upgrade': '开始升级',
    'complete_upgrade': '完成升级',
    'waiting_for_votes': '等待投票',
    'vote_complete': '投票完成',
    'vote_rules': '投票规则',
    'feature': '功能',
    'discount': '折扣',
    // 家庭邀请
    'invite_family': '邀请家人',
    'create_family_ledger': '创建家庭账本',
    'qr_code_invite': '二维码邀请',
    'show_qr_code': '显示二维码',
    'scan_to_join': '扫码加入',
    'send_invite_link': '发送邀请链接',
    'share_link': '分享链接',
    'copy_link': '复制链接',
    // 安全设置
    'security_settings': '安全设置',
    'security_log': '安全日志',
    'app_lock': '应用锁',
    'set_pin': '设置PIN码',
    'fingerprint_unlock': '指纹解锁',
    'face_id_unlock': '面容解锁',
    'prevent_screenshot': '防止截屏',
    'privacy_mode': '隐私模式',
    'push_notification': '推送通知',
    'auto_sync': '自动同步',
    'auto_sync_desc': '数据自动同步到云端',
    // 数据管理
    'data_management': '数据管理',
    'save_changes': '保存更改',
    'view_stats': '查看统计',
    'detailed_stats': '详细统计',
    'get_suggestion': '获取建议',
    'savings_goals': '储蓄目标',
    'annual_review': '年度回顾',
    'weekly_report': '周报',
    // 区域设置
    'region_settings': '区域设置',
    'date_format': '日期格式',
    'time_format': '时间格式',
    'number_format': '数字格式',
    'week_start_day': '每周起始日',
    // 收据
    'receipt_detail': '收据详情',
    'subtotal': '小计',
    'remaining_amount': '剩余金额',
    // 帮助
    'faq': '常见问题',
    'add_note': '添加备注',
  };

  // 繁体中文
  static const Map<String, String> _zhTW = {
    'app_name': 'AI智能記帳',
    'confirm': '確認',
    'cancel': '取消',
    'save': '儲存',
    'delete': '刪除',
    'edit': '編輯',
    'add': '新增',
    'close': '關閉',
    'loading': '載入中...',
    'error': '錯誤',
    'success': '成功',
    'warning': '警告',
    'no_data': '暫無資料',
    'retry': '重試',
    'home': '首頁',
    'statistics': '統計',
    'add_record': '記帳',
    'budget': '預算',
    'settings': '我的',
    'expense': '支出',
    'income': '收入',
    'transfer': '轉帳',
    'amount': '金額',
    'category': '分類',
    'account': '帳戶',
    'date': '日期',
    'note': '備註',
    'enter_amount': '請輸入金額',
    'select_category': '選擇分類',
    'select_account': '選擇帳戶',
    'total_income': '總收入',
    'total_expense': '總支出',
    'balance': '結餘',
    'daily': '日',
    'weekly': '週',
    'monthly': '月',
    'yearly': '年',
    'profile': '個人資料',
    'language': '語言',
    'currency': '貨幣',
    'theme': '主題',
    'dark_mode': '深色模式',
    'light_mode': '淺色模式',
    'system_mode': '跟隨系統',
    'data_backup': '資料備份',
    'data_export': '資料匯出',
    'data_import': '資料匯入',
    'about': '關於',
    'logout': '登出',
    'login': '登入',
    'register': '註冊',
    'cash': '現金',
    'bank_card': '銀行卡',
    'credit_card': '信用卡',
    'e_wallet': '電子錢包',
    'account_balance': '帳戶餘額',
    'budget_management': '預算管理',
    'monthly_budget': '月度預算',
    'category_budget': '分類預算',
    'budget_remaining': '剩餘預算',
    'budget_exceeded': '已超支',
    'currency_settings': '貨幣設定',
    'default_currency': '預設貨幣',
    'show_currency_symbol': '顯示貨幣符號',
    'language_settings': '語言設定',
    'follow_system': '跟隨系統',
    // AA分摊
    'aa_split': 'AA分攤',
    'aa_detected': '偵測到AA消費',
    'total_amount': '總金額',
    'split_people': '分攤人數',
    'auto_detected': '自動偵測',
    'my_share': '我的份額',
    'per_person': '人均',
    'bookkeeping_mode': '記帳模式',
    'only_my_share': '只記我的份額',
    'record_total': '記錄全部',
    'confirm_split': '確認分攤',
    'split_method': '分攤方式',
    'even_split': '平均分攤',
    'proportional_split': '按比例分攤',
    'custom_split': '自定義分攤',
    'your_share': '你的份額',
    // 無障礙設置
    'accessibility_settings': '無障礙設定',
    'font_size': '字體大小',
    'high_contrast': '高對比度',
    'bold_text': '粗體文字',
    'reduce_motion': '減少動畫',
    'screen_reader': '螢幕閱讀器支援',
    'large_touch_target': '大觸控區域',
    'large_touch': '大觸控',
    // 智能建議
    'smart_advice': '智能建議',
    'today_advice': '今日建議',
    'manage_advice_preference': '管理建議偏好',
    // AI語言設置
    'ai_language_settings': 'AI語言設定',
    'ai_reply_language': 'AI回覆語言',
    'voice_recognition_language': '語音識別語言',
    'ai_learning_curve': 'AI學習曲線',
    'ai_voice': 'AI語音',
    'male_voice': '男聲',
    'female_voice': '女聲',
    // 應用設置
    'app_lock_settings': '應用鎖設定',
    'batch_train_ai': '批量訓練AI',
    // 家庭功能
    'family_leaderboard': '家庭排行榜',
    'weekly_ranking': '本週排名',
    'monthly_ranking': '本月排名',
    'savings_champion': '儲蓄冠軍',
    'budget_master': '預算達人',
    'family_savings_goal': '家庭儲蓄目標',
    'contribute_now': '立即貢獻',
    'goal_amount': '目標金額',
    'current_progress': '當前進度',
    'days_remaining': '剩餘天數',
    // 帳本設置
    'ledger_settings': '帳本設定',
    'default_ledger': '預設帳本',
    'ledger_name': '帳本名稱',
    'ledger_icon': '帳本圖示',
    'ledger_color': '帳本顏色',
    'archive_ledger': '歸檔帳本',
    // 位置服務
    'location_services': '位置服務',
    'enable_location': '啟用位置',
    'location_accuracy': '定位精度',
    'high_accuracy': '高精度',
    'low_power': '低功耗',
    'geofence_alerts': '地理圍欄提醒',
    'nearby_merchants': '附近商家',
    // 交易相關
    'duplicate_transaction': '複製交易',
    'transaction_time': '交易時間',
    'transaction_note': '交易備註',
    'transaction_tags': '交易標籤',
    'transaction_location': '交易位置',
    'transaction_attachments': '交易附件',
    // 錢齡分析
    'money_age_title': '錢齡分析',
    'money_age_description2': '了解你的資金周轉效率',
    'average_money_age': '平均錢齡',
    'money_age_health': '錢齡健康度',
    'poor': '較差',
    // 習慣追蹤
    'habit_tracking': '習慣追蹤',
    'daily_streak': '連續記帳',
    'weekly_goal': '每週目標',
    'monthly_goal': '每月目標',
    // 成就系統
    'achievement_unlocked': '成就解鎖',
    'view_achievements': '查看成就',
    'share_achievement': '分享成就',
    'achievement_progress': '成就進度',
    // 語音相關
    'listening': '正在聆聽...',
    'voice_error': '語音識別失敗',
    'speak_now': '請說話',
    // 掃描相關
    'scan_bill': '掃描帳單',
    'recognizing': '識別中...',
    'recognition_failed': '識別失敗',
    // 同步相關
    'syncing': '同步中...',
    'sync_complete': '同步完成',
    'sync_failed': '同步失敗',
    'last_synced': '上次同步',
    'sync_now': '立即同步',
    // 離線模式
    'offline_mode': '離線模式',
    'offline_data': '離線資料',
    'pending_sync': '待同步',
    'offline_changes': '離線更改',
    // 隱私設置
    'privacy_settings': '隱私設定',
    'data_encryption': '資料加密',
    'biometric_lock': '生物識別鎖',
    'auto_lock': '自動鎖定',
    'lock_timeout': '鎖定逾時',
    // 預算提醒
    'budget_warning': '預算預警',
    'budget_alerts': '預算提醒',
    'daily_reminder': '每日提醒',
    // 匯出格式
    'export_format': '匯出格式',
    'csv_format': 'CSV格式',
    'excel_format': 'Excel格式',
    'json_format': 'JSON格式',
    // 回饋相關
    'feedback_submitted': '回饋已提交',
    'thank_you_feedback': '感謝您的回饋',
    'rate_app': '給應用評分',
    'share_app': '分享應用',
    // 登入相關
    'upgrade_required': '需要升級',
    'login_required': '需要登入',
    'login_to_use_feature': '登入後可使用此功能',
    'login_now': '立即登入',
    'continue_as_guest': '以訪客身份繼續',
    // 網路相關
    'connection_failed': '連線失敗',
    'check_network': '請檢查網路連線',
    // 權限相關
    'permission_required': '需要權限',
    'location_permission': '位置權限',
    'storage_permission': '儲存權限',
    // 刪除相關
    'delete_warning': '此操作無法撤銷',
    'permanently_delete': '永久刪除',
    'move_to_trash': '移至回收站',
    // 搜尋相關
    'search_placeholder': '搜尋...',
    'no_results': '無結果',
    'search_history': '搜尋歷史',
    'clear_history': '清除歷史',
    // 篩選排序
    'filter_by': '篩選',
    'sort_by': '排序',
    'date_range': '日期範圍',
    'amount_range': '金額範圍',
    'category_filter': '分類篩選',
    'ascending': '升序',
    'descending': '降序',
    'by_date': '按日期',
    'by_amount': '按金額',
    'by_category': '按分類',
    // 批量操作
    'select_all': '全選',
    'deselect_all': '取消全選',
    'selected': '已選擇',
    'batch_delete': '批量刪除',
    'batch_edit': '批量編輯',
    // 操作相關
    'redo': '重做',
    'action_undone': '操作已撤銷',
    'action_redone': '操作已重做',
    // 載入相關
    'load_more': '載入更多',
    'refreshing': '重新整理中...',
    'pull_to_refresh': '下拉重新整理',
    'release_to_refresh': '釋放重新整理',
    // 空狀態
    'empty_state': '暫無資料',
    'add_first': '新增第一筆記錄',
    // 問候語
    'welcome_back': '歡迎回來',
    'good_morning': '早安',
    'good_afternoon': '午安',
    'good_evening': '晚安',
    // 快捷操作
    'frequent_categories': '常用分類',
    'suggested_actions': '建議操作',
    // 資料匯入匯出
    'import_data': '匯入資料',
    'export_data': '匯出資料',
    // 財務自由模擬器
    'financial_freedom_simulator': '財務自由模擬器',
    'your_financial_freedom_journey': '你的財務自由之旅',
    'estimated_time': '預計時間',
    'to_achieve_freedom': '達成財務自由',
    'accelerate_tip': '加速建議',
    'adjust_parameters': '調整參數',
    'monthly_savings': '月儲蓄額',
    'annual_return': '年化收益率',
    'target_passive_income': '目標被動收入',
    'disclaimer': '僅供參考，不構成理財建議',
    // 家庭年度回顧
    'days_recording': '天記錄',
    'family_dinners': '家庭聚餐',
    'trips_count': '出行次數',
    'warmest_moment': '最溫暖時刻',
    'biggest_goal': '最大目標',
    'shared_time': '共度時光',
    'yearly_warm_moments': '年度溫暖時刻',
    'family_contributions': '家庭貢獻',
    'save_image': '儲存圖片',
    'share_to_family': '分享給家人',
    // 家庭生日
    'education': '教育',
    'hobbies': '愛好',
    'growth': '成長',
    'generate_birthday_card': '生成生日賀卡',
    // 家庭排行榜
    'record_leaderboard': '記錄排行榜',
    'savings_leaderboard': '儲蓄排行榜',
    'badges_wall': '徽章牆',
    'leaderboard': '排行榜',
    // 家庭儲蓄目標
    'member_contribution': '成員貢獻',
    'other_savings_goals': '其他儲蓄目標',
    'recent_deposits': '最近存款',
    'deposit_now': '立即存入',
    // 家庭簡易模式
    'simple_mode': '簡易模式',
    'monthly_shared_expense': '月度共享支出',
    'recent_records': '最近記錄',
    'view_all': '查看全部',
    'upgrade_to_full_mode': '升級到完整模式',
    'full_mode': '完整模式',
    'stay_simple': '保持簡潔',
    // 地理圍欄
    'geofence_reminder': '地理圍欄提醒',
    // 首頁佈局
    'home_layout': '首頁佈局',
    'reset': '重置',
    // 帳本設置擴展
    'ledger_type': '帳本類型',
    'default_visibility': '預設可見性',
    'visibility_desc': '設置預設的可見性範圍',
    'hide_amount': '隱藏金額',
    'hide_amount_desc': '在列表中隱藏金額顯示',
    'notification_settings': '通知設定',
    'member_record_notify': '成員記帳通知',
    'budget_overflow_alert': '預算超支提醒',
    'danger_zone': '危險區域',
    'leave_ledger': '離開帳本',
    'delete_ledger': '刪除帳本',
    'only_owner_can_delete': '僅所有者可刪除',
    // 位置分析
    'location_analysis': '位置分析',
    'precise_location_service': '精準定位服務',
    'resident_locations': '常駐位置',
    'location_analysis_report': '位置分析報告',
    'remote_spending_record': '異地消費記錄',
    'data_security_guarantee': '資料安全保障',
    // 會員權限
    'member': '成員',
    'member_benefits': '會員權益',
    'member_desc': '成員權限說明',
    'member_permissions': '成員權限',
    'membership_service': '會員服務',
    'member_vote_status': '成員投票狀態',
    'admin': '管理員',
    'admin_desc': '管理員權限說明',
    'owner': '所有者',
    'owner_desc': '所有者權限說明',
    'viewer': '查看者',
    'viewer_desc': '查看者權限說明',
    'current_permissions': '當前權限',
    'permission_settings': '權限設定',
    'select_role': '選擇角色',
    'role_recommendation': '角色推薦',
    // 離線模式擴展
    'offline_mode_active': '離線模式已啟用',
    'offline_mode_desc': '離線模式說明',
    'offline_mode_full_desc': '離線模式下資料儲存在本地，聯網後自動同步',
    'offline_voice': '離線語音',
    'offline_voice_desc': '支援離線語音識別',
    'online': '在線',
    'network_unavailable': '網路不可用',
    'retry_network': '重試網路',
    'retry_online': '重新連網',
    'continue_offline': '繼續離線使用',
    'use_offline': '離線使用',
    // 智慧功能
    'smart_recommendation': '智慧推薦',
    'discover_new_feature': '發現新功能',
    'later_remind': '稍後提醒',
    'ai_parsing': 'AI解析',
    'ai_parsing_offline_desc': '離線模式下AI解析不可用',
    'analyzing': '分析中...',
    'confidence_level': '置信度',
    'low_confidence_title': '低置信度',
    'recognition_result': '識別結果',
    'auto_extracted': '自動提取',
    'original_text': '原始文字',
    // 語音助手
    'voice_assistant': '語音助手',
    'voice_chat': '語音聊天',
    'voice_history_title': '語音歷史',
    'voice_history_hint': '查看歷史語音記錄',
    'no_voice_history': '暫無語音歷史',
    'type_or_speak': '輸入或說話',
    'ask_anything': '問我任何問題',
    'you_can_ask': '你可以問我',
    'examples': '示例',
    'quick_questions': '快捷問題',
    'continue_asking': '繼續提問',
    'continuous_chat': '連續對話',
    // 自然語言輸入
    'natural_language_input': '自然語言輸入',
    'smart_text_input': '智慧文字輸入',
    'input_hint': '輸入提示',
    'input_to_bookkeep': '輸入記帳',
    'quick_bookkeep': '快速記帳',
    'quick_bookkeeping': '快捷記帳',
    'confirm_bookkeeping': '確認記帳',
    'basic_recording': '基礎記錄',
    // 預算查詢
    'budget_query': '預算查詢',
    'budget_overspent_alert': '預算已超支',
    'money_age_query': '錢齡查詢',
    // 帳單提醒
    'bill_due_reminder': '帳單到期提醒',
    'remind': '提醒',
    // 升級功能
    'upgrade_mode': '升級模式',
    'upgrade_notice': '升級通知',
    'upgrade_notice_desc': '有新版本可用',
    'upgrade_description': '升級說明',
    'upgrade_vote': '升級投票',
    'choose_plan': '選擇方案',
    'start_upgrade': '開始升級',
    'complete_upgrade': '完成升級',
    'waiting_for_votes': '等待投票',
    'vote_complete': '投票完成',
    'vote_rules': '投票規則',
    'feature': '功能',
    'discount': '折扣',
    // 家庭邀請
    'invite_family': '邀請家人',
    'create_family_ledger': '建立家庭帳本',
    'qr_code_invite': '二維碼邀請',
    'show_qr_code': '顯示二維碼',
    'scan_to_join': '掃碼加入',
    'send_invite_link': '發送邀請連結',
    'share_link': '分享連結',
    'copy_link': '複製連結',
    // 安全設定
    'security_settings': '安全設定',
    'security_log': '安全日誌',
    'app_lock': '應用鎖',
    'set_pin': '設定PIN碼',
    'fingerprint_unlock': '指紋解鎖',
    'face_id_unlock': '面容解鎖',
    'prevent_screenshot': '防止截圖',
    'privacy_mode': '隱私模式',
    'push_notification': '推送通知',
    'auto_sync': '自動同步',
    'auto_sync_desc': '資料自動同步到雲端',
    // 資料管理
    'data_management': '資料管理',
    'save_changes': '儲存變更',
    'view_stats': '查看統計',
    'detailed_stats': '詳細統計',
    'get_suggestion': '取得建議',
    'savings_goals': '儲蓄目標',
    'annual_review': '年度回顧',
    'weekly_report': '週報',
    // 區域設定
    'region_settings': '區域設定',
    'date_format': '日期格式',
    'time_format': '時間格式',
    'number_format': '數字格式',
    'week_start_day': '每週起始日',
    // 收據
    'receipt_detail': '收據詳情',
    'subtotal': '小計',
    'remaining_amount': '剩餘金額',
    // 說明
    'faq': '常見問題',
    'add_note': '新增備註',
  };

  // 英语
  static const Map<String, String> _en = {
    'app_name': 'AI Bookkeeping',
    'confirm': 'Confirm',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'add': 'Add',
    'close': 'Close',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'warning': 'Warning',
    'no_data': 'No Data',
    'retry': 'Retry',
    'home': 'Home',
    'statistics': 'Statistics',
    'add_record': 'Add',
    'budget': 'Budget',
    'settings': 'Settings',
    'expense': 'Expense',
    'income': 'Income',
    'transfer': 'Transfer',
    'amount': 'Amount',
    'category': 'Category',
    'account': 'Account',
    'date': 'Date',
    'note': 'Note',
    'enter_amount': 'Enter amount',
    'select_category': 'Select category',
    'select_account': 'Select account',
    'total_income': 'Total Income',
    'total_expense': 'Total Expense',
    'balance': 'Balance',
    'daily': 'Daily',
    'weekly': 'Weekly',
    'monthly': 'Monthly',
    'yearly': 'Yearly',
    'profile': 'Profile',
    'language': 'Language',
    'currency': 'Currency',
    'theme': 'Theme',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'system_mode': 'System',
    'data_backup': 'Backup',
    'data_export': 'Export',
    'data_import': 'Import',
    'about': 'About',
    'logout': 'Logout',
    'login': 'Login',
    'register': 'Register',
    'cash': 'Cash',
    'bank_card': 'Bank Card',
    'credit_card': 'Credit Card',
    'e_wallet': 'E-Wallet',
    'account_balance': 'Balance',
    'budget_management': 'Budget',
    'monthly_budget': 'Monthly Budget',
    'category_budget': 'Category Budget',
    'budget_remaining': 'Remaining',
    'budget_exceeded': 'Exceeded',
    'currency_settings': 'Currency Settings',
    'default_currency': 'Default Currency',
    'show_currency_symbol': 'Show Symbol',
    'language_settings': 'Language Settings',
    'follow_system': 'Follow System',
    // AA Split
    'aa_split': 'Split Bill',
    'aa_detected': 'Split expense detected',
    'total_amount': 'Total Amount',
    'split_people': 'Split People',
    'auto_detected': 'Auto Detected',
    'my_share': 'My Share',
    'per_person': 'Per Person',
    'bookkeeping_mode': 'Bookkeeping Mode',
    'only_my_share': 'Only My Share',
    'record_total': 'Record Total',
    'confirm_split': 'Confirm Split',
    'split_method': 'Split Method',
    'even_split': 'Even Split',
    'proportional_split': 'Proportional Split',
    'custom_split': 'Custom Split',
    'your_share': 'Your Share',
    // Accessibility Settings
    'accessibility_settings': 'Accessibility Settings',
    'font_size': 'Font Size',
    'high_contrast': 'High Contrast',
    'bold_text': 'Bold Text',
    'reduce_motion': 'Reduce Motion',
    'screen_reader': 'Screen Reader Support',
    'large_touch_target': 'Large Touch Targets',
    'large_touch': 'Large Touch',
    // Smart Advice
    'smart_advice': 'Smart Advice',
    'today_advice': 'Today\'s Advice',
    'manage_advice_preference': 'Manage Advice Preferences',
    // AI Language Settings
    'ai_language_settings': 'AI Language Settings',
    'ai_reply_language': 'AI Reply Language',
    'voice_recognition_language': 'Voice Recognition Language',
    'ai_learning_curve': 'AI Learning Curve',
    'ai_voice': 'AI Voice',
    'male_voice': 'Male Voice',
    'female_voice': 'Female Voice',
    // App Settings
    'app_lock_settings': 'App Lock Settings',
    'batch_train_ai': 'Batch Train AI',
    // Family Features
    'family_leaderboard': 'Family Leaderboard',
    'weekly_ranking': 'Weekly Ranking',
    'monthly_ranking': 'Monthly Ranking',
    'savings_champion': 'Savings Champion',
    'budget_master': 'Budget Master',
    'family_savings_goal': 'Family Savings Goal',
    'contribute_now': 'Contribute Now',
    'goal_amount': 'Goal Amount',
    'current_progress': 'Current Progress',
    'days_remaining': 'Days Remaining',
    // Ledger Settings
    'ledger_settings': 'Ledger Settings',
    'default_ledger': 'Default Ledger',
    'ledger_name': 'Ledger Name',
    'ledger_icon': 'Ledger Icon',
    'ledger_color': 'Ledger Color',
    'archive_ledger': 'Archive Ledger',
    // Location Services
    'location_services': 'Location Services',
    'enable_location': 'Enable Location',
    'location_accuracy': 'Location Accuracy',
    'high_accuracy': 'High Accuracy',
    'low_power': 'Low Power',
    'geofence_alerts': 'Geofence Alerts',
    'nearby_merchants': 'Nearby Merchants',
    // Transaction Related
    'duplicate_transaction': 'Duplicate Transaction',
    'transaction_time': 'Transaction Time',
    'transaction_note': 'Transaction Note',
    'transaction_tags': 'Transaction Tags',
    'transaction_location': 'Transaction Location',
    'transaction_attachments': 'Transaction Attachments',
    // Money Age Analysis
    'money_age_title': 'Money Age Analysis',
    'money_age_description2': 'Understand your cash flow efficiency',
    'average_money_age': 'Average Money Age',
    'money_age_health': 'Money Age Health',
    'poor': 'Poor',
    // Habit Tracking
    'habit_tracking': 'Habit Tracking',
    'daily_streak': 'Daily Streak',
    'weekly_goal': 'Weekly Goal',
    'monthly_goal': 'Monthly Goal',
    // Achievement System
    'achievement_unlocked': 'Achievement Unlocked',
    'view_achievements': 'View Achievements',
    'share_achievement': 'Share Achievement',
    'achievement_progress': 'Achievement Progress',
    // Voice Related
    'listening': 'Listening...',
    'voice_error': 'Voice recognition failed',
    'speak_now': 'Speak now',
    // Scan Related
    'scan_bill': 'Scan Bill',
    'recognizing': 'Recognizing...',
    'recognition_failed': 'Recognition Failed',
    // Sync Related
    'syncing': 'Syncing...',
    'sync_complete': 'Sync Complete',
    'sync_failed': 'Sync Failed',
    'last_synced': 'Last Synced',
    'sync_now': 'Sync Now',
    // Offline Mode
    'offline_mode': 'Offline Mode',
    'offline_data': 'Offline Data',
    'pending_sync': 'Pending Sync',
    'offline_changes': 'Offline Changes',
    // Privacy Settings
    'privacy_settings': 'Privacy Settings',
    'data_encryption': 'Data Encryption',
    'biometric_lock': 'Biometric Lock',
    'auto_lock': 'Auto Lock',
    'lock_timeout': 'Lock Timeout',
    // Budget Alerts
    'budget_warning': 'Budget Warning',
    'budget_alerts': 'Budget Alerts',
    'daily_reminder': 'Daily Reminder',
    // Export Format
    'export_format': 'Export Format',
    'csv_format': 'CSV Format',
    'excel_format': 'Excel Format',
    'json_format': 'JSON Format',
    // Feedback Related
    'feedback_submitted': 'Feedback Submitted',
    'thank_you_feedback': 'Thank you for your feedback',
    'rate_app': 'Rate App',
    'share_app': 'Share App',
    // Login Related
    'upgrade_required': 'Upgrade Required',
    'login_required': 'Login Required',
    'login_to_use_feature': 'Login to use this feature',
    'login_now': 'Login Now',
    'continue_as_guest': 'Continue as Guest',
    // Network Related
    'connection_failed': 'Connection Failed',
    'check_network': 'Please check your network connection',
    // Permission Related
    'permission_required': 'Permission Required',
    'location_permission': 'Location Permission',
    'storage_permission': 'Storage Permission',
    // Delete Related
    'delete_warning': 'This action cannot be undone',
    'permanently_delete': 'Permanently Delete',
    'move_to_trash': 'Move to Trash',
    // Search Related
    'search_placeholder': 'Search...',
    'no_results': 'No Results',
    'search_history': 'Search History',
    'clear_history': 'Clear History',
    // Filter and Sort
    'filter_by': 'Filter',
    'sort_by': 'Sort',
    'date_range': 'Date Range',
    'amount_range': 'Amount Range',
    'category_filter': 'Category Filter',
    'ascending': 'Ascending',
    'descending': 'Descending',
    'by_date': 'By Date',
    'by_amount': 'By Amount',
    'by_category': 'By Category',
    // Batch Operations
    'select_all': 'Select All',
    'deselect_all': 'Deselect All',
    'selected': 'Selected',
    'batch_delete': 'Batch Delete',
    'batch_edit': 'Batch Edit',
    // Action Related
    'redo': 'Redo',
    'action_undone': 'Action Undone',
    'action_redone': 'Action Redone',
    // Loading Related
    'load_more': 'Load More',
    'refreshing': 'Refreshing...',
    'pull_to_refresh': 'Pull to Refresh',
    'release_to_refresh': 'Release to Refresh',
    // Empty State
    'empty_state': 'No Data',
    'add_first': 'Add First Record',
    // Greetings
    'welcome_back': 'Welcome Back',
    'good_morning': 'Good Morning',
    'good_afternoon': 'Good Afternoon',
    'good_evening': 'Good Evening',
    // Quick Actions
    'frequent_categories': 'Frequent Categories',
    'suggested_actions': 'Suggested Actions',
    // Import Export
    'import_data': 'Import Data',
    'export_data': 'Export Data',
    // Financial Freedom Simulator
    'financial_freedom_simulator': 'Financial Freedom Simulator',
    'your_financial_freedom_journey': 'Your Financial Freedom Journey',
    'estimated_time': 'Estimated Time',
    'to_achieve_freedom': 'To Achieve Freedom',
    'accelerate_tip': 'Accelerate Tip',
    'adjust_parameters': 'Adjust Parameters',
    'monthly_savings': 'Monthly Savings',
    'annual_return': 'Annual Return',
    'target_passive_income': 'Target Passive Income',
    'disclaimer': 'For reference only, not financial advice',
    // Family Annual Review
    'days_recording': 'Days Recording',
    'family_dinners': 'Family Dinners',
    'trips_count': 'Trips Count',
    'warmest_moment': 'Warmest Moment',
    'biggest_goal': 'Biggest Goal',
    'shared_time': 'Shared Time',
    'yearly_warm_moments': 'Yearly Warm Moments',
    'family_contributions': 'Family Contributions',
    'save_image': 'Save Image',
    'share_to_family': 'Share to Family',
    // Family Birthday
    'education': 'Education',
    'hobbies': 'Hobbies',
    'growth': 'Growth',
    'generate_birthday_card': 'Generate Birthday Card',
    // Family Leaderboard
    'record_leaderboard': 'Record Leaderboard',
    'savings_leaderboard': 'Savings Leaderboard',
    'badges_wall': 'Badges Wall',
    'leaderboard': 'Leaderboard',
    // Family Savings Goal
    'member_contribution': 'Member Contribution',
    'other_savings_goals': 'Other Savings Goals',
    'recent_deposits': 'Recent Deposits',
    'deposit_now': 'Deposit Now',
    // Family Simple Mode
    'simple_mode': 'Simple Mode',
    'monthly_shared_expense': 'Monthly Shared Expense',
    'recent_records': 'Recent Records',
    'view_all': 'View All',
    'upgrade_to_full_mode': 'Upgrade to Full Mode',
    'full_mode': 'Full Mode',
    'stay_simple': 'Stay Simple',
    // Geofence
    'geofence_reminder': 'Geofence Reminder',
    // Home Layout
    'home_layout': 'Home Layout',
    'reset': 'Reset',
    // Ledger Settings Extended
    'ledger_type': 'Ledger Type',
    'default_visibility': 'Default Visibility',
    'visibility_desc': 'Set default visibility scope',
    'hide_amount': 'Hide Amount',
    'hide_amount_desc': 'Hide amount display in list',
    'notification_settings': 'Notification Settings',
    'member_record_notify': 'Member Record Notification',
    'budget_overflow_alert': 'Budget Overflow Alert',
    'danger_zone': 'Danger Zone',
    'leave_ledger': 'Leave Ledger',
    'delete_ledger': 'Delete Ledger',
    'only_owner_can_delete': 'Only owner can delete',
    // Location Analysis
    'location_analysis': 'Location Analysis',
    'precise_location_service': 'Precise Location Service',
    'resident_locations': 'Resident Locations',
    'location_analysis_report': 'Location Analysis Report',
    'remote_spending_record': 'Remote Spending Record',
    'data_security_guarantee': 'Data Security Guarantee',
    // Member Permissions
    'member': 'Member',
    'member_benefits': 'Member Benefits',
    'member_desc': 'Member permission description',
    'member_permissions': 'Member Permissions',
    'membership_service': 'Membership Service',
    'member_vote_status': 'Member Vote Status',
    'admin': 'Admin',
    'admin_desc': 'Admin permission description',
    'owner': 'Owner',
    'owner_desc': 'Owner permission description',
    'viewer': 'Viewer',
    'viewer_desc': 'Viewer permission description',
    'current_permissions': 'Current Permissions',
    'permission_settings': 'Permission Settings',
    'select_role': 'Select Role',
    'role_recommendation': 'Role Recommendation',
    // Offline Mode Extended
    'offline_mode_active': 'Offline Mode Active',
    'offline_mode_desc': 'Offline mode description',
    'offline_mode_full_desc': 'In offline mode, data is stored locally and synced when online',
    'offline_voice': 'Offline Voice',
    'offline_voice_desc': 'Offline voice recognition supported',
    'online': 'Online',
    'network_unavailable': 'Network Unavailable',
    'retry_network': 'Retry Network',
    'retry_online': 'Retry Online',
    'continue_offline': 'Continue Offline',
    'use_offline': 'Use Offline',
    // Smart Features
    'smart_recommendation': 'Smart Recommendation',
    'discover_new_feature': 'Discover New Feature',
    'later_remind': 'Remind Later',
    'ai_parsing': 'AI Parsing',
    'ai_parsing_offline_desc': 'AI parsing unavailable in offline mode',
    'analyzing': 'Analyzing...',
    'confidence_level': 'Confidence Level',
    'low_confidence_title': 'Low Confidence',
    'recognition_result': 'Recognition Result',
    'auto_extracted': 'Auto Extracted',
    'original_text': 'Original Text',
    // Voice Assistant
    'voice_assistant': 'Voice Assistant',
    'voice_chat': 'Voice Chat',
    'voice_history_title': 'Voice History',
    'voice_history_hint': 'View voice history records',
    'no_voice_history': 'No Voice History',
    'type_or_speak': 'Type or Speak',
    'ask_anything': 'Ask Anything',
    'you_can_ask': 'You Can Ask',
    'examples': 'Examples',
    'quick_questions': 'Quick Questions',
    'continue_asking': 'Continue Asking',
    'continuous_chat': 'Continuous Chat',
    // Natural Language Input
    'natural_language_input': 'Natural Language Input',
    'smart_text_input': 'Smart Text Input',
    'input_hint': 'Input Hint',
    'input_to_bookkeep': 'Input to Bookkeep',
    'quick_bookkeep': 'Quick Bookkeep',
    'quick_bookkeeping': 'Quick Bookkeeping',
    'confirm_bookkeeping': 'Confirm Bookkeeping',
    'basic_recording': 'Basic Recording',
    // Budget Query
    'budget_query': 'Budget Query',
    'budget_overspent_alert': 'Budget Overspent',
    'money_age_query': 'Money Age Query',
    // Bill Reminder
    'bill_due_reminder': 'Bill Due Reminder',
    'remind': 'Remind',
    // Upgrade Features
    'upgrade_mode': 'Upgrade Mode',
    'upgrade_notice': 'Upgrade Notice',
    'upgrade_notice_desc': 'New version available',
    'upgrade_description': 'Upgrade Description',
    'upgrade_vote': 'Upgrade Vote',
    'choose_plan': 'Choose Plan',
    'start_upgrade': 'Start Upgrade',
    'complete_upgrade': 'Complete Upgrade',
    'waiting_for_votes': 'Waiting for Votes',
    'vote_complete': 'Vote Complete',
    'vote_rules': 'Vote Rules',
    'feature': 'Feature',
    'discount': 'Discount',
    // Family Invite
    'invite_family': 'Invite Family',
    'create_family_ledger': 'Create Family Ledger',
    'qr_code_invite': 'QR Code Invite',
    'show_qr_code': 'Show QR Code',
    'scan_to_join': 'Scan to Join',
    'send_invite_link': 'Send Invite Link',
    'share_link': 'Share Link',
    'copy_link': 'Copy Link',
    // Security Settings
    'security_settings': 'Security Settings',
    'security_log': 'Security Log',
    'app_lock': 'App Lock',
    'set_pin': 'Set PIN',
    'fingerprint_unlock': 'Fingerprint Unlock',
    'face_id_unlock': 'Face ID Unlock',
    'prevent_screenshot': 'Prevent Screenshot',
    'privacy_mode': 'Privacy Mode',
    'push_notification': 'Push Notification',
    'auto_sync': 'Auto Sync',
    'auto_sync_desc': 'Automatically sync data to cloud',
    // Data Management
    'data_management': 'Data Management',
    'save_changes': 'Save Changes',
    'view_stats': 'View Stats',
    'detailed_stats': 'Detailed Stats',
    'get_suggestion': 'Get Suggestion',
    'savings_goals': 'Savings Goals',
    'annual_review': 'Annual Review',
    'weekly_report': 'Weekly Report',
    // Region Settings
    'region_settings': 'Region Settings',
    'date_format': 'Date Format',
    'time_format': 'Time Format',
    'number_format': 'Number Format',
    'week_start_day': 'Week Start Day',
    // Receipt
    'receipt_detail': 'Receipt Detail',
    'subtotal': 'Subtotal',
    'remaining_amount': 'Remaining Amount',
    // Help
    'faq': 'FAQ',
    'add_note': 'Add Note',
  };

  // 日语
  static const Map<String, String> _ja = {
    'app_name': 'AI家計簿',
    'confirm': '確認',
    'cancel': 'キャンセル',
    'save': '保存',
    'delete': '削除',
    'edit': '編集',
    'add': '追加',
    'close': '閉じる',
    'loading': '読み込み中...',
    'error': 'エラー',
    'success': '成功',
    'warning': '警告',
    'no_data': 'データなし',
    'retry': '再試行',
    'home': 'ホーム',
    'statistics': '統計',
    'add_record': '記録',
    'budget': '予算',
    'settings': '設定',
    'expense': '支出',
    'income': '収入',
    'transfer': '振替',
    'amount': '金額',
    'category': 'カテゴリ',
    'account': '口座',
    'date': '日付',
    'note': 'メモ',
    'enter_amount': '金額を入力',
    'select_category': 'カテゴリを選択',
    'select_account': '口座を選択',
    'total_income': '総収入',
    'total_expense': '総支出',
    'balance': '残高',
    'daily': '日',
    'weekly': '週',
    'monthly': '月',
    'yearly': '年',
    'profile': 'プロフィール',
    'language': '言語',
    'currency': '通貨',
    'theme': 'テーマ',
    'dark_mode': 'ダークモード',
    'light_mode': 'ライトモード',
    'system_mode': 'システム',
    'data_backup': 'バックアップ',
    'data_export': 'エクスポート',
    'data_import': 'インポート',
    'about': '情報',
    'logout': 'ログアウト',
    'login': 'ログイン',
    'register': '登録',
    'cash': '現金',
    'bank_card': '銀行カード',
    'credit_card': 'クレジットカード',
    'e_wallet': '電子マネー',
    'account_balance': '残高',
    'budget_management': '予算管理',
    'monthly_budget': '月間予算',
    'category_budget': 'カテゴリ予算',
    'budget_remaining': '残り予算',
    'budget_exceeded': '超過',
    'currency_settings': '通貨設定',
    'default_currency': 'デフォルト通貨',
    'show_currency_symbol': '記号を表示',
    'language_settings': '言語設定',
    'follow_system': 'システムに従う',
    // AA分割
    'aa_split': '割り勘',
    'aa_detected': '割り勘を検出',
    'total_amount': '合計金額',
    'split_people': '人数',
    'auto_detected': '自動検出',
    'my_share': '私の負担額',
    'per_person': '一人当たり',
    'bookkeeping_mode': '記帳モード',
    'only_my_share': '私の分のみ記録',
    'record_total': '全額記録',
    'confirm_split': '分割を確認',
    'split_method': '分割方法',
    'even_split': '均等分割',
    'proportional_split': '比例分割',
    'custom_split': 'カスタム分割',
    'your_share': 'あなたの負担額',
    // アクセシビリティ設定
    'accessibility_settings': 'アクセシビリティ設定',
    'font_size': 'フォントサイズ',
    'high_contrast': 'ハイコントラスト',
    'bold_text': '太字テキスト',
    'reduce_motion': 'モーションを減らす',
    'screen_reader': 'スクリーンリーダー対応',
    'large_touch_target': '大きなタッチターゲット',
    'large_touch': '大タッチ',
    // スマートアドバイス
    'smart_advice': 'スマートアドバイス',
    'today_advice': '今日のアドバイス',
    'manage_advice_preference': 'アドバイス設定を管理',
    // AI言語設定
    'ai_language_settings': 'AI言語設定',
    'ai_reply_language': 'AI応答言語',
    'voice_recognition_language': '音声認識言語',
    'ai_learning_curve': 'AI学習曲線',
    'ai_voice': 'AI音声',
    'male_voice': '男性の声',
    'female_voice': '女性の声',
    // アプリ設定
    'app_lock_settings': 'アプリロック設定',
    'batch_train_ai': 'AIを一括トレーニング',
    // 家族機能
    'family_leaderboard': '家族ランキング',
    'weekly_ranking': '週間ランキング',
    'monthly_ranking': '月間ランキング',
    'savings_champion': '貯蓄チャンピオン',
    'budget_master': '予算マスター',
    'family_savings_goal': '家族貯蓄目標',
    'contribute_now': '今すぐ貢献',
    'goal_amount': '目標金額',
    'current_progress': '現在の進捗',
    'days_remaining': '残り日数',
    // 帳簿設定
    'ledger_settings': '帳簿設定',
    'default_ledger': 'デフォルト帳簿',
    'ledger_name': '帳簿名',
    'ledger_icon': '帳簿アイコン',
    'ledger_color': '帳簿の色',
    'archive_ledger': '帳簿をアーカイブ',
    // 位置情報サービス
    'location_services': '位置情報サービス',
    'enable_location': '位置情報を有効にする',
    'location_accuracy': '位置精度',
    'high_accuracy': '高精度',
    'low_power': '省電力',
    'geofence_alerts': 'ジオフェンス通知',
    'nearby_merchants': '近くの店舗',
    // 取引関連
    'duplicate_transaction': '取引を複製',
    'transaction_time': '取引時間',
    'transaction_note': '取引メモ',
    'transaction_tags': '取引タグ',
    'transaction_location': '取引場所',
    'transaction_attachments': '取引添付ファイル',
    // マネーエイジ分析
    'money_age_title': 'マネーエイジ分析',
    'money_age_description2': 'キャッシュフロー効率を理解する',
    'average_money_age': '平均マネーエイジ',
    'money_age_health': 'マネーエイジ健康度',
    'poor': '不良',
    // 習慣トラッキング
    'habit_tracking': '習慣トラッキング',
    'daily_streak': '連続記録',
    'weekly_goal': '週間目標',
    'monthly_goal': '月間目標',
    // 実績システム
    'achievement_unlocked': '実績解除',
    'view_achievements': '実績を見る',
    'share_achievement': '実績を共有',
    'achievement_progress': '実績進捗',
    // 音声関連
    'listening': '聞いています...',
    'voice_error': '音声認識に失敗しました',
    'speak_now': '話してください',
    // スキャン関連
    'scan_bill': '請求書をスキャン',
    'recognizing': '認識中...',
    'recognition_failed': '認識に失敗しました',
    // 同期関連
    'syncing': '同期中...',
    'sync_complete': '同期完了',
    'sync_failed': '同期に失敗しました',
    'last_synced': '最終同期',
    'sync_now': '今すぐ同期',
    // オフラインモード
    'offline_mode': 'オフラインモード',
    'offline_data': 'オフラインデータ',
    'pending_sync': '同期待ち',
    'offline_changes': 'オフライン変更',
    // プライバシー設定
    'privacy_settings': 'プライバシー設定',
    'data_encryption': 'データ暗号化',
    'biometric_lock': '生体認証ロック',
    'auto_lock': '自動ロック',
    'lock_timeout': 'ロックタイムアウト',
    // 予算アラート
    'budget_warning': '予算警告',
    'budget_alerts': '予算アラート',
    'daily_reminder': '毎日のリマインダー',
    // エクスポート形式
    'export_format': 'エクスポート形式',
    'csv_format': 'CSV形式',
    'excel_format': 'Excel形式',
    'json_format': 'JSON形式',
    // フィードバック関連
    'feedback_submitted': 'フィードバックを送信しました',
    'thank_you_feedback': 'フィードバックありがとうございます',
    'rate_app': 'アプリを評価',
    'share_app': 'アプリを共有',
    // ログイン関連
    'upgrade_required': 'アップグレードが必要です',
    'login_required': 'ログインが必要です',
    'login_to_use_feature': 'この機能を使用するにはログインしてください',
    'login_now': '今すぐログイン',
    'continue_as_guest': 'ゲストとして続ける',
    // ネットワーク関連
    'connection_failed': '接続に失敗しました',
    'check_network': 'ネットワーク接続を確認してください',
    // 権限関連
    'permission_required': '権限が必要です',
    'location_permission': '位置情報の権限',
    'storage_permission': 'ストレージの権限',
    // 削除関連
    'delete_warning': 'この操作は取り消せません',
    'permanently_delete': '完全に削除',
    'move_to_trash': 'ゴミ箱に移動',
    // 検索関連
    'search_placeholder': '検索...',
    'no_results': '結果なし',
    'search_history': '検索履歴',
    'clear_history': '履歴をクリア',
    // フィルターと並べ替え
    'filter_by': 'フィルター',
    'sort_by': '並べ替え',
    'date_range': '日付範囲',
    'amount_range': '金額範囲',
    'category_filter': 'カテゴリフィルター',
    'ascending': '昇順',
    'descending': '降順',
    'by_date': '日付順',
    'by_amount': '金額順',
    'by_category': 'カテゴリ順',
    // バッチ操作
    'select_all': 'すべて選択',
    'deselect_all': '選択解除',
    'selected': '選択済み',
    'batch_delete': '一括削除',
    'batch_edit': '一括編集',
    // 操作関連
    'redo': 'やり直し',
    'action_undone': '操作を取り消しました',
    'action_redone': '操作をやり直しました',
    // 読み込み関連
    'load_more': 'もっと読み込む',
    'refreshing': '更新中...',
    'pull_to_refresh': '引き下げて更新',
    'release_to_refresh': '離して更新',
    // 空の状態
    'empty_state': 'データなし',
    'add_first': '最初の記録を追加',
    // 挨拶
    'welcome_back': 'おかえりなさい',
    'good_morning': 'おはようございます',
    'good_afternoon': 'こんにちは',
    'good_evening': 'こんばんは',
    // クイック操作
    'frequent_categories': 'よく使うカテゴリ',
    'suggested_actions': 'おすすめ操作',
    // インポートエクスポート
    'import_data': 'データをインポート',
    'export_data': 'データをエクスポート',
    // 財務自由シミュレーター
    'financial_freedom_simulator': '財務自由シミュレーター',
    'your_financial_freedom_journey': 'あなたの財務自由への旅',
    'estimated_time': '予想時間',
    'to_achieve_freedom': '財務自由達成まで',
    'accelerate_tip': '加速のヒント',
    'adjust_parameters': 'パラメーターを調整',
    'monthly_savings': '月間貯蓄',
    'annual_return': '年間収益率',
    'target_passive_income': '目標パッシブ収入',
    'disclaimer': '参考用であり、財務アドバイスではありません',
    // 家族年間レビュー
    'days_recording': '日間記録',
    'family_dinners': '家族の食事会',
    'trips_count': '旅行回数',
    'warmest_moment': '最も温かい瞬間',
    'biggest_goal': '最大の目標',
    'shared_time': '共有時間',
    'yearly_warm_moments': '年間の温かい瞬間',
    'family_contributions': '家族の貢献',
    'save_image': '画像を保存',
    'share_to_family': '家族に共有',
    // 家族の誕生日
    'education': '教育',
    'hobbies': '趣味',
    'growth': '成長',
    'generate_birthday_card': '誕生日カードを作成',
    // 家族ランキング
    'record_leaderboard': '記録ランキング',
    'savings_leaderboard': '貯蓄ランキング',
    'badges_wall': 'バッジウォール',
    'leaderboard': 'ランキング',
    // 家族貯蓄目標
    'member_contribution': 'メンバー貢献',
    'other_savings_goals': 'その他の貯蓄目標',
    'recent_deposits': '最近の預金',
    'deposit_now': '今すぐ預金',
    // 家族シンプルモード
    'simple_mode': 'シンプルモード',
    'monthly_shared_expense': '月間共有支出',
    'recent_records': '最近の記録',
    'view_all': 'すべて表示',
    'upgrade_to_full_mode': 'フルモードにアップグレード',
    'full_mode': 'フルモード',
    'stay_simple': 'シンプルに',
    // ジオフェンス
    'geofence_reminder': 'ジオフェンスリマインダー',
    // ホームレイアウト
    'home_layout': 'ホームレイアウト',
    'reset': 'リセット',
    // 帳簿設定拡張
    'ledger_type': '帳簿タイプ',
    'default_visibility': 'デフォルト公開範囲',
    'visibility_desc': 'デフォルトの公開範囲を設定',
    'hide_amount': '金額を非表示',
    'hide_amount_desc': 'リストで金額を非表示',
    'notification_settings': '通知設定',
    'member_record_notify': 'メンバー記録通知',
    'budget_overflow_alert': '予算オーバーアラート',
    'danger_zone': '危険ゾーン',
    'leave_ledger': '帳簿を離れる',
    'delete_ledger': '帳簿を削除',
    'only_owner_can_delete': 'オーナーのみ削除可能',
    // 位置分析
    'location_analysis': '位置分析',
    'precise_location_service': '精密位置サービス',
    'resident_locations': '居住地',
    'location_analysis_report': '位置分析レポート',
    'remote_spending_record': '遠隔支出記録',
    'data_security_guarantee': 'データセキュリティ保証',
    // メンバー権限
    'member': 'メンバー',
    'member_benefits': 'メンバー特典',
    'member_desc': 'メンバー権限の説明',
    'member_permissions': 'メンバー権限',
    'membership_service': 'メンバーシップサービス',
    'member_vote_status': 'メンバー投票状況',
    'admin': '管理者',
    'admin_desc': '管理者権限の説明',
    'owner': 'オーナー',
    'owner_desc': 'オーナー権限の説明',
    'viewer': '閲覧者',
    'viewer_desc': '閲覧者権限の説明',
    'current_permissions': '現在の権限',
    'permission_settings': '権限設定',
    'select_role': '役割を選択',
    'role_recommendation': '役割の推奨',
    // オフラインモード拡張
    'offline_mode_active': 'オフラインモード有効',
    'offline_mode_desc': 'オフラインモードの説明',
    'offline_mode_full_desc': 'オフラインモードではデータはローカルに保存され、オンライン時に同期されます',
    'offline_voice': 'オフライン音声',
    'offline_voice_desc': 'オフライン音声認識対応',
    'online': 'オンライン',
    'network_unavailable': 'ネットワーク利用不可',
    'retry_network': 'ネットワークを再試行',
    'retry_online': 'オンラインを再試行',
    'continue_offline': 'オフラインで続行',
    'use_offline': 'オフラインで使用',
    // スマート機能
    'smart_recommendation': 'スマート推奨',
    'discover_new_feature': '新機能を発見',
    'later_remind': '後でリマインド',
    'ai_parsing': 'AI解析',
    'ai_parsing_offline_desc': 'オフラインモードではAI解析は利用できません',
    'analyzing': '分析中...',
    'confidence_level': '信頼度',
    'low_confidence_title': '低信頼度',
    'recognition_result': '認識結果',
    'auto_extracted': '自動抽出',
    'original_text': '元のテキスト',
    // 音声アシスタント
    'voice_assistant': '音声アシスタント',
    'voice_chat': '音声チャット',
    'voice_history_title': '音声履歴',
    'voice_history_hint': '音声履歴を表示',
    'no_voice_history': '音声履歴なし',
    'type_or_speak': '入力または話す',
    'ask_anything': '何でも聞いてください',
    'you_can_ask': '質問できます',
    'examples': '例',
    'quick_questions': 'クイック質問',
    'continue_asking': '質問を続ける',
    'continuous_chat': '連続チャット',
    // 自然言語入力
    'natural_language_input': '自然言語入力',
    'smart_text_input': 'スマートテキスト入力',
    'input_hint': '入力ヒント',
    'input_to_bookkeep': '入力して記帳',
    'quick_bookkeep': 'クイック記帳',
    'quick_bookkeeping': 'クイック記帳',
    'confirm_bookkeeping': '記帳を確認',
    'basic_recording': '基本記録',
    // 予算クエリ
    'budget_query': '予算クエリ',
    'budget_overspent_alert': '予算超過',
    'money_age_query': 'マネーエイジクエリ',
    // 請求リマインダー
    'bill_due_reminder': '請求期限リマインダー',
    'remind': 'リマインド',
    // アップグレード機能
    'upgrade_mode': 'アップグレードモード',
    'upgrade_notice': 'アップグレード通知',
    'upgrade_notice_desc': '新しいバージョンが利用可能です',
    'upgrade_description': 'アップグレード説明',
    'upgrade_vote': 'アップグレード投票',
    'choose_plan': 'プランを選択',
    'start_upgrade': 'アップグレード開始',
    'complete_upgrade': 'アップグレード完了',
    'waiting_for_votes': '投票待ち',
    'vote_complete': '投票完了',
    'vote_rules': '投票ルール',
    'feature': '機能',
    'discount': '割引',
    // 家族招待
    'invite_family': '家族を招待',
    'create_family_ledger': '家族帳簿を作成',
    'qr_code_invite': 'QRコード招待',
    'show_qr_code': 'QRコードを表示',
    'scan_to_join': 'スキャンして参加',
    'send_invite_link': '招待リンクを送信',
    'share_link': 'リンクを共有',
    'copy_link': 'リンクをコピー',
    // セキュリティ設定
    'security_settings': 'セキュリティ設定',
    'security_log': 'セキュリティログ',
    'app_lock': 'アプリロック',
    'set_pin': 'PINを設定',
    'fingerprint_unlock': '指紋解除',
    'face_id_unlock': 'Face ID解除',
    'prevent_screenshot': 'スクリーンショット防止',
    'privacy_mode': 'プライバシーモード',
    'push_notification': 'プッシュ通知',
    'auto_sync': '自動同期',
    'auto_sync_desc': 'データを自動的にクラウドに同期',
    // データ管理
    'data_management': 'データ管理',
    'save_changes': '変更を保存',
    'view_stats': '統計を表示',
    'detailed_stats': '詳細統計',
    'get_suggestion': '提案を取得',
    'savings_goals': '貯蓄目標',
    'annual_review': '年間レビュー',
    'weekly_report': '週間レポート',
    // 地域設定
    'region_settings': '地域設定',
    'date_format': '日付形式',
    'time_format': '時間形式',
    'number_format': '数字形式',
    'week_start_day': '週の開始日',
    // レシート
    'receipt_detail': 'レシート詳細',
    'subtotal': '小計',
    'remaining_amount': '残額',
    // ヘルプ
    'faq': 'よくある質問',
    'add_note': 'メモを追加',
  };

  // 韩语
  static const Map<String, String> _ko = {
    'app_name': 'AI 가계부',
    'confirm': '확인',
    'cancel': '취소',
    'save': '저장',
    'delete': '삭제',
    'edit': '편집',
    'add': '추가',
    'close': '닫기',
    'loading': '로딩 중...',
    'error': '오류',
    'success': '성공',
    'warning': '경고',
    'no_data': '데이터 없음',
    'retry': '재시도',
    'home': '홈',
    'statistics': '통계',
    'add_record': '기록',
    'budget': '예산',
    'settings': '설정',
    'expense': '지출',
    'income': '수입',
    'transfer': '이체',
    'amount': '금액',
    'category': '카테고리',
    'account': '계좌',
    'date': '날짜',
    'note': '메모',
    'enter_amount': '금액 입력',
    'select_category': '카테고리 선택',
    'select_account': '계좌 선택',
    'total_income': '총 수입',
    'total_expense': '총 지출',
    'balance': '잔액',
    'daily': '일',
    'weekly': '주',
    'monthly': '월',
    'yearly': '년',
    'profile': '프로필',
    'language': '언어',
    'currency': '통화',
    'theme': '테마',
    'dark_mode': '다크 모드',
    'light_mode': '라이트 모드',
    'system_mode': '시스템',
    'data_backup': '백업',
    'data_export': '내보내기',
    'data_import': '가져오기',
    'about': '정보',
    'logout': '로그아웃',
    'login': '로그인',
    'register': '가입',
    'cash': '현금',
    'bank_card': '은행 카드',
    'credit_card': '신용카드',
    'e_wallet': '전자지갑',
    'account_balance': '잔액',
    'budget_management': '예산 관리',
    'monthly_budget': '월 예산',
    'category_budget': '카테고리 예산',
    'budget_remaining': '남은 예산',
    'budget_exceeded': '초과',
    'currency_settings': '통화 설정',
    'default_currency': '기본 통화',
    'show_currency_symbol': '기호 표시',
    'language_settings': '언어 설정',
    'follow_system': '시스템 따르기',
    // AA분할
    'aa_split': '더치페이',
    'aa_detected': '더치페이 감지됨',
    'total_amount': '총 금액',
    'split_people': '인원 수',
    'auto_detected': '자동 감지',
    'my_share': '내 부담금',
    'per_person': '인당',
    'bookkeeping_mode': '기록 모드',
    'only_my_share': '내 부담금만 기록',
    'record_total': '전체 기록',
    'confirm_split': '분할 확인',
    'split_method': '분할 방법',
    'even_split': '균등 분할',
    'proportional_split': '비율 분할',
    'custom_split': '사용자 정의 분할',
    'your_share': '내 부담금',
    // 접근성 설정
    'accessibility_settings': '접근성 설정',
    'font_size': '글꼴 크기',
    'high_contrast': '고대비',
    'bold_text': '굵은 텍스트',
    'reduce_motion': '모션 줄이기',
    'screen_reader': '화면 리더 지원',
    'large_touch_target': '큰 터치 영역',
    'large_touch': '큰 터치',
    // 스마트 조언
    'smart_advice': '스마트 조언',
    'today_advice': '오늘의 조언',
    'manage_advice_preference': '조언 설정 관리',
    // AI 언어 설정
    'ai_language_settings': 'AI 언어 설정',
    'ai_reply_language': 'AI 응답 언어',
    'voice_recognition_language': '음성 인식 언어',
    'ai_learning_curve': 'AI 학습 곡선',
    'ai_voice': 'AI 음성',
    'male_voice': '남성 음성',
    'female_voice': '여성 음성',
    // 앱 설정
    'app_lock_settings': '앱 잠금 설정',
    'batch_train_ai': 'AI 일괄 훈련',
    // 가족 기능
    'family_leaderboard': '가족 순위',
    'weekly_ranking': '주간 순위',
    'monthly_ranking': '월간 순위',
    'savings_champion': '저축 챔피언',
    'budget_master': '예산 마스터',
    'family_savings_goal': '가족 저축 목표',
    'contribute_now': '지금 기여하기',
    'goal_amount': '목표 금액',
    'current_progress': '현재 진행률',
    'days_remaining': '남은 일수',
    // 장부 설정
    'ledger_settings': '장부 설정',
    'default_ledger': '기본 장부',
    'ledger_name': '장부 이름',
    'ledger_icon': '장부 아이콘',
    'ledger_color': '장부 색상',
    'archive_ledger': '장부 보관',
    // 위치 서비스
    'location_services': '위치 서비스',
    'enable_location': '위치 활성화',
    'location_accuracy': '위치 정확도',
    'high_accuracy': '높은 정확도',
    'low_power': '저전력',
    'geofence_alerts': '지오펜스 알림',
    'nearby_merchants': '근처 가맹점',
    // 거래 관련
    'duplicate_transaction': '거래 복제',
    'transaction_time': '거래 시간',
    'transaction_note': '거래 메모',
    'transaction_tags': '거래 태그',
    'transaction_location': '거래 위치',
    'transaction_attachments': '거래 첨부 파일',
    // 자금 연령 분석
    'money_age_title': '자금 연령 분석',
    'money_age_description2': '현금 흐름 효율성 이해하기',
    'average_money_age': '평균 자금 연령',
    'money_age_health': '자금 연령 건강도',
    'poor': '나쁨',
    // 습관 추적
    'habit_tracking': '습관 추적',
    'daily_streak': '연속 기록',
    'weekly_goal': '주간 목표',
    'monthly_goal': '월간 목표',
    // 업적 시스템
    'achievement_unlocked': '업적 해제',
    'view_achievements': '업적 보기',
    'share_achievement': '업적 공유',
    'achievement_progress': '업적 진행률',
    // 음성 관련
    'listening': '듣는 중...',
    'voice_error': '음성 인식 실패',
    'speak_now': '말씀하세요',
    // 스캔 관련
    'scan_bill': '영수증 스캔',
    'recognizing': '인식 중...',
    'recognition_failed': '인식 실패',
    // 동기화 관련
    'syncing': '동기화 중...',
    'sync_complete': '동기화 완료',
    'sync_failed': '동기화 실패',
    'last_synced': '마지막 동기화',
    'sync_now': '지금 동기화',
    // 오프라인 모드
    'offline_mode': '오프라인 모드',
    'offline_data': '오프라인 데이터',
    'pending_sync': '동기화 대기 중',
    'offline_changes': '오프라인 변경사항',
    // 개인정보 설정
    'privacy_settings': '개인정보 설정',
    'data_encryption': '데이터 암호화',
    'biometric_lock': '생체 인식 잠금',
    'auto_lock': '자동 잠금',
    'lock_timeout': '잠금 시간 초과',
    // 예산 알림
    'budget_warning': '예산 경고',
    'budget_alerts': '예산 알림',
    'daily_reminder': '일일 알림',
    // 내보내기 형식
    'export_format': '내보내기 형식',
    'csv_format': 'CSV 형식',
    'excel_format': 'Excel 형식',
    'json_format': 'JSON 형식',
    // 피드백 관련
    'feedback_submitted': '피드백 제출됨',
    'thank_you_feedback': '피드백 감사합니다',
    'rate_app': '앱 평가하기',
    'share_app': '앱 공유하기',
    // 로그인 관련
    'upgrade_required': '업그레이드 필요',
    'login_required': '로그인 필요',
    'login_to_use_feature': '이 기능을 사용하려면 로그인하세요',
    'login_now': '지금 로그인',
    'continue_as_guest': '게스트로 계속',
    // 네트워크 관련
    'connection_failed': '연결 실패',
    'check_network': '네트워크 연결을 확인하세요',
    // 권한 관련
    'permission_required': '권한 필요',
    'location_permission': '위치 권한',
    'storage_permission': '저장소 권한',
    // 삭제 관련
    'delete_warning': '이 작업은 취소할 수 없습니다',
    'permanently_delete': '영구 삭제',
    'move_to_trash': '휴지통으로 이동',
    // 검색 관련
    'search_placeholder': '검색...',
    'no_results': '결과 없음',
    'search_history': '검색 기록',
    'clear_history': '기록 지우기',
    // 필터 및 정렬
    'filter_by': '필터',
    'sort_by': '정렬',
    'date_range': '날짜 범위',
    'amount_range': '금액 범위',
    'category_filter': '카테고리 필터',
    'ascending': '오름차순',
    'descending': '내림차순',
    'by_date': '날짜순',
    'by_amount': '금액순',
    'by_category': '카테고리순',
    // 일괄 작업
    'select_all': '전체 선택',
    'deselect_all': '선택 해제',
    'selected': '선택됨',
    'batch_delete': '일괄 삭제',
    'batch_edit': '일괄 편집',
    // 작업 관련
    'redo': '다시 실행',
    'action_undone': '작업 취소됨',
    'action_redone': '작업 다시 실행됨',
    // 로딩 관련
    'load_more': '더 보기',
    'refreshing': '새로고침 중...',
    'pull_to_refresh': '당겨서 새로고침',
    'release_to_refresh': '놓아서 새로고침',
    // 빈 상태
    'empty_state': '데이터 없음',
    'add_first': '첫 번째 기록 추가',
    // 인사
    'welcome_back': '다시 오신 것을 환영합니다',
    'good_morning': '좋은 아침입니다',
    'good_afternoon': '좋은 오후입니다',
    'good_evening': '좋은 저녁입니다',
    // 빠른 작업
    'frequent_categories': '자주 사용하는 카테고리',
    'suggested_actions': '추천 작업',
    // 가져오기/내보내기
    'import_data': '데이터 가져오기',
    'export_data': '데이터 내보내기',
    // 재정 자유 시뮬레이터
    'financial_freedom_simulator': '재정 자유 시뮬레이터',
    'your_financial_freedom_journey': '당신의 재정 자유 여정',
    'estimated_time': '예상 시간',
    'to_achieve_freedom': '재정 자유 달성까지',
    'accelerate_tip': '가속 팁',
    'adjust_parameters': '파라미터 조정',
    'monthly_savings': '월간 저축',
    'annual_return': '연간 수익률',
    'target_passive_income': '목표 수동 소득',
    'disclaimer': '참고용이며 재정 조언이 아닙니다',
    // 가족 연간 리뷰
    'days_recording': '일간 기록',
    'family_dinners': '가족 식사',
    'trips_count': '여행 횟수',
    'warmest_moment': '가장 따뜻한 순간',
    'biggest_goal': '가장 큰 목표',
    'shared_time': '공유 시간',
    'yearly_warm_moments': '연간 따뜻한 순간들',
    'family_contributions': '가족 기여',
    'save_image': '이미지 저장',
    'share_to_family': '가족에게 공유',
    // 가족 생일
    'education': '교육',
    'hobbies': '취미',
    'growth': '성장',
    'generate_birthday_card': '생일 카드 만들기',
    // 가족 순위
    'record_leaderboard': '기록 순위',
    'savings_leaderboard': '저축 순위',
    'badges_wall': '배지 벽',
    'leaderboard': '순위',
    // 가족 저축 목표
    'member_contribution': '멤버 기여',
    'other_savings_goals': '기타 저축 목표',
    'recent_deposits': '최근 예금',
    'deposit_now': '지금 예금',
    // 가족 심플 모드
    'simple_mode': '심플 모드',
    'monthly_shared_expense': '월간 공유 지출',
    'recent_records': '최근 기록',
    'view_all': '전체 보기',
    'upgrade_to_full_mode': '풀 모드로 업그레이드',
    'full_mode': '풀 모드',
    'stay_simple': '심플하게',
    // 지오펜스
    'geofence_reminder': '지오펜스 리마인더',
    // 홈 레이아웃
    'home_layout': '홈 레이아웃',
    'reset': '초기화',
    // 장부 설정 확장
    'ledger_type': '장부 유형',
    'default_visibility': '기본 공개 범위',
    'visibility_desc': '기본 공개 범위 설정',
    'hide_amount': '금액 숨기기',
    'hide_amount_desc': '목록에서 금액 숨기기',
    'notification_settings': '알림 설정',
    'member_record_notify': '멤버 기록 알림',
    'budget_overflow_alert': '예산 초과 알림',
    'danger_zone': '위험 영역',
    'leave_ledger': '장부 나가기',
    'delete_ledger': '장부 삭제',
    'only_owner_can_delete': '소유자만 삭제 가능',
    // 위치 분석
    'location_analysis': '위치 분석',
    'precise_location_service': '정밀 위치 서비스',
    'resident_locations': '거주 위치',
    'location_analysis_report': '위치 분석 보고서',
    'remote_spending_record': '원격 지출 기록',
    'data_security_guarantee': '데이터 보안 보장',
    // 멤버 권한
    'member': '멤버',
    'member_benefits': '멤버 혜택',
    'member_desc': '멤버 권한 설명',
    'member_permissions': '멤버 권한',
    'membership_service': '멤버십 서비스',
    'member_vote_status': '멤버 투표 상태',
    'admin': '관리자',
    'admin_desc': '관리자 권한 설명',
    'owner': '소유자',
    'owner_desc': '소유자 권한 설명',
    'viewer': '뷰어',
    'viewer_desc': '뷰어 권한 설명',
    'current_permissions': '현재 권한',
    'permission_settings': '권한 설정',
    'select_role': '역할 선택',
    'role_recommendation': '역할 추천',
    // 오프라인 모드 확장
    'offline_mode_active': '오프라인 모드 활성화',
    'offline_mode_desc': '오프라인 모드 설명',
    'offline_mode_full_desc': '오프라인 모드에서는 데이터가 로컬에 저장되고 온라인 시 동기화됩니다',
    'offline_voice': '오프라인 음성',
    'offline_voice_desc': '오프라인 음성 인식 지원',
    'online': '온라인',
    'network_unavailable': '네트워크 사용 불가',
    'retry_network': '네트워크 재시도',
    'retry_online': '온라인 재시도',
    'continue_offline': '오프라인으로 계속',
    'use_offline': '오프라인 사용',
    // 스마트 기능
    'smart_recommendation': '스마트 추천',
    'discover_new_feature': '새 기능 발견',
    'later_remind': '나중에 알림',
    'ai_parsing': 'AI 분석',
    'ai_parsing_offline_desc': '오프라인 모드에서는 AI 분석을 사용할 수 없습니다',
    'analyzing': '분석 중...',
    'confidence_level': '신뢰도',
    'low_confidence_title': '낮은 신뢰도',
    'recognition_result': '인식 결과',
    'auto_extracted': '자동 추출',
    'original_text': '원본 텍스트',
    // 음성 어시스턴트
    'voice_assistant': '음성 어시스턴트',
    'voice_chat': '음성 채팅',
    'voice_history_title': '음성 기록',
    'voice_history_hint': '음성 기록 보기',
    'no_voice_history': '음성 기록 없음',
    'type_or_speak': '입력하거나 말하세요',
    'ask_anything': '무엇이든 물어보세요',
    'you_can_ask': '질문할 수 있습니다',
    'examples': '예시',
    'quick_questions': '빠른 질문',
    'continue_asking': '계속 질문',
    'continuous_chat': '연속 채팅',
    // 자연어 입력
    'natural_language_input': '자연어 입력',
    'smart_text_input': '스마트 텍스트 입력',
    'input_hint': '입력 힌트',
    'input_to_bookkeep': '입력하여 기록',
    'quick_bookkeep': '빠른 기록',
    'quick_bookkeeping': '빠른 기록',
    'confirm_bookkeeping': '기록 확인',
    'basic_recording': '기본 기록',
    // 예산 쿼리
    'budget_query': '예산 쿼리',
    'budget_overspent_alert': '예산 초과',
    'money_age_query': '자금 연령 쿼리',
    // 청구서 리마인더
    'bill_due_reminder': '청구서 만기 리마인더',
    'remind': '리마인드',
    // 업그레이드 기능
    'upgrade_mode': '업그레이드 모드',
    'upgrade_notice': '업그레이드 알림',
    'upgrade_notice_desc': '새 버전 사용 가능',
    'upgrade_description': '업그레이드 설명',
    'upgrade_vote': '업그레이드 투표',
    'choose_plan': '플랜 선택',
    'start_upgrade': '업그레이드 시작',
    'complete_upgrade': '업그레이드 완료',
    'waiting_for_votes': '투표 대기 중',
    'vote_complete': '투표 완료',
    'vote_rules': '투표 규칙',
    'feature': '기능',
    'discount': '할인',
    // 가족 초대
    'invite_family': '가족 초대',
    'create_family_ledger': '가족 장부 만들기',
    'qr_code_invite': 'QR 코드 초대',
    'show_qr_code': 'QR 코드 표시',
    'scan_to_join': '스캔하여 참가',
    'send_invite_link': '초대 링크 전송',
    'share_link': '링크 공유',
    'copy_link': '링크 복사',
    // 보안 설정
    'security_settings': '보안 설정',
    'security_log': '보안 로그',
    'app_lock': '앱 잠금',
    'set_pin': 'PIN 설정',
    'fingerprint_unlock': '지문 잠금 해제',
    'face_id_unlock': 'Face ID 잠금 해제',
    'prevent_screenshot': '스크린샷 방지',
    'privacy_mode': '프라이버시 모드',
    'push_notification': '푸시 알림',
    'auto_sync': '자동 동기화',
    'auto_sync_desc': '데이터를 자동으로 클라우드에 동기화',
    // 데이터 관리
    'data_management': '데이터 관리',
    'save_changes': '변경 사항 저장',
    'view_stats': '통계 보기',
    'detailed_stats': '상세 통계',
    'get_suggestion': '제안 받기',
    'savings_goals': '저축 목표',
    'annual_review': '연간 리뷰',
    'weekly_report': '주간 보고서',
    // 지역 설정
    'region_settings': '지역 설정',
    'date_format': '날짜 형식',
    'time_format': '시간 형식',
    'number_format': '숫자 형식',
    'week_start_day': '주 시작일',
    // 영수증
    'receipt_detail': '영수증 상세',
    'subtotal': '소계',
    'remaining_amount': '남은 금액',
    // 도움말
    'faq': '자주 묻는 질문',
    'add_note': '메모 추가',
  };
}

/// 本地化代理
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  final AppLanguage language;

  const AppLocalizationsDelegate(this.language);

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(language);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => old.language != language;
}
