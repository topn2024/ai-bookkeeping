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
    'app_name': 'AI智能记账',
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
    'profile': '个人资料',
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
