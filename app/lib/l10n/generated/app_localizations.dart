import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'AI Bookkeeping'**
  String get appName;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This Year'**
  String get thisYear;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @pleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please Select'**
  String get pleaseSelect;

  /// No description provided for @pleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please Enter'**
  String get pleaseEnter;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Bottom navigation - Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Bottom navigation - Trends
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trends;

  /// Bottom navigation - Statistics
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Bottom navigation - Add record
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addRecord;

  /// Bottom navigation - Budget
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// Bottom navigation - Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Transaction type - Expense
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// Transaction type - Income
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// Transaction type - Transfer
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @subcategory.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get subcategory;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @remark.
  ///
  /// In en, this message translates to:
  /// **'Remark'**
  String get remark;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// No description provided for @selectSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Select subcategory'**
  String get selectSubcategory;

  /// No description provided for @selectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get selectAccount;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved'**
  String get transactionSaved;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDeleted;

  /// No description provided for @transactionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated'**
  String get transactionUpdated;

  /// No description provided for @confirmDeleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete this transaction?'**
  String get confirmDeleteTransaction;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get noTransactions;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @allTransactions.
  ///
  /// In en, this message translates to:
  /// **'All Transactions'**
  String get allTransactions;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransaction;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From Account'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To Account'**
  String get toAccount;

  /// No description provided for @transferFee.
  ///
  /// In en, this message translates to:
  /// **'Transfer Fee'**
  String get transferFee;

  /// No description provided for @totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// No description provided for @totalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get totalExpense;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @netIncome.
  ///
  /// In en, this message translates to:
  /// **'Net Income'**
  String get netIncome;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @trend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get trend;

  /// No description provided for @comparison.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get comparison;

  /// No description provided for @breakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown'**
  String get breakdown;

  /// No description provided for @expenseByCategory.
  ///
  /// In en, this message translates to:
  /// **'Expense by Category'**
  String get expenseByCategory;

  /// No description provided for @incomeByCategory.
  ///
  /// In en, this message translates to:
  /// **'Income by Category'**
  String get incomeByCategory;

  /// No description provided for @expenseByAccount.
  ///
  /// In en, this message translates to:
  /// **'Expense by Account'**
  String get expenseByAccount;

  /// No description provided for @incomeByAccount.
  ///
  /// In en, this message translates to:
  /// **'Income by Account'**
  String get incomeByAccount;

  /// No description provided for @topCategories.
  ///
  /// In en, this message translates to:
  /// **'Top Categories'**
  String get topCategories;

  /// No description provided for @expenseTrend.
  ///
  /// In en, this message translates to:
  /// **'Expense Trend'**
  String get expenseTrend;

  /// No description provided for @incomeTrend.
  ///
  /// In en, this message translates to:
  /// **'Income Trend'**
  String get incomeTrend;

  /// No description provided for @balanceTrend.
  ///
  /// In en, this message translates to:
  /// **'Balance Trend'**
  String get balanceTrend;

  /// No description provided for @statisticsOverview.
  ///
  /// In en, this message translates to:
  /// **'Statistics Overview'**
  String get statisticsOverview;

  /// No description provided for @noStatisticsData.
  ///
  /// In en, this message translates to:
  /// **'No statistics data'**
  String get noStatisticsData;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// No description provided for @dataBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get dataBackup;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get dataExport;

  /// No description provided for @dataImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataImport;

  /// No description provided for @dataSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get dataSync;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get rememberMe;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccess;

  /// No description provided for @logoutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logout successful'**
  String get logoutSuccess;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registerSuccess;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display Settings'**
  String get displaySettings;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get checkUpdate;

  /// No description provided for @alreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'Already latest version'**
  String get alreadyLatest;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get newVersionAvailable;

  /// Account type - Cash
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// Account type - Bank Card
  ///
  /// In en, this message translates to:
  /// **'Bank Card'**
  String get bankCard;

  /// Account type - Credit Card
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get creditCard;

  /// Account type - E-Wallet
  ///
  /// In en, this message translates to:
  /// **'E-Wallet'**
  String get eWallet;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalance;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get accountManagement;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccount;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountName;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @initialBalance.
  ///
  /// In en, this message translates to:
  /// **'Initial Balance'**
  String get initialBalance;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get currentBalance;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @accountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account saved'**
  String get accountSaved;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String confirmDeleteAccount(String name);

  /// No description provided for @defaultAccount.
  ///
  /// In en, this message translates to:
  /// **'Default Account'**
  String get defaultAccount;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get setAsDefault;

  /// No description provided for @includeInTotal.
  ///
  /// In en, this message translates to:
  /// **'Include in Total'**
  String get includeInTotal;

  /// No description provided for @accountIcon.
  ///
  /// In en, this message translates to:
  /// **'Account Icon'**
  String get accountIcon;

  /// No description provided for @accountColor.
  ///
  /// In en, this message translates to:
  /// **'Account Color'**
  String get accountColor;

  /// No description provided for @totalAssets.
  ///
  /// In en, this message translates to:
  /// **'Total Assets'**
  String get totalAssets;

  /// No description provided for @totalLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Total Liabilities'**
  String get totalLiabilities;

  /// No description provided for @netAssets.
  ///
  /// In en, this message translates to:
  /// **'Net Assets'**
  String get netAssets;

  /// No description provided for @debitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit Card'**
  String get debitCard;

  /// No description provided for @savingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Savings Account'**
  String get savingsAccount;

  /// No description provided for @investmentAccount.
  ///
  /// In en, this message translates to:
  /// **'Investment Account'**
  String get investmentAccount;

  /// No description provided for @loanAccount.
  ///
  /// In en, this message translates to:
  /// **'Loan Account'**
  String get loanAccount;

  /// No description provided for @otherAccount.
  ///
  /// In en, this message translates to:
  /// **'Other Account'**
  String get otherAccount;

  /// No description provided for @budgetManagement.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetManagement;

  /// No description provided for @monthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly Budget'**
  String get monthlyBudget;

  /// No description provided for @categoryBudget.
  ///
  /// In en, this message translates to:
  /// **'Category Budget'**
  String get categoryBudget;

  /// No description provided for @budgetRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get budgetRemaining;

  /// No description provided for @budgetExceeded.
  ///
  /// In en, this message translates to:
  /// **'Exceeded'**
  String get budgetExceeded;

  /// No description provided for @budgetUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get budgetUsed;

  /// No description provided for @budgetProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get budgetProgress;

  /// No description provided for @addBudget.
  ///
  /// In en, this message translates to:
  /// **'Add Budget'**
  String get addBudget;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit Budget'**
  String get editBudget;

  /// No description provided for @deleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget'**
  String get deleteBudget;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget Amount'**
  String get budgetAmount;

  /// No description provided for @budgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Budget Period'**
  String get budgetPeriod;

  /// No description provided for @budgetAlert.
  ///
  /// In en, this message translates to:
  /// **'Budget Alert'**
  String get budgetAlert;

  /// No description provided for @alertThreshold.
  ///
  /// In en, this message translates to:
  /// **'Alert Threshold'**
  String get alertThreshold;

  /// No description provided for @budgetSaved.
  ///
  /// In en, this message translates to:
  /// **'Budget saved'**
  String get budgetSaved;

  /// No description provided for @budgetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted'**
  String get budgetDeleted;

  /// No description provided for @confirmDeleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete budget \"{name}\"?'**
  String confirmDeleteBudget(String name);

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get overBudget;

  /// No description provided for @underBudget.
  ///
  /// In en, this message translates to:
  /// **'Under budget'**
  String get underBudget;

  /// No description provided for @noBudget.
  ///
  /// In en, this message translates to:
  /// **'No budget set'**
  String get noBudget;

  /// No description provided for @setBudget.
  ///
  /// In en, this message translates to:
  /// **'Set Budget'**
  String get setBudget;

  /// No description provided for @totalBudget.
  ///
  /// In en, this message translates to:
  /// **'Total Budget'**
  String get totalBudget;

  /// No description provided for @remainingBudget.
  ///
  /// In en, this message translates to:
  /// **'Remaining Budget'**
  String get remainingBudget;

  /// No description provided for @budgetOverview.
  ///
  /// In en, this message translates to:
  /// **'Budget Overview'**
  String get budgetOverview;

  /// No description provided for @currencySettings.
  ///
  /// In en, this message translates to:
  /// **'Currency Settings'**
  String get currencySettings;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get defaultCurrency;

  /// No description provided for @showCurrencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Show Symbol'**
  String get showCurrencySymbol;

  /// No description provided for @currencyFormat.
  ///
  /// In en, this message translates to:
  /// **'Currency Format'**
  String get currencyFormat;

  /// No description provided for @decimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal Places'**
  String get decimalPlaces;

  /// No description provided for @thousandSeparator.
  ///
  /// In en, this message translates to:
  /// **'Thousand Separator'**
  String get thousandSeparator;

  /// No description provided for @currencyPosition.
  ///
  /// In en, this message translates to:
  /// **'Symbol Position'**
  String get currencyPosition;

  /// No description provided for @beforeAmount.
  ///
  /// In en, this message translates to:
  /// **'Before Amount'**
  String get beforeAmount;

  /// No description provided for @afterAmount.
  ///
  /// In en, this message translates to:
  /// **'After Amount'**
  String get afterAmount;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed'**
  String get languageChanged;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart required for changes to take effect'**
  String get restartRequired;

  /// No description provided for @categoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Category Management'**
  String get categoryManagement;

  /// No description provided for @expenseCategories.
  ///
  /// In en, this message translates to:
  /// **'Expense Categories'**
  String get expenseCategories;

  /// No description provided for @incomeCategories.
  ///
  /// In en, this message translates to:
  /// **'Income Categories'**
  String get incomeCategories;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @categoryIcon.
  ///
  /// In en, this message translates to:
  /// **'Category Icon'**
  String get categoryIcon;

  /// No description provided for @categoryColor.
  ///
  /// In en, this message translates to:
  /// **'Category Color'**
  String get categoryColor;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent Category'**
  String get parentCategory;

  /// No description provided for @noParent.
  ///
  /// In en, this message translates to:
  /// **'No Parent (Top Level)'**
  String get noParent;

  /// No description provided for @categorySaved.
  ///
  /// In en, this message translates to:
  /// **'Category saved'**
  String get categorySaved;

  /// No description provided for @categoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoryDeleted;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete this category?'**
  String get confirmDeleteCategory;

  /// No description provided for @customCategory.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customCategory;

  /// No description provided for @defaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultCategory;

  /// No description provided for @sortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort Order'**
  String get sortOrder;

  /// No description provided for @categoryHasSubcategories.
  ///
  /// In en, this message translates to:
  /// **'This category has subcategories'**
  String get categoryHasSubcategories;

  /// No description provided for @deleteWithSubcategories.
  ///
  /// In en, this message translates to:
  /// **'Delete with subcategories'**
  String get deleteWithSubcategories;

  /// No description provided for @moveToOther.
  ///
  /// In en, this message translates to:
  /// **'Move transactions to other category'**
  String get moveToOther;

  /// No description provided for @subcategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subcategories'**
  String subcategoriesCount(int count);

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice Input'**
  String get voiceInput;

  /// No description provided for @voiceRecognition.
  ///
  /// In en, this message translates to:
  /// **'Voice Recognition'**
  String get voiceRecognition;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop Recording'**
  String get stopRecording;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @voiceInputHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to start voice input'**
  String get voiceInputHint;

  /// No description provided for @voiceRecognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition failed'**
  String get voiceRecognitionFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @recognitionResult.
  ///
  /// In en, this message translates to:
  /// **'Recognition Result'**
  String get recognitionResult;

  /// No description provided for @confirmRecognition.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmRecognition;

  /// No description provided for @reRecognize.
  ///
  /// In en, this message translates to:
  /// **'Re-recognize'**
  String get reRecognize;

  /// No description provided for @microphonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get microphonePermission;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @imageRecognition.
  ///
  /// In en, this message translates to:
  /// **'Image Recognition'**
  String get imageRecognition;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @imageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing image...'**
  String get imageProcessing;

  /// No description provided for @recognitionComplete.
  ///
  /// In en, this message translates to:
  /// **'Recognition complete'**
  String get recognitionComplete;

  /// No description provided for @noReceiptFound.
  ///
  /// In en, this message translates to:
  /// **'No receipt found'**
  String get noReceiptFound;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera permission required'**
  String get cameraPermission;

  /// No description provided for @galleryPermission.
  ///
  /// In en, this message translates to:
  /// **'Gallery permission required'**
  String get galleryPermission;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @recurringTransaction.
  ///
  /// In en, this message translates to:
  /// **'Recurring Transaction'**
  String get recurringTransaction;

  /// No description provided for @addRecurring.
  ///
  /// In en, this message translates to:
  /// **'Add Recurring'**
  String get addRecurring;

  /// No description provided for @editRecurring.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring'**
  String get editRecurring;

  /// No description provided for @deleteRecurring.
  ///
  /// In en, this message translates to:
  /// **'Delete Recurring'**
  String get deleteRecurring;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every Day'**
  String get everyDay;

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every Week'**
  String get everyWeek;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every Month'**
  String get everyMonth;

  /// No description provided for @everyYear.
  ///
  /// In en, this message translates to:
  /// **'Every Year'**
  String get everyYear;

  /// No description provided for @startFrom.
  ///
  /// In en, this message translates to:
  /// **'Start From'**
  String get startFrom;

  /// No description provided for @endAt.
  ///
  /// In en, this message translates to:
  /// **'End At'**
  String get endAt;

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No End Date'**
  String get noEndDate;

  /// No description provided for @nextOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Next Occurrence'**
  String get nextOccurrence;

  /// No description provided for @recurringSaved.
  ///
  /// In en, this message translates to:
  /// **'Recurring saved'**
  String get recurringSaved;

  /// No description provided for @recurringDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recurring deleted'**
  String get recurringDeleted;

  /// No description provided for @confirmDeleteRecurring.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete this recurring transaction?'**
  String get confirmDeleteRecurring;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @billReminder.
  ///
  /// In en, this message translates to:
  /// **'Bill Reminder'**
  String get billReminder;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add Reminder'**
  String get addReminder;

  /// No description provided for @editReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit Reminder'**
  String get editReminder;

  /// No description provided for @deleteReminder.
  ///
  /// In en, this message translates to:
  /// **'Delete Reminder'**
  String get deleteReminder;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get reminderTime;

  /// No description provided for @reminderDate.
  ///
  /// In en, this message translates to:
  /// **'Reminder Date'**
  String get reminderDate;

  /// No description provided for @reminderNote.
  ///
  /// In en, this message translates to:
  /// **'Reminder Note'**
  String get reminderNote;

  /// No description provided for @reminderSaved.
  ///
  /// In en, this message translates to:
  /// **'Reminder saved'**
  String get reminderSaved;

  /// No description provided for @reminderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Reminder deleted'**
  String get reminderDeleted;

  /// No description provided for @confirmDeleteReminder.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete this reminder?'**
  String get confirmDeleteReminder;

  /// No description provided for @markAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get markAsPaid;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysLeft(int days);

  /// No description provided for @daysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days} days overdue'**
  String daysOverdue(int days);

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get debt;

  /// No description provided for @debtManagement.
  ///
  /// In en, this message translates to:
  /// **'Debt Management'**
  String get debtManagement;

  /// No description provided for @addDebt.
  ///
  /// In en, this message translates to:
  /// **'Add Debt'**
  String get addDebt;

  /// No description provided for @editDebt.
  ///
  /// In en, this message translates to:
  /// **'Edit Debt'**
  String get editDebt;

  /// No description provided for @deleteDebt.
  ///
  /// In en, this message translates to:
  /// **'Delete Debt'**
  String get deleteDebt;

  /// No description provided for @lend.
  ///
  /// In en, this message translates to:
  /// **'Lend'**
  String get lend;

  /// No description provided for @borrow.
  ///
  /// In en, this message translates to:
  /// **'Borrow'**
  String get borrow;

  /// No description provided for @lendTo.
  ///
  /// In en, this message translates to:
  /// **'Lend To'**
  String get lendTo;

  /// No description provided for @borrowFrom.
  ///
  /// In en, this message translates to:
  /// **'Borrow From'**
  String get borrowFrom;

  /// No description provided for @personName.
  ///
  /// In en, this message translates to:
  /// **'Person Name'**
  String get personName;

  /// No description provided for @debtAmount.
  ///
  /// In en, this message translates to:
  /// **'Debt Amount'**
  String get debtAmount;

  /// No description provided for @repaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Repaid Amount'**
  String get repaidAmount;

  /// No description provided for @remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'Remaining Amount'**
  String get remainingAmount;

  /// No description provided for @debtSaved.
  ///
  /// In en, this message translates to:
  /// **'Debt saved'**
  String get debtSaved;

  /// No description provided for @debtDeleted.
  ///
  /// In en, this message translates to:
  /// **'Debt deleted'**
  String get debtDeleted;

  /// No description provided for @confirmDeleteDebt.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete this debt?'**
  String get confirmDeleteDebt;

  /// No description provided for @addRepayment.
  ///
  /// In en, this message translates to:
  /// **'Add Repayment'**
  String get addRepayment;

  /// No description provided for @repaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Repayment History'**
  String get repaymentHistory;

  /// No description provided for @fullyRepaid.
  ///
  /// In en, this message translates to:
  /// **'Fully Repaid'**
  String get fullyRepaid;

  /// No description provided for @partiallyRepaid.
  ///
  /// In en, this message translates to:
  /// **'Partially Repaid'**
  String get partiallyRepaid;

  /// No description provided for @notRepaid.
  ///
  /// In en, this message translates to:
  /// **'Not Repaid'**
  String get notRepaid;

  /// No description provided for @totalLent.
  ///
  /// In en, this message translates to:
  /// **'Total Lent'**
  String get totalLent;

  /// No description provided for @totalBorrowed.
  ///
  /// In en, this message translates to:
  /// **'Total Borrowed'**
  String get totalBorrowed;

  /// No description provided for @savingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Savings Goal'**
  String get savingsGoal;

  /// No description provided for @addGoal.
  ///
  /// In en, this message translates to:
  /// **'Add Goal'**
  String get addGoal;

  /// No description provided for @editGoal.
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get editGoal;

  /// No description provided for @deleteGoal.
  ///
  /// In en, this message translates to:
  /// **'Delete Goal'**
  String get deleteGoal;

  /// No description provided for @goalName.
  ///
  /// In en, this message translates to:
  /// **'Goal Name'**
  String get goalName;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target Amount'**
  String get targetAmount;

  /// No description provided for @currentAmount.
  ///
  /// In en, this message translates to:
  /// **'Current Amount'**
  String get currentAmount;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target Date'**
  String get targetDate;

  /// No description provided for @goalProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get goalProgress;

  /// No description provided for @goalSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal saved'**
  String get goalSaved;

  /// No description provided for @goalDeleted.
  ///
  /// In en, this message translates to:
  /// **'Goal deleted'**
  String get goalDeleted;

  /// No description provided for @confirmDeleteGoal.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete this goal?'**
  String get confirmDeleteGoal;

  /// No description provided for @addSavings.
  ///
  /// In en, this message translates to:
  /// **'Add Savings'**
  String get addSavings;

  /// No description provided for @withdrawSavings.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Savings'**
  String get withdrawSavings;

  /// No description provided for @goalAchieved.
  ///
  /// In en, this message translates to:
  /// **'Goal Achieved'**
  String get goalAchieved;

  /// No description provided for @daysToGoal.
  ///
  /// In en, this message translates to:
  /// **'{days} days to goal'**
  String daysToGoal(int days);

  /// No description provided for @amountNeeded.
  ///
  /// In en, this message translates to:
  /// **'Amount needed'**
  String get amountNeeded;

  /// No description provided for @dailySavingsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Daily savings needed'**
  String get dailySavingsNeeded;

  /// No description provided for @monthlySavingsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Monthly savings needed'**
  String get monthlySavingsNeeded;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @generateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get generateReport;

  /// No description provided for @exportReport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get exportReport;

  /// No description provided for @reportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Report Period'**
  String get reportPeriod;

  /// No description provided for @incomeReport.
  ///
  /// In en, this message translates to:
  /// **'Income Report'**
  String get incomeReport;

  /// No description provided for @expenseReport.
  ///
  /// In en, this message translates to:
  /// **'Expense Report'**
  String get expenseReport;

  /// No description provided for @balanceReport.
  ///
  /// In en, this message translates to:
  /// **'Balance Report'**
  String get balanceReport;

  /// No description provided for @categoryReport.
  ///
  /// In en, this message translates to:
  /// **'Category Report'**
  String get categoryReport;

  /// No description provided for @accountReport.
  ///
  /// In en, this message translates to:
  /// **'Account Report'**
  String get accountReport;

  /// No description provided for @annualReport.
  ///
  /// In en, this message translates to:
  /// **'Annual Report'**
  String get annualReport;

  /// No description provided for @monthlyReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly Report'**
  String get monthlyReport;

  /// No description provided for @weeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Weekly Report'**
  String get weeklyReport;

  /// No description provided for @customReport.
  ///
  /// In en, this message translates to:
  /// **'Custom Report'**
  String get customReport;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get networkError;

  /// No description provided for @connectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout'**
  String get connectionTimeout;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get serverError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @checkYourConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection'**
  String get checkYourConnection;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpired;

  /// No description provided for @pleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please login again'**
  String get pleaseLoginAgain;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @operationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get operationSuccess;

  /// No description provided for @dataLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Data load failed'**
  String get dataLoadFailed;

  /// No description provided for @dataSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Data save failed'**
  String get dataSaveFailed;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get invalidInput;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone format'**
  String get invalidPhone;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get amountInvalid;

  /// No description provided for @dateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid date'**
  String get dateInvalid;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AI Bookkeeping'**
  String get welcomeMessage;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick Add'**
  String get quickAdd;

  /// No description provided for @voiceAdd.
  ///
  /// In en, this message translates to:
  /// **'Voice Add'**
  String get voiceAdd;

  /// No description provided for @scanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan Receipt'**
  String get scanReceipt;

  /// No description provided for @todaySpending.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Spending'**
  String get todaySpending;

  /// No description provided for @monthlySpending.
  ///
  /// In en, this message translates to:
  /// **'Monthly Spending'**
  String get monthlySpending;

  /// No description provided for @budgetStatus.
  ///
  /// In en, this message translates to:
  /// **'Budget Status'**
  String get budgetStatus;

  /// No description provided for @financialOverview.
  ///
  /// In en, this message translates to:
  /// **'Financial Overview'**
  String get financialOverview;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @tips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// No description provided for @didYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Did You Know'**
  String get didYouKnow;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @createFirstTransaction.
  ///
  /// In en, this message translates to:
  /// **'Create your first transaction'**
  String get createFirstTransaction;

  /// No description provided for @setupBudget.
  ///
  /// In en, this message translates to:
  /// **'Set up your budget'**
  String get setupBudget;

  /// No description provided for @addAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add your accounts'**
  String get addAccounts;

  /// No description provided for @startTracking.
  ///
  /// In en, this message translates to:
  /// **'Start tracking your finances'**
  String get startTracking;

  /// No description provided for @ledgerManagement.
  ///
  /// In en, this message translates to:
  /// **'Ledger Management'**
  String get ledgerManagement;

  /// No description provided for @reimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get reimbursement;

  /// No description provided for @tagStatistics.
  ///
  /// In en, this message translates to:
  /// **'Tag Statistics'**
  String get tagStatistics;

  /// No description provided for @templateManagement.
  ///
  /// In en, this message translates to:
  /// **'Template Management'**
  String get templateManagement;

  /// No description provided for @recurringManagement.
  ///
  /// In en, this message translates to:
  /// **'Recurring Transactions'**
  String get recurringManagement;

  /// No description provided for @openMembership.
  ///
  /// In en, this message translates to:
  /// **'Open Membership'**
  String get openMembership;

  /// No description provided for @unlockAIFeatures.
  ///
  /// In en, this message translates to:
  /// **'Unlock AI smart bookkeeping features'**
  String get unlockAIFeatures;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get openNow;

  /// No description provided for @dataCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get dataCloudSync;

  /// No description provided for @cloudSyncEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled, data auto-syncs to cloud'**
  String get cloudSyncEnabled;

  /// No description provided for @cloudSyncDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled, data saved locally only'**
  String get cloudSyncDisabled;

  /// No description provided for @cloudSyncTurnedOn.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync enabled'**
  String get cloudSyncTurnedOn;

  /// No description provided for @cloudSyncTurnedOff.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync disabled, data saved locally only'**
  String get cloudSyncTurnedOff;

  /// No description provided for @dataBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Backup'**
  String get dataBackupTitle;

  /// No description provided for @backupToCloud.
  ///
  /// In en, this message translates to:
  /// **'Backup to cloud'**
  String get backupToCloud;

  /// No description provided for @dataExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Export'**
  String get dataExportTitle;

  /// No description provided for @exportToCSV.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV file'**
  String get exportToCSV;

  /// No description provided for @dataImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Import'**
  String get dataImportTitle;

  /// No description provided for @importFromCSV.
  ///
  /// In en, this message translates to:
  /// **'Import from CSV file'**
  String get importFromCSV;

  /// No description provided for @annualReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Annual Report'**
  String get annualReportTitle;

  /// No description provided for @viewAnnualSummary.
  ///
  /// In en, this message translates to:
  /// **'View annual financial summary'**
  String get viewAnnualSummary;

  /// No description provided for @customReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Report'**
  String get customReportTitle;

  /// No description provided for @multiDimensionalAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Multi-dimensional custom analysis'**
  String get multiDimensionalAnalysis;

  /// No description provided for @assetOverview.
  ///
  /// In en, this message translates to:
  /// **'Asset Overview'**
  String get assetOverview;

  /// No description provided for @netAssetsTrendDistribution.
  ///
  /// In en, this message translates to:
  /// **'Net assets, trends and distribution'**
  String get netAssetsTrendDistribution;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get systemSettings;

  /// No description provided for @themeLanguageSecurity.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, security, etc.'**
  String get themeLanguageSecurity;

  /// No description provided for @editTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransactionTitle;

  /// No description provided for @addTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Record'**
  String get addTransactionTitle;

  /// No description provided for @splitTransaction.
  ///
  /// In en, this message translates to:
  /// **'Split Transaction'**
  String get splitTransaction;

  /// No description provided for @voiceRecord.
  ///
  /// In en, this message translates to:
  /// **'Voice Record'**
  String get voiceRecord;

  /// No description provided for @photoRecord.
  ///
  /// In en, this message translates to:
  /// **'Photo Record'**
  String get photoRecord;

  /// No description provided for @addNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add note...'**
  String get addNoteHint;

  /// No description provided for @reimbursable.
  ///
  /// In en, this message translates to:
  /// **'Reimbursable'**
  String get reimbursable;

  /// No description provided for @subcategoryOf.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s subcategories'**
  String subcategoryOf(String name);

  /// No description provided for @useParentCategory.
  ///
  /// In en, this message translates to:
  /// **'Use parent'**
  String get useParentCategory;

  /// No description provided for @aiRecommendedCategory.
  ///
  /// In en, this message translates to:
  /// **'AI Recommended: {name}'**
  String aiRecommendedCategory(String name);

  /// No description provided for @useCategory.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useCategory;

  /// No description provided for @pleaseEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter amount'**
  String get pleaseEnterAmount;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select category'**
  String get pleaseSelectCategory;

  /// No description provided for @accountsCannotBeSame.
  ///
  /// In en, this message translates to:
  /// **'From and to accounts cannot be the same'**
  String get accountsCannotBeSame;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @aiSmartBookkeeping.
  ///
  /// In en, this message translates to:
  /// **'AI Smart Bookkeeping'**
  String get aiSmartBookkeeping;

  /// No description provided for @thisMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonthLabel;

  /// No description provided for @quickRecord.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get quickRecord;

  /// No description provided for @reportAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportAnalysis;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteRecord.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record?'**
  String get confirmDeleteRecord;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// No description provided for @aiConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Confidence'**
  String get aiConfidenceLabel;

  /// No description provided for @originalImage.
  ///
  /// In en, this message translates to:
  /// **'Original Image'**
  String get originalImage;

  /// No description provided for @viewLargeImage.
  ///
  /// In en, this message translates to:
  /// **'View Full Image'**
  String get viewLargeImage;

  /// No description provided for @sourcePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get sourcePhoto;

  /// No description provided for @sourceVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get sourceVoice;

  /// No description provided for @sourceEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get sourceEmail;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @expiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String expiresInDays(int days);

  /// No description provided for @expiresInHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours left'**
  String expiresInHours(int hours);

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoon;

  /// No description provided for @deleteText.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteText;

  /// No description provided for @saveText.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveText;

  /// No description provided for @iconColor.
  ///
  /// In en, this message translates to:
  /// **'Icon Color'**
  String get iconColor;

  /// No description provided for @iconText.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get iconText;

  /// No description provided for @budgetType.
  ///
  /// In en, this message translates to:
  /// **'Budget Type'**
  String get budgetType;

  /// No description provided for @linkedCategory.
  ///
  /// In en, this message translates to:
  /// **'Linked Category (Optional)'**
  String get linkedCategory;

  /// No description provided for @colorText.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorText;

  /// No description provided for @budgetCarryover.
  ///
  /// In en, this message translates to:
  /// **'Budget Carryover'**
  String get budgetCarryover;

  /// No description provided for @carryoverMode.
  ///
  /// In en, this message translates to:
  /// **'Carryover Mode'**
  String get carryoverMode;

  /// No description provided for @confirmDeleteCategoryMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String confirmDeleteCategoryMsg(String name);

  /// No description provided for @debtToAssetRatio.
  ///
  /// In en, this message translates to:
  /// **'Debt to Asset Ratio'**
  String get debtToAssetRatio;

  /// No description provided for @statisticsDimension.
  ///
  /// In en, this message translates to:
  /// **'Statistics Dimension'**
  String get statisticsDimension;

  /// No description provided for @adjustFilters.
  ///
  /// In en, this message translates to:
  /// **'Please adjust filter criteria'**
  String get adjustFilters;

  /// No description provided for @advancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get advancedFilters;

  /// No description provided for @cleanupText.
  ///
  /// In en, this message translates to:
  /// **'Cleanup'**
  String get cleanupText;

  /// No description provided for @restoreText.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreText;

  /// No description provided for @noCacheFiles.
  ///
  /// In en, this message translates to:
  /// **'No cache files'**
  String get noCacheFiles;

  /// No description provided for @restoreStatistics.
  ///
  /// In en, this message translates to:
  /// **'Restore Statistics:'**
  String get restoreStatistics;

  /// No description provided for @confirmRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to restore from \"{name}\"?'**
  String confirmRestoreBackup(String name);

  /// No description provided for @confirmDeleteBackup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete backup \"{name}\"? This action cannot be undone.'**
  String confirmDeleteBackup(String name);

  /// No description provided for @confirmDeleteBillReminder.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete bill reminder \"{name}\"?'**
  String confirmDeleteBillReminder(String name);

  /// No description provided for @confirmDeleteCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete credit card \"{name}\"?'**
  String confirmDeleteCreditCard(String name);

  /// No description provided for @repaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Repayment - {name}'**
  String repaymentTitle(String name);

  /// No description provided for @currentDebt.
  ///
  /// In en, this message translates to:
  /// **'Current Debt: ¥{amount}'**
  String currentDebt(String amount);

  /// No description provided for @repaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully repaid ¥{amount}'**
  String repaymentSuccess(String amount);

  /// No description provided for @confirmDeleteTheme.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete theme \"{name}\"? This action cannot be undone.'**
  String confirmDeleteTheme(String name);

  /// No description provided for @editThemeName.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editThemeName(String name);

  /// No description provided for @cardBorderRadius.
  ///
  /// In en, this message translates to:
  /// **'Card Border Radius'**
  String get cardBorderRadius;

  /// No description provided for @buttonBorderRadius.
  ///
  /// In en, this message translates to:
  /// **'Button Border Radius'**
  String get buttonBorderRadius;

  /// No description provided for @materialDesign3.
  ///
  /// In en, this message translates to:
  /// **'Material 3'**
  String get materialDesign3;

  /// No description provided for @useMaterialDesign3.
  ///
  /// In en, this message translates to:
  /// **'Use Material Design 3 style'**
  String get useMaterialDesign3;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} feature coming soon'**
  String featureComingSoon(String feature);

  /// No description provided for @checkUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get checkUpdateTitle;

  /// No description provided for @currentVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Version {version}'**
  String currentVersionLabel(String version);

  /// No description provided for @cleanDownloadCache.
  ///
  /// In en, this message translates to:
  /// **'Clean Download Cache'**
  String get cleanDownloadCache;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculating;

  /// No description provided for @cachedSize.
  ///
  /// In en, this message translates to:
  /// **'Cached {size}'**
  String cachedSize(String size);

  /// No description provided for @noCache.
  ///
  /// In en, this message translates to:
  /// **'No cache'**
  String get noCache;

  /// No description provided for @helpAndFeedback.
  ///
  /// In en, this message translates to:
  /// **'Help & Feedback'**
  String get helpAndFeedback;

  /// No description provided for @helpAndFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'User guide, FAQ'**
  String get helpAndFeedbackDesc;

  /// No description provided for @versionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionNumber;

  /// No description provided for @buildTime.
  ///
  /// In en, this message translates to:
  /// **'Build Time'**
  String get buildTime;

  /// No description provided for @packageName.
  ///
  /// In en, this message translates to:
  /// **'Package Name'**
  String get packageName;

  /// No description provided for @userAgreement.
  ///
  /// In en, this message translates to:
  /// **'User Agreement'**
  String get userAgreement;

  /// No description provided for @logManagement.
  ///
  /// In en, this message translates to:
  /// **'Log Management'**
  String get logManagement;

  /// No description provided for @logManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'View and clean app logs'**
  String get logManagementDesc;

  /// No description provided for @copyrightText.
  ///
  /// In en, this message translates to:
  /// **'© {year} AI Bookkeeping\nSmart Finance Assistant'**
  String copyrightText(int year);

  /// No description provided for @smartFinanceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Smart Finance Assistant'**
  String get smartFinanceAssistant;

  /// No description provided for @downloadCacheManagement.
  ///
  /// In en, this message translates to:
  /// **'Download Cache Management'**
  String get downloadCacheManagement;

  /// No description provided for @cacheFileList.
  ///
  /// In en, this message translates to:
  /// **'Cache files:'**
  String get cacheFileList;

  /// No description provided for @clearingCache.
  ///
  /// In en, this message translates to:
  /// **'Clearing...'**
  String get clearingCache;

  /// No description provided for @clearAllCache.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAllCache;

  /// No description provided for @confirmClearCache.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all downloaded APKs and cache files?'**
  String get confirmClearCache;

  /// No description provided for @pauseBudget.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseBudget;

  /// No description provided for @enableBudget.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableBudget;

  /// No description provided for @clickToAddBudget.
  ///
  /// In en, this message translates to:
  /// **'Click top-right to add budget'**
  String get clickToAddBudget;

  /// No description provided for @confirmDeleteBudgetMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete budget \"{name}\"?'**
  String confirmDeleteBudgetMsg(String name);

  /// No description provided for @budgetNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monthly Total Budget'**
  String get budgetNameHint;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @carryoverToNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Carry surplus/overspent to next period'**
  String get carryoverToNextPeriod;

  /// No description provided for @carryoverSurplusOnly.
  ///
  /// In en, this message translates to:
  /// **'Surplus only'**
  String get carryoverSurplusOnly;

  /// No description provided for @carryoverSurplusOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Only carry positive balance to next period'**
  String get carryoverSurplusOnlyDesc;

  /// No description provided for @carryoverAll.
  ///
  /// In en, this message translates to:
  /// **'Surplus and deficit'**
  String get carryoverAll;

  /// No description provided for @carryoverAllDesc.
  ///
  /// In en, this message translates to:
  /// **'Carry positive or negative balance to next period'**
  String get carryoverAllDesc;

  /// No description provided for @traditionalBudget.
  ///
  /// In en, this message translates to:
  /// **'Traditional'**
  String get traditionalBudget;

  /// No description provided for @traditionalBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'Set fixed budget amount'**
  String get traditionalBudgetHint;

  /// No description provided for @zeroBudget.
  ///
  /// In en, this message translates to:
  /// **'Zero-based'**
  String get zeroBudget;

  /// No description provided for @zeroBudgetHint.
  ///
  /// In en, this message translates to:
  /// **'Allocate every dollar a job'**
  String get zeroBudgetHint;

  /// No description provided for @moneyAge.
  ///
  /// In en, this message translates to:
  /// **'Money Age'**
  String get moneyAge;

  /// No description provided for @moneyAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String moneyAgeDays(int days);

  /// No description provided for @whatIsMoneyAge.
  ///
  /// In en, this message translates to:
  /// **'What is Money Age?'**
  String get whatIsMoneyAge;

  /// No description provided for @moneyAgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Money Age is a key metric in zero-based budgeting. It shows how many days ago the money you\'re spending today was earned.'**
  String get moneyAgeDescription;

  /// No description provided for @excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get excellent;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fair;

  /// No description provided for @needsImprovement.
  ///
  /// In en, this message translates to:
  /// **'Needs Improvement'**
  String get needsImprovement;

  /// No description provided for @daysOrMore.
  ///
  /// In en, this message translates to:
  /// **'≥ {days} days'**
  String daysOrMore(int days);

  /// No description provided for @daysRange.
  ///
  /// In en, this message translates to:
  /// **'{min}-{max} days'**
  String daysRange(int min, int max);

  /// No description provided for @lessThanDays.
  ///
  /// In en, this message translates to:
  /// **'< {days} days'**
  String lessThanDays(int days);

  /// No description provided for @healthyCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Very healthy cash flow'**
  String get healthyCashFlow;

  /// No description provided for @goodCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Good cash flow'**
  String get goodCashFlow;

  /// No description provided for @considerSavingsBuffer.
  ///
  /// In en, this message translates to:
  /// **'Consider adding savings buffer'**
  String get considerSavingsBuffer;

  /// No description provided for @spendingRecentIncome.
  ///
  /// In en, this message translates to:
  /// **'May be spending recent income'**
  String get spendingRecentIncome;

  /// No description provided for @improveMoneyAgeTip.
  ///
  /// In en, this message translates to:
  /// **'How to improve: Control spending, increase income, build emergency fund'**
  String get improveMoneyAgeTip;

  /// No description provided for @budgetSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent ¥{amount}'**
  String budgetSpent(String amount);

  /// No description provided for @budgetTotal.
  ///
  /// In en, this message translates to:
  /// **'Budget ¥{amount}'**
  String budgetTotal(String amount);

  /// No description provided for @budgetRemainingAmount.
  ///
  /// In en, this message translates to:
  /// **'Remaining ¥{amount}'**
  String budgetRemainingAmount(String amount);

  /// No description provided for @budgetOverspentAmount.
  ///
  /// In en, this message translates to:
  /// **'Overspent ¥{amount}'**
  String budgetOverspentAmount(String amount);

  /// No description provided for @budgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget Name'**
  String get budgetName;

  /// No description provided for @myAccounts.
  ///
  /// In en, this message translates to:
  /// **'My Accounts'**
  String get myAccounts;

  /// No description provided for @liabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get liabilities;

  /// No description provided for @creditLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get creditLimit;

  /// No description provided for @repaymentDay.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get repaymentDay;

  /// No description provided for @dayUnit.
  ///
  /// In en, this message translates to:
  /// **'th'**
  String get dayUnit;

  /// No description provided for @transactionRecord.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionRecord;

  /// No description provided for @transactionDetail.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetail;

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchant;

  /// No description provided for @moneyAgeInfo.
  ///
  /// In en, this message translates to:
  /// **'Money Age Info'**
  String get moneyAgeInfo;

  /// No description provided for @moneyAgeUsedPrefix.
  ///
  /// In en, this message translates to:
  /// **'This expense used income from'**
  String get moneyAgeUsedPrefix;

  /// No description provided for @moneyAgeUsedSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get moneyAgeUsedSuffix;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// No description provided for @undoDelete.
  ///
  /// In en, this message translates to:
  /// **'Undo Delete'**
  String get undoDelete;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @deletedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name} ¥{amount}\"'**
  String deletedTransaction(String name, String amount);

  /// No description provided for @linkVault.
  ///
  /// In en, this message translates to:
  /// **'Link to Vault'**
  String get linkVault;

  /// No description provided for @noLink.
  ///
  /// In en, this message translates to:
  /// **'No Link'**
  String get noLink;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get addTag;

  /// No description provided for @saveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Save Transaction'**
  String get saveTransaction;

  /// No description provided for @totalDebt.
  ///
  /// In en, this message translates to:
  /// **'Total Debt'**
  String get totalDebt;

  /// No description provided for @dueThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Due This Month'**
  String get dueThisMonth;

  /// No description provided for @debtPaidPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Paid'**
  String debtPaidPercent(int percent);

  /// No description provided for @estimatedPayoffMonths.
  ///
  /// In en, this message translates to:
  /// **'Est. {months} months to pay off'**
  String estimatedPayoffMonths(int months);

  /// No description provided for @debtDetails.
  ///
  /// In en, this message translates to:
  /// **'Debt Details'**
  String get debtDetails;

  /// No description provided for @repaymentDayIn.
  ///
  /// In en, this message translates to:
  /// **'Due {day}th · {daysLeft}'**
  String repaymentDayIn(int day, String daysLeft);

  /// No description provided for @daysLater.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String daysLater(int days);

  /// No description provided for @currentBill.
  ///
  /// In en, this message translates to:
  /// **'Current Bill'**
  String get currentBill;

  /// No description provided for @installmentInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get installmentInProgress;

  /// No description provided for @installmentRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} payments left'**
  String installmentRemaining(int count);

  /// No description provided for @remainingPrincipal.
  ///
  /// In en, this message translates to:
  /// **'Remaining Principal'**
  String get remainingPrincipal;

  /// No description provided for @repaymentSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Repayment Suggestion'**
  String get repaymentSuggestion;

  /// No description provided for @prioritizeHighInterest.
  ///
  /// In en, this message translates to:
  /// **'Prioritize high-interest debt'**
  String get prioritizeHighInterest;

  /// No description provided for @consumerLoan.
  ///
  /// In en, this message translates to:
  /// **'Consumer Loan'**
  String get consumerLoan;

  /// No description provided for @smartAdvice.
  ///
  /// In en, this message translates to:
  /// **'Smart Advice'**
  String get smartAdvice;

  /// No description provided for @todayAdvice.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Advice'**
  String get todayAdvice;

  /// No description provided for @manageAdvicePreference.
  ///
  /// In en, this message translates to:
  /// **'Manage Advice Preferences'**
  String get manageAdvicePreference;

  /// No description provided for @financialFreedomSimulator.
  ///
  /// In en, this message translates to:
  /// **'Financial Freedom Simulator'**
  String get financialFreedomSimulator;

  /// No description provided for @yourFinancialFreedomJourney.
  ///
  /// In en, this message translates to:
  /// **'Your Financial Freedom Journey'**
  String get yourFinancialFreedomJourney;

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated Time'**
  String get estimatedTime;

  /// No description provided for @toAchieveFreedom.
  ///
  /// In en, this message translates to:
  /// **'To Achieve Freedom'**
  String get toAchieveFreedom;

  /// No description provided for @accelerateTip.
  ///
  /// In en, this message translates to:
  /// **'Accelerate Tip'**
  String get accelerateTip;

  /// No description provided for @adjustParameters.
  ///
  /// In en, this message translates to:
  /// **'Adjust Parameters'**
  String get adjustParameters;

  /// No description provided for @monthlySavings.
  ///
  /// In en, this message translates to:
  /// **'Monthly Savings'**
  String get monthlySavings;

  /// No description provided for @annualReturn.
  ///
  /// In en, this message translates to:
  /// **'Annual Return'**
  String get annualReturn;

  /// No description provided for @targetPassiveIncome.
  ///
  /// In en, this message translates to:
  /// **'Target Passive Income'**
  String get targetPassiveIncome;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimer;

  /// No description provided for @smartRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Smart Recommendation'**
  String get smartRecommendation;

  /// No description provided for @discoverNewFeature.
  ///
  /// In en, this message translates to:
  /// **'Discover New Feature'**
  String get discoverNewFeature;

  /// No description provided for @laterRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind Later'**
  String get laterRemind;

  /// No description provided for @aaSplit.
  ///
  /// In en, this message translates to:
  /// **'Split Bill'**
  String get aaSplit;

  /// No description provided for @aaDetected.
  ///
  /// In en, this message translates to:
  /// **'Split bill detected'**
  String get aaDetected;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @splitPeople.
  ///
  /// In en, this message translates to:
  /// **'Number of People'**
  String get splitPeople;

  /// No description provided for @splitMethod.
  ///
  /// In en, this message translates to:
  /// **'Split Method'**
  String get splitMethod;

  /// No description provided for @evenSplit.
  ///
  /// In en, this message translates to:
  /// **'Even Split'**
  String get evenSplit;

  /// No description provided for @proportionalSplit.
  ///
  /// In en, this message translates to:
  /// **'Proportional Split'**
  String get proportionalSplit;

  /// No description provided for @customSplit.
  ///
  /// In en, this message translates to:
  /// **'Custom Split'**
  String get customSplit;

  /// No description provided for @yourShare.
  ///
  /// In en, this message translates to:
  /// **'Your Share'**
  String get yourShare;

  /// No description provided for @confirmSplit.
  ///
  /// In en, this message translates to:
  /// **'Confirm Split'**
  String get confirmSplit;

  /// No description provided for @accessibilitySettings.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Settings'**
  String get accessibilitySettings;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get highContrast;

  /// No description provided for @boldText.
  ///
  /// In en, this message translates to:
  /// **'Bold Text'**
  String get boldText;

  /// No description provided for @screenReader.
  ///
  /// In en, this message translates to:
  /// **'Screen Reader'**
  String get screenReader;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce Motion'**
  String get reduceMotion;

  /// No description provided for @largeTouch.
  ///
  /// In en, this message translates to:
  /// **'Large Touch Targets'**
  String get largeTouch;

  /// No description provided for @aiLanguageSettings.
  ///
  /// In en, this message translates to:
  /// **'AI Language Settings'**
  String get aiLanguageSettings;

  /// No description provided for @aiReplyLanguage.
  ///
  /// In en, this message translates to:
  /// **'AI Reply Language'**
  String get aiReplyLanguage;

  /// No description provided for @aiVoice.
  ///
  /// In en, this message translates to:
  /// **'AI Voice'**
  String get aiVoice;

  /// No description provided for @maleVoice.
  ///
  /// In en, this message translates to:
  /// **'Male Voice'**
  String get maleVoice;

  /// No description provided for @femaleVoice.
  ///
  /// In en, this message translates to:
  /// **'Female Voice'**
  String get femaleVoice;

  /// No description provided for @familyLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Family Leaderboard'**
  String get familyLeaderboard;

  /// No description provided for @weeklyRanking.
  ///
  /// In en, this message translates to:
  /// **'Weekly Ranking'**
  String get weeklyRanking;

  /// No description provided for @monthlyRanking.
  ///
  /// In en, this message translates to:
  /// **'Monthly Ranking'**
  String get monthlyRanking;

  /// No description provided for @savingsChampion.
  ///
  /// In en, this message translates to:
  /// **'Savings Champion'**
  String get savingsChampion;

  /// No description provided for @budgetMaster.
  ///
  /// In en, this message translates to:
  /// **'Budget Master'**
  String get budgetMaster;

  /// No description provided for @familySavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Family Savings Goal'**
  String get familySavingsGoal;

  /// No description provided for @contributeNow.
  ///
  /// In en, this message translates to:
  /// **'Contribute Now'**
  String get contributeNow;

  /// No description provided for @goalAmount.
  ///
  /// In en, this message translates to:
  /// **'Goal Amount'**
  String get goalAmount;

  /// No description provided for @currentProgress.
  ///
  /// In en, this message translates to:
  /// **'Current Progress'**
  String get currentProgress;

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'Days Remaining'**
  String get daysRemaining;

  /// No description provided for @ledgerSettings.
  ///
  /// In en, this message translates to:
  /// **'Ledger Settings'**
  String get ledgerSettings;

  /// No description provided for @defaultLedger.
  ///
  /// In en, this message translates to:
  /// **'Default Ledger'**
  String get defaultLedger;

  /// No description provided for @ledgerName.
  ///
  /// In en, this message translates to:
  /// **'Ledger Name'**
  String get ledgerName;

  /// No description provided for @ledgerIcon.
  ///
  /// In en, this message translates to:
  /// **'Ledger Icon'**
  String get ledgerIcon;

  /// No description provided for @ledgerColor.
  ///
  /// In en, this message translates to:
  /// **'Ledger Color'**
  String get ledgerColor;

  /// No description provided for @archiveLedger.
  ///
  /// In en, this message translates to:
  /// **'Archive Ledger'**
  String get archiveLedger;

  /// No description provided for @locationServices.
  ///
  /// In en, this message translates to:
  /// **'Location Services'**
  String get locationServices;

  /// No description provided for @enableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get enableLocation;

  /// No description provided for @locationAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Location Accuracy'**
  String get locationAccuracy;

  /// No description provided for @highAccuracy.
  ///
  /// In en, this message translates to:
  /// **'High Accuracy'**
  String get highAccuracy;

  /// No description provided for @lowPower.
  ///
  /// In en, this message translates to:
  /// **'Low Power'**
  String get lowPower;

  /// No description provided for @geofenceAlerts.
  ///
  /// In en, this message translates to:
  /// **'Geofence Alerts'**
  String get geofenceAlerts;

  /// No description provided for @nearbyMerchants.
  ///
  /// In en, this message translates to:
  /// **'Nearby Merchants'**
  String get nearbyMerchants;

  /// No description provided for @duplicateTransaction.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Transaction'**
  String get duplicateTransaction;

  /// No description provided for @transactionTime.
  ///
  /// In en, this message translates to:
  /// **'Transaction Time'**
  String get transactionTime;

  /// No description provided for @transactionNote.
  ///
  /// In en, this message translates to:
  /// **'Transaction Note'**
  String get transactionNote;

  /// No description provided for @transactionTags.
  ///
  /// In en, this message translates to:
  /// **'Transaction Tags'**
  String get transactionTags;

  /// No description provided for @transactionLocation.
  ///
  /// In en, this message translates to:
  /// **'Transaction Location'**
  String get transactionLocation;

  /// No description provided for @transactionAttachments.
  ///
  /// In en, this message translates to:
  /// **'Transaction Attachments'**
  String get transactionAttachments;

  /// No description provided for @budgetWarning.
  ///
  /// In en, this message translates to:
  /// **'Budget Warning'**
  String get budgetWarning;

  /// No description provided for @moneyAgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Money Age Analysis'**
  String get moneyAgeTitle;

  /// No description provided for @moneyAgeDescription2.
  ///
  /// In en, this message translates to:
  /// **'Understand your cash flow efficiency'**
  String get moneyAgeDescription2;

  /// No description provided for @averageMoneyAge.
  ///
  /// In en, this message translates to:
  /// **'Average Money Age'**
  String get averageMoneyAge;

  /// No description provided for @moneyAgeHealth.
  ///
  /// In en, this message translates to:
  /// **'Money Age Health'**
  String get moneyAgeHealth;

  /// No description provided for @poor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get poor;

  /// No description provided for @habitTracking.
  ///
  /// In en, this message translates to:
  /// **'Habit Tracking'**
  String get habitTracking;

  /// No description provided for @dailyStreak.
  ///
  /// In en, this message translates to:
  /// **'Daily Streak'**
  String get dailyStreak;

  /// No description provided for @weeklyGoal.
  ///
  /// In en, this message translates to:
  /// **'Weekly Goal'**
  String get weeklyGoal;

  /// No description provided for @monthlyGoal.
  ///
  /// In en, this message translates to:
  /// **'Monthly Goal'**
  String get monthlyGoal;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String streakDays(int count);

  /// No description provided for @achievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement Unlocked'**
  String get achievementUnlocked;

  /// No description provided for @viewAchievements.
  ///
  /// In en, this message translates to:
  /// **'View Achievements'**
  String get viewAchievements;

  /// No description provided for @shareAchievement.
  ///
  /// In en, this message translates to:
  /// **'Share Achievement'**
  String get shareAchievement;

  /// No description provided for @achievementProgress.
  ///
  /// In en, this message translates to:
  /// **'Achievement Progress'**
  String get achievementProgress;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @voiceError.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition failed'**
  String get voiceError;

  /// No description provided for @speakNow.
  ///
  /// In en, this message translates to:
  /// **'Speak now'**
  String get speakNow;

  /// No description provided for @scanBill.
  ///
  /// In en, this message translates to:
  /// **'Scan Bill'**
  String get scanBill;

  /// No description provided for @recognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing...'**
  String get recognizing;

  /// No description provided for @recognitionFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition Failed'**
  String get recognitionFailed;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync Complete'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed'**
  String get syncFailed;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last Synced'**
  String get lastSynced;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @offlineData.
  ///
  /// In en, this message translates to:
  /// **'Offline Data'**
  String get offlineData;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending Sync'**
  String get pendingSync;

  /// No description provided for @offlineChanges.
  ///
  /// In en, this message translates to:
  /// **'Offline Changes'**
  String get offlineChanges;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy Settings'**
  String get privacySettings;

  /// No description provided for @dataEncryption.
  ///
  /// In en, this message translates to:
  /// **'Data Encryption'**
  String get dataEncryption;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Biometric Lock'**
  String get biometricLock;

  /// No description provided for @autoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto Lock'**
  String get autoLock;

  /// No description provided for @lockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock Timeout'**
  String get lockTimeout;

  /// No description provided for @budgetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budget Alerts'**
  String get budgetAlerts;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get dailyReminder;

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get exportFormat;

  /// No description provided for @csvFormat.
  ///
  /// In en, this message translates to:
  /// **'CSV Format'**
  String get csvFormat;

  /// No description provided for @excelFormat.
  ///
  /// In en, this message translates to:
  /// **'Excel Format'**
  String get excelFormat;

  /// No description provided for @jsonFormat.
  ///
  /// In en, this message translates to:
  /// **'JSON Format'**
  String get jsonFormat;

  /// No description provided for @feedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Feedback Submitted'**
  String get feedbackSubmitted;

  /// No description provided for @thankYouFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback'**
  String get thankYouFeedback;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @upgradeRequired.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Required'**
  String get upgradeRequired;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginToUseFeature.
  ///
  /// In en, this message translates to:
  /// **'Login to use this feature'**
  String get loginToUseFeature;

  /// No description provided for @loginNow.
  ///
  /// In en, this message translates to:
  /// **'Login Now'**
  String get loginNow;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get connectionFailed;

  /// No description provided for @checkNetwork.
  ///
  /// In en, this message translates to:
  /// **'Please check your network connection'**
  String get checkNetwork;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// No description provided for @locationPermission.
  ///
  /// In en, this message translates to:
  /// **'Location Permission'**
  String get locationPermission;

  /// No description provided for @storagePermission.
  ///
  /// In en, this message translates to:
  /// **'Storage Permission'**
  String get storagePermission;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get deleteWarning;

  /// No description provided for @permanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Permanently Delete'**
  String get permanentlyDelete;

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get moveToTrash;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchPlaceholder;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get noResults;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search History'**
  String get searchHistory;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @filterBy.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterBy;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @amountRange.
  ///
  /// In en, this message translates to:
  /// **'Amount Range'**
  String get amountRange;

  /// No description provided for @categoryFilter.
  ///
  /// In en, this message translates to:
  /// **'Category Filter'**
  String get categoryFilter;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @byDate.
  ///
  /// In en, this message translates to:
  /// **'By Date'**
  String get byDate;

  /// No description provided for @byAmount.
  ///
  /// In en, this message translates to:
  /// **'By Amount'**
  String get byAmount;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get byCategory;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @batchDelete.
  ///
  /// In en, this message translates to:
  /// **'Batch Delete'**
  String get batchDelete;

  /// No description provided for @batchEdit.
  ///
  /// In en, this message translates to:
  /// **'Batch Edit'**
  String get batchEdit;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @actionUndone.
  ///
  /// In en, this message translates to:
  /// **'Action Undone'**
  String get actionUndone;

  /// No description provided for @actionRedone.
  ///
  /// In en, this message translates to:
  /// **'Action Redone'**
  String get actionRedone;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to Refresh'**
  String get pullToRefresh;

  /// No description provided for @releaseToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Release to Refresh'**
  String get releaseToRefresh;

  /// No description provided for @emptyState.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get emptyState;

  /// No description provided for @addFirst.
  ///
  /// In en, this message translates to:
  /// **'Add First Record'**
  String get addFirst;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @frequentCategories.
  ///
  /// In en, this message translates to:
  /// **'Frequent Categories'**
  String get frequentCategories;

  /// No description provided for @suggestedActions.
  ///
  /// In en, this message translates to:
  /// **'Suggested Actions'**
  String get suggestedActions;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @autoDetected.
  ///
  /// In en, this message translates to:
  /// **'Auto Detected'**
  String get autoDetected;

  /// No description provided for @myShare.
  ///
  /// In en, this message translates to:
  /// **'My Share'**
  String get myShare;

  /// No description provided for @perPerson.
  ///
  /// In en, this message translates to:
  /// **'Per Person'**
  String get perPerson;

  /// No description provided for @bookkeepingMode.
  ///
  /// In en, this message translates to:
  /// **'Bookkeeping Mode'**
  String get bookkeepingMode;

  /// No description provided for @onlyMyShare.
  ///
  /// In en, this message translates to:
  /// **'Only My Share'**
  String get onlyMyShare;

  /// No description provided for @recordTotal.
  ///
  /// In en, this message translates to:
  /// **'Record Total'**
  String get recordTotal;

  /// No description provided for @largeTouchTarget.
  ///
  /// In en, this message translates to:
  /// **'Large Touch Target'**
  String get largeTouchTarget;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @adminDesc.
  ///
  /// In en, this message translates to:
  /// **'Admin permission description'**
  String get adminDesc;

  /// No description provided for @aiParsing.
  ///
  /// In en, this message translates to:
  /// **'AI Parsing'**
  String get aiParsing;

  /// No description provided for @aiParsingOfflineDesc.
  ///
  /// In en, this message translates to:
  /// **'AI parsing unavailable in offline mode'**
  String get aiParsingOfflineDesc;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @annualReview.
  ///
  /// In en, this message translates to:
  /// **'Annual Review'**
  String get annualReview;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLock;

  /// No description provided for @askAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask Anything'**
  String get askAnything;

  /// No description provided for @autoExtracted.
  ///
  /// In en, this message translates to:
  /// **'Auto Extracted'**
  String get autoExtracted;

  /// No description provided for @autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get autoSync;

  /// No description provided for @autoSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync data to cloud'**
  String get autoSyncDesc;

  /// No description provided for @badgesWall.
  ///
  /// In en, this message translates to:
  /// **'Badges Wall'**
  String get badgesWall;

  /// No description provided for @basicRecording.
  ///
  /// In en, this message translates to:
  /// **'Basic Recording'**
  String get basicRecording;

  /// No description provided for @biggestGoal.
  ///
  /// In en, this message translates to:
  /// **'Biggest Goal'**
  String get biggestGoal;

  /// No description provided for @billDueReminder.
  ///
  /// In en, this message translates to:
  /// **'Bill Due Reminder'**
  String get billDueReminder;

  /// No description provided for @budgetOverflowAlert.
  ///
  /// In en, this message translates to:
  /// **'Budget Overflow Alert'**
  String get budgetOverflowAlert;

  /// No description provided for @budgetOverspentAlert.
  ///
  /// In en, this message translates to:
  /// **'Budget Overspent'**
  String get budgetOverspentAlert;

  /// No description provided for @budgetQuery.
  ///
  /// In en, this message translates to:
  /// **'Budget Query'**
  String get budgetQuery;

  /// No description provided for @choosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose Plan'**
  String get choosePlan;

  /// No description provided for @completeUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Complete Upgrade'**
  String get completeUpgrade;

  /// No description provided for @confidenceLevel.
  ///
  /// In en, this message translates to:
  /// **'Confidence Level'**
  String get confidenceLevel;

  /// No description provided for @confirmBookkeeping.
  ///
  /// In en, this message translates to:
  /// **'Confirm Bookkeeping'**
  String get confirmBookkeeping;

  /// No description provided for @continueAsking.
  ///
  /// In en, this message translates to:
  /// **'Continue Asking'**
  String get continueAsking;

  /// No description provided for @continueOffline.
  ///
  /// In en, this message translates to:
  /// **'Continue Offline'**
  String get continueOffline;

  /// No description provided for @continuousChat.
  ///
  /// In en, this message translates to:
  /// **'Continuous Chat'**
  String get continuousChat;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get copyLink;

  /// No description provided for @createFamilyLedger.
  ///
  /// In en, this message translates to:
  /// **'Create Family Ledger'**
  String get createFamilyLedger;

  /// No description provided for @currentPermissions.
  ///
  /// In en, this message translates to:
  /// **'Current Permissions'**
  String get currentPermissions;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @dataSecurityGuarantee.
  ///
  /// In en, this message translates to:
  /// **'Data Security Guarantee'**
  String get dataSecurityGuarantee;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormat;

  /// No description provided for @daysRecording.
  ///
  /// In en, this message translates to:
  /// **'days recording'**
  String get daysRecording;

  /// No description provided for @defaultVisibility.
  ///
  /// In en, this message translates to:
  /// **'Default Visibility'**
  String get defaultVisibility;

  /// No description provided for @deleteLedger.
  ///
  /// In en, this message translates to:
  /// **'Delete Ledger'**
  String get deleteLedger;

  /// No description provided for @depositNow.
  ///
  /// In en, this message translates to:
  /// **'Deposit Now'**
  String get depositNow;

  /// No description provided for @detailedStats.
  ///
  /// In en, this message translates to:
  /// **'Detailed Stats'**
  String get detailedStats;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @examples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get examples;

  /// No description provided for @faceIdUnlock.
  ///
  /// In en, this message translates to:
  /// **'Face ID Unlock'**
  String get faceIdUnlock;

  /// No description provided for @familyContributions.
  ///
  /// In en, this message translates to:
  /// **'Family Contributions'**
  String get familyContributions;

  /// No description provided for @familyDinners.
  ///
  /// In en, this message translates to:
  /// **'Family Dinners'**
  String get familyDinners;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feature;

  /// No description provided for @fingerprintUnlock.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint Unlock'**
  String get fingerprintUnlock;

  /// No description provided for @fullMode.
  ///
  /// In en, this message translates to:
  /// **'Full Mode'**
  String get fullMode;

  /// No description provided for @generateBirthdayCard.
  ///
  /// In en, this message translates to:
  /// **'Generate Birthday Card'**
  String get generateBirthdayCard;

  /// No description provided for @geofenceReminder.
  ///
  /// In en, this message translates to:
  /// **'Geofence Reminder'**
  String get geofenceReminder;

  /// No description provided for @getSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Get Suggestion'**
  String get getSuggestion;

  /// No description provided for @growth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get growth;

  /// No description provided for @hideAmount.
  ///
  /// In en, this message translates to:
  /// **'Hide Amount'**
  String get hideAmount;

  /// No description provided for @hideAmountDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide amount display in lists'**
  String get hideAmountDesc;

  /// No description provided for @hobbies.
  ///
  /// In en, this message translates to:
  /// **'Hobbies'**
  String get hobbies;

  /// No description provided for @homeLayout.
  ///
  /// In en, this message translates to:
  /// **'Home Layout'**
  String get homeLayout;

  /// No description provided for @inputHint.
  ///
  /// In en, this message translates to:
  /// **'Input Hint'**
  String get inputHint;

  /// No description provided for @inputToBookkeep.
  ///
  /// In en, this message translates to:
  /// **'Input to Bookkeep'**
  String get inputToBookkeep;

  /// No description provided for @inviteFamily.
  ///
  /// In en, this message translates to:
  /// **'Invite Family'**
  String get inviteFamily;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @leaveLedger.
  ///
  /// In en, this message translates to:
  /// **'Leave Ledger'**
  String get leaveLedger;

  /// No description provided for @ledgerType.
  ///
  /// In en, this message translates to:
  /// **'Ledger Type'**
  String get ledgerType;

  /// No description provided for @locationAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Location Analysis'**
  String get locationAnalysis;

  /// No description provided for @locationAnalysisReport.
  ///
  /// In en, this message translates to:
  /// **'Location Analysis Report'**
  String get locationAnalysisReport;

  /// No description provided for @lowConfidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Low Confidence'**
  String get lowConfidenceTitle;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @memberBenefits.
  ///
  /// In en, this message translates to:
  /// **'Member Benefits'**
  String get memberBenefits;

  /// No description provided for @memberContribution.
  ///
  /// In en, this message translates to:
  /// **'Member Contribution'**
  String get memberContribution;

  /// No description provided for @memberDesc.
  ///
  /// In en, this message translates to:
  /// **'Member description'**
  String get memberDesc;

  /// No description provided for @memberPermissions.
  ///
  /// In en, this message translates to:
  /// **'Member Permissions'**
  String get memberPermissions;

  /// No description provided for @memberRecordNotify.
  ///
  /// In en, this message translates to:
  /// **'Member Record Notify'**
  String get memberRecordNotify;

  /// No description provided for @membershipService.
  ///
  /// In en, this message translates to:
  /// **'Membership Service'**
  String get membershipService;

  /// No description provided for @memberVoteStatus.
  ///
  /// In en, this message translates to:
  /// **'Member Vote Status'**
  String get memberVoteStatus;

  /// No description provided for @moneyAgeQuery.
  ///
  /// In en, this message translates to:
  /// **'Money Age Query'**
  String get moneyAgeQuery;

  /// No description provided for @monthlySharedExpense.
  ///
  /// In en, this message translates to:
  /// **'Monthly Shared Expense'**
  String get monthlySharedExpense;

  /// No description provided for @naturalLanguageInput.
  ///
  /// In en, this message translates to:
  /// **'Natural Language Input'**
  String get naturalLanguageInput;

  /// No description provided for @networkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Network Unavailable'**
  String get networkUnavailable;

  /// No description provided for @noVoiceHistory.
  ///
  /// In en, this message translates to:
  /// **'No Voice History'**
  String get noVoiceHistory;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number Format'**
  String get numberFormat;

  /// No description provided for @offlineModeActive.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode Active'**
  String get offlineModeActive;

  /// No description provided for @offlineModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Offline mode description'**
  String get offlineModeDesc;

  /// No description provided for @offlineModeFullDesc.
  ///
  /// In en, this message translates to:
  /// **'In offline mode, data is stored locally and synced when online'**
  String get offlineModeFullDesc;

  /// No description provided for @offlineVoice.
  ///
  /// In en, this message translates to:
  /// **'Offline Voice'**
  String get offlineVoice;

  /// No description provided for @offlineVoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Offline voice recognition'**
  String get offlineVoiceDesc;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @onlyOwnerCanDelete.
  ///
  /// In en, this message translates to:
  /// **'Only Owner Can Delete'**
  String get onlyOwnerCanDelete;

  /// No description provided for @originalText.
  ///
  /// In en, this message translates to:
  /// **'Original Text'**
  String get originalText;

  /// No description provided for @otherSavingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Other Savings Goals'**
  String get otherSavingsGoals;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @ownerDesc.
  ///
  /// In en, this message translates to:
  /// **'Owner description'**
  String get ownerDesc;

  /// No description provided for @permissionSettings.
  ///
  /// In en, this message translates to:
  /// **'Permission Settings'**
  String get permissionSettings;

  /// No description provided for @preciseLocationService.
  ///
  /// In en, this message translates to:
  /// **'Precise Location Service'**
  String get preciseLocationService;

  /// No description provided for @preventScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Prevent Screenshot'**
  String get preventScreenshot;

  /// No description provided for @privacyMode.
  ///
  /// In en, this message translates to:
  /// **'Privacy Mode'**
  String get privacyMode;

  /// No description provided for @pushNotification.
  ///
  /// In en, this message translates to:
  /// **'Push Notification'**
  String get pushNotification;

  /// No description provided for @qrCodeInvite.
  ///
  /// In en, this message translates to:
  /// **'QR Code Invite'**
  String get qrCodeInvite;

  /// No description provided for @quickBookkeep.
  ///
  /// In en, this message translates to:
  /// **'Quick Bookkeep'**
  String get quickBookkeep;

  /// No description provided for @quickBookkeeping.
  ///
  /// In en, this message translates to:
  /// **'Quick Bookkeeping'**
  String get quickBookkeeping;

  /// No description provided for @quickQuestions.
  ///
  /// In en, this message translates to:
  /// **'Quick Questions'**
  String get quickQuestions;

  /// No description provided for @receiptDetail.
  ///
  /// In en, this message translates to:
  /// **'Receipt Detail'**
  String get receiptDetail;

  /// No description provided for @recentDeposits.
  ///
  /// In en, this message translates to:
  /// **'Recent Deposits'**
  String get recentDeposits;

  /// No description provided for @recentRecords.
  ///
  /// In en, this message translates to:
  /// **'Recent Records'**
  String get recentRecords;

  /// No description provided for @recordLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Record Leaderboard'**
  String get recordLeaderboard;

  /// No description provided for @regionSettings.
  ///
  /// In en, this message translates to:
  /// **'Region Settings'**
  String get regionSettings;

  /// No description provided for @remind.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get remind;

  /// No description provided for @remoteSpendingRecord.
  ///
  /// In en, this message translates to:
  /// **'Remote Spending Record'**
  String get remoteSpendingRecord;

  /// No description provided for @residentLocations.
  ///
  /// In en, this message translates to:
  /// **'Resident Locations'**
  String get residentLocations;

  /// No description provided for @retryNetwork.
  ///
  /// In en, this message translates to:
  /// **'Retry Network'**
  String get retryNetwork;

  /// No description provided for @retryOnline.
  ///
  /// In en, this message translates to:
  /// **'Retry Online'**
  String get retryOnline;

  /// No description provided for @roleRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Role Recommendation'**
  String get roleRecommendation;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @saveImage.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get saveImage;

  /// No description provided for @savingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings Goals'**
  String get savingsGoals;

  /// No description provided for @savingsLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Savings Leaderboard'**
  String get savingsLeaderboard;

  /// No description provided for @scanToJoin.
  ///
  /// In en, this message translates to:
  /// **'Scan to Join'**
  String get scanToJoin;

  /// No description provided for @securityLog.
  ///
  /// In en, this message translates to:
  /// **'Security Log'**
  String get securityLog;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// No description provided for @sendInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Send Invite Link'**
  String get sendInviteLink;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get setPin;

  /// No description provided for @sharedTime.
  ///
  /// In en, this message translates to:
  /// **'Shared Time'**
  String get sharedTime;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Share Link'**
  String get shareLink;

  /// No description provided for @shareToFamily.
  ///
  /// In en, this message translates to:
  /// **'Share to Family'**
  String get shareToFamily;

  /// No description provided for @showQRCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR Code'**
  String get showQRCode;

  /// No description provided for @simpleMode.
  ///
  /// In en, this message translates to:
  /// **'Simple Mode'**
  String get simpleMode;

  /// No description provided for @smartTextInput.
  ///
  /// In en, this message translates to:
  /// **'Smart Text Input'**
  String get smartTextInput;

  /// No description provided for @startUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Start Upgrade'**
  String get startUpgrade;

  /// No description provided for @staySimple.
  ///
  /// In en, this message translates to:
  /// **'Stay Simple'**
  String get staySimple;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @timeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time Format'**
  String get timeFormat;

  /// No description provided for @tripsCount.
  ///
  /// In en, this message translates to:
  /// **'Trips Count'**
  String get tripsCount;

  /// No description provided for @typeOrSpeak.
  ///
  /// In en, this message translates to:
  /// **'Type or Speak'**
  String get typeOrSpeak;

  /// No description provided for @upgradeDescription.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Description'**
  String get upgradeDescription;

  /// No description provided for @upgradeMode.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Mode'**
  String get upgradeMode;

  /// No description provided for @upgradeNotice.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Notice'**
  String get upgradeNotice;

  /// No description provided for @upgradeNoticeDesc.
  ///
  /// In en, this message translates to:
  /// **'Upgrade notice description'**
  String get upgradeNoticeDesc;

  /// No description provided for @upgradeToFullMode.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Full Mode'**
  String get upgradeToFullMode;

  /// No description provided for @upgradeVote.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Vote'**
  String get upgradeVote;

  /// No description provided for @useOffline.
  ///
  /// In en, this message translates to:
  /// **'Use Offline'**
  String get useOffline;

  /// No description provided for @viewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get viewer;

  /// No description provided for @viewerDesc.
  ///
  /// In en, this message translates to:
  /// **'Viewer description'**
  String get viewerDesc;

  /// No description provided for @viewStats.
  ///
  /// In en, this message translates to:
  /// **'View Stats'**
  String get viewStats;

  /// No description provided for @visibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Visibility description'**
  String get visibilityDesc;

  /// No description provided for @voiceAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice Assistant'**
  String get voiceAssistant;

  /// No description provided for @voiceChat.
  ///
  /// In en, this message translates to:
  /// **'Voice Chat'**
  String get voiceChat;

  /// No description provided for @voiceHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Voice history hint'**
  String get voiceHistoryHint;

  /// No description provided for @voiceHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice History'**
  String get voiceHistoryTitle;

  /// No description provided for @voteComplete.
  ///
  /// In en, this message translates to:
  /// **'Vote Complete'**
  String get voteComplete;

  /// No description provided for @voteRules.
  ///
  /// In en, this message translates to:
  /// **'Vote Rules'**
  String get voteRules;

  /// No description provided for @waitingForVotes.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Votes'**
  String get waitingForVotes;

  /// No description provided for @warmestMoment.
  ///
  /// In en, this message translates to:
  /// **'Warmest Moment'**
  String get warmestMoment;

  /// No description provided for @weekStartDay.
  ///
  /// In en, this message translates to:
  /// **'Week Start Day'**
  String get weekStartDay;

  /// No description provided for @yearlyWarmMoments.
  ///
  /// In en, this message translates to:
  /// **'Yearly Warm Moments'**
  String get yearlyWarmMoments;

  /// No description provided for @youCanAsk.
  ///
  /// In en, this message translates to:
  /// **'You Can Ask'**
  String get youCanAsk;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return SZhCn();
          case 'TW':
            return SZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'ja':
      return SJa();
    case 'ko':
      return SKo();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
