# 页面映射报告

**代码页面总数**: 213
**原型页面总数**: 145
**未被引用页面数**: 8

**已匹配页面**: 68 (代码实现了原型设计的页面)
**未匹配页面**: 145 (代码中有但原型中没有的页面)
**未被引用且未匹配**: 4 (强烈建议删除)

## 关键发现

### ❌ 建议删除的页面 (4个)

这些页面既没有在原型中定义，也没有被任何其他页面引用，可能是死代码：

- `aa_split_page.dart` (AaSplitPage)
- `ai_learning_curve_page.dart` (AiLearningCurvePage)
- `batch_ai_training_page.dart` (BatchAiTrainingPage)
- `multimodal_wakeup_settings_page.dart` (MultimodalWakeupSettingsPage)

### ⚠️ 需要添加入口的页面 (4个)

这些页面在原型中有定义，但没有被任何页面引用，需要添加导航入口：

- `ai/ai_cost_monitor_page.dart` (AiCostMonitorPage) - 14.09 AI成本监控
- `ai_language_settings_page.dart` (AiLanguageSettingsPage) - 8.06 AI语言设置
- `ai/ai_learning_report_page.dart` (AiLearningReportPage) - 14.10 智能学习报告
- `vault_ai_suggestion_page.dart` (VaultAiSuggestionPage) - 3.05 智能分配建议

## 完整页面对照表

| 文件名 | 类名 | 原型编号 | 中文名称 | 是否被引用 | 建议 |
|--------|------|----------|----------|------------|------|
| aa_split_page.dart | AaSplitPage | - | 未匹配 | ❌ | **可能需要删除** |
| about_page.dart | AboutPage | - | 未匹配 | ✅ | 检查是否需要 |
| accessibility_settings_page.dart | AccessibilitySettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| account_list_page.dart | AccountListPage | 4.01 | 账户列表 | ✅ | 正常 |
| account_management_page.dart | AccountManagementPage | 8.10 | 账户管理 | ✅ | 正常 |
| account_pages.dart | AccountsPage | - | 未匹配 | ✅ | 检查是否需要 |
| growth/achievement_share_page.dart | AchievementSharePage | 16.05 | 成就分享 | ✅ | 正常 |
| actionable_advice_page.dart | ActionableAdvicePage | - | 未匹配 | ✅ | 检查是否需要 |
| add_transaction_page.dart | AddTransactionPage | 1.03 | 快速记账 Quick Add | ✅ | 正常 |
| advanced_filter_page.dart | AdvancedFilterPage | 9.03 | 高级筛选 | ✅ | 正常 |
| agreement_page.dart | AgreementPage | - | 未匹配 | ✅ | 检查是否需要 |
| ai/ai_cost_monitor_page.dart | AiCostMonitorPage | 14.09 | AI成本监控 | ⚠️ | 需添加入口 |
| ai_language_settings_page.dart | AiLanguageSettingsPage | 8.06 | AI语言设置 | ⚠️ | 需添加入口 |
| ai_learning_curve_page.dart | AiLearningCurvePage | - | 未匹配 | ❌ | **可能需要删除** |
| ai/ai_learning_report_page.dart | AiLearningReportPage | 14.10 | 智能学习报告 | ⚠️ | 需添加入口 |
| observability/alert_history_page.dart | AlertHistoryPage | 12.04 | 告警历史 | ✅ | 正常 |
| allocation_page.dart | AllocationPage | - | 未匹配 | ✅ | 检查是否需要 |
| annual_report_page.dart | AnnualReportPage | - | 未匹配 | ✅ | 检查是否需要 |
| reports/annual_summary_page.dart | AnnualSummaryPage | 7.03 | 年度总结 | ✅ | 正常 |
| ai/anomaly_detection_settings_page.dart | AnomalyDetectionSettingsPage | 14.04 | 异常检测设置 | ✅ | 正常 |
| ai/anomaly_transaction_detail_page.dart | AnomalyTransactionDetailPage | 14.05 | 异常交易详情 | ✅ | 正常 |
| observability/app_health_page.dart | AppHealthPage | - | 未匹配 | ✅ | 检查是否需要 |
| app_lock_settings_page.dart | AppLockSettingsPage | 8.20 | 应用锁设置 | ✅ | 正常 |
| asset_overview_page.dart | AssetOverviewPage | - | 未匹配 | ✅ | 检查是否需要 |
| backup_page.dart | BackupPage | - | 未匹配 | ✅ | 检查是否需要 |
| batch_ai_training_page.dart | BatchAiTrainingPage | - | 未匹配 | ❌ | **可能需要删除** |
| import/batch_edit_page.dart | BatchEditPage | 5.07 | 批量编辑 | ✅ | 正常 |
| bill_reminders/bill_calendar_page.dart | BillCalendarPage | - | 未匹配 | ✅ | 检查是否需要 |
| bill_reminders/bill_detail_page.dart | BillDetailPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/bill_export_tutorial_page.dart | BillExportTutorialPage | - | 未匹配 | ✅ | 检查是否需要 |
| bill_reminder_page.dart | BillReminderPage | - | 未匹配 | ✅ | 检查是否需要 |
| budget_carryover_settings_page.dart | BudgetCarryoverSettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| budget_center_page.dart | BudgetCenterPage | 1.04 | 预算中心 Budget | ✅ | 正常 |
| budget_health_page.dart | BudgetHealthPage | - | 未匹配 | ✅ | 检查是否需要 |
| budget_management_page.dart | BudgetManagementPage | - | 未匹配 | ✅ | 检查是否需要 |
| budget_money_age_page.dart | BudgetMoneyAgePage | - | 未匹配 | ✅ | 检查是否需要 |
| reports/budget_report_page.dart | BudgetReportPage | 7.04 | 预算报告 | ✅ | 正常 |
| category_detail_page.dart | CategoryDetailPage | 9.01 | 分类详情 | ✅ | 正常 |
| category_management_page.dart | CategoryManagementPage | 8.09 | 分类管理 | ✅ | 正常 |
| reports/category_pie_drill_page.dart | CategoryPieDrillPage | - | 未匹配 | ✅ | 检查是否需要 |
| reports/chart_share_page.dart | ChartSharePage | 7.10 | 图表分享 | ✅ | 正常 |
| ai/chat_assistant_settings_page.dart | ChatAssistantSettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| ai/classification_feedback_page.dart | ClassificationFeedbackPage | - | 未匹配 | ✅ | 检查是否需要 |
| credit_card_page.dart | CreditCardPage | - | 未匹配 | ✅ | 检查是否需要 |
| bill_reminders/credit_card_repayment_page.dart | CreditCardRepaymentPage | - | 未匹配 | ✅ | 检查是否需要 |
| currency_settings_page.dart | CurrencySettingsPage | 8.04 | 货币设置 | ✅ | 正常 |
| custom_report_page.dart | CustomReportPage | - | 未匹配 | ✅ | 检查是否需要 |
| custom_theme_page.dart | CustomThemePage | - | 未匹配 | ✅ | 检查是否需要 |
| reports/data_filter_page.dart | DataFilterPage | 7.09 | 数据筛选 | ✅ | 正常 |
| exception/data_integrity_check_page.dart | DataIntegrityCheckPage | 11.03 | 数据完整性检查 | ✅ | 正常 |
| data_management_page.dart | DataManagementPage | 8.25 | 数据管理 | ✅ | 正常 |
| debt_management_page.dart | DebtManagementPage | 4.05 | 债务管理 | ✅ | 正常 |
| debt_simulator_page.dart | DebtSimulatorPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/deduplication_page.dart | DeduplicationPage | - | 未匹配 | ✅ | 检查是否需要 |
| growth/detractor_care_page.dart | DetractorCarePage | - | 未匹配 | ✅ | 检查是否需要 |
| observability/diagnostic_report_page.dart | DiagnosticReportPage | 12.06 | 诊断报告 | ✅ | 正常 |
| reports/drill_navigation_page.dart | DrillNavigationPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/duplicate_detection_page.dart | DuplicateDetectionPage | 5.02 | 去重检测 | ✅ | 正常 |
| emergency_fund_page.dart | EmergencyFundPage | - | 未匹配 | ✅ | 检查是否需要 |
| enhanced_voice_assistant_page.dart | EnhancedVoiceAssistantPage | - | 未匹配 | ✅ | 检查是否需要 |
| reports/expense_heatmap_page.dart | ExpenseHeatmapPage | - | 未匹配 | ✅ | 检查是否需要 |
| expense_target_page.dart | ExpenseTargetPage | - | 未匹配 | ✅ | 检查是否需要 |
| export/export_advanced_config_page.dart | ExportAdvancedConfigPage | 5.14 | 导出高级配置 | ✅ | 正常 |
| export_import_pages.dart | ExportImportsPage | - | 未匹配 | ✅ | 检查是否需要 |
| export_page.dart | ExportPage | - | 未匹配 | ✅ | 检查是否需要 |
| family_annual_review_page.dart | FamilyAnnualReviewPage | - | 未匹配 | ✅ | 检查是否需要 |
| family_birthday_page.dart | FamilyBirthdayPage | - | 未匹配 | ✅ | 检查是否需要 |
| family_leaderboard_page.dart | FamilyLeaderboardPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/family_member_assignment_page.dart | FamilyMemberAssignmentPage | - | 未匹配 | ✅ | 检查是否需要 |
| family_savings_goal_page.dart | FamilySavingsGoalPage | - | 未匹配 | ✅ | 检查是否需要 |
| family_simple_mode_page.dart | FamilySimpleModePage | - | 未匹配 | ✅ | 检查是否需要 |
| import/field_mapping_page.dart | FieldMappingPage | 5.10 | 字段映射配置 | ✅ | 正常 |
| financial_commitment_page.dart | FinancialCommitmentPage | - | 未匹配 | ✅ | 检查是否需要 |
| financial_freedom_simulator_page.dart | FinancialFreedomSimulatorPage | - | 未匹配 | ✅ | 检查是否需要 |
| financial_health_dashboard_page.dart | FinancialHealthDashboardPage | 10.01 | 财务健康仪表盘 | ✅ | 正常 |
| forgot_password_page.dart | ForgotPasswordPage | - | 未匹配 | ✅ | 检查是否需要 |
| geofence_management_page.dart | GeofenceManagementPage | 8.16 | 地理围栏管理 | ✅ | 正常 |
| goal_achievement_dashboard_page.dart | GoalAchievementDashboardPage | - | 未匹配 | ✅ | 检查是否需要 |
| handwriting_recognition_page.dart | HandwritingRecognitionPage | - | 未匹配 | ✅ | 检查是否需要 |
| help_page.dart | HelpPage | - | 未匹配 | ✅ | 检查是否需要 |
| home_layout_page.dart | HomeLayoutPage | - | 未匹配 | ✅ | 检查是否需要 |
| home_page.dart | HomePage | 1.01 | 仪表盘 Dashboard | ✅ | 正常 |
| image_recognition_page.dart | ImageRecognitionPage | 6.05 | 图片OCR识别 | ✅ | 正常 |
| import/import_history_page.dart | ImportHistoryPage | 5.08 | 导入历史 | ✅ | 正常 |
| import/import_main_page.dart | ImportMainPage | - | 未匹配 | ✅ | 检查是否需要 |
| import_page.dart | ImportPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/import_preview_confirm_page.dart | ImportPreviewConfirmPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/import_preview_page.dart | ImportPreviewPage | 5.12 | 导入预览确认 | ✅ | 正常 |
| import/import_progress_page.dart | ImportProgressPage | 5.13 | 导入进度 | ✅ | 正常 |
| import/import_success_page.dart | ImportSuccessPage | 5.15 | 导入成功 | ✅ | 正常 |
| reports/insight_analysis_page.dart | InsightAnalysisPage | 7.02 | 洞察分析 | ✅ | 正常 |
| investment_page.dart | InvestmentPage | - | 未匹配 | ✅ | 检查是否需要 |
| growth/invite_friend_page.dart | InviteFriendPage | 16.04 | 邀请好友 | ✅ | 正常 |
| join_invite_page.dart | JoinInvitePage | - | 未匹配 | ✅ | 检查是否需要 |
| language_settings_page.dart | LanguageSettingsPage | 8.03 | 语言设置 | ✅ | 正常 |
| latte_factor_page.dart | LatteFactorPage | - | 未匹配 | ✅ | 检查是否需要 |
| learning_budget_suggestion_page.dart | LearningBudgetSuggestionPage | - | 未匹配 | ✅ | 检查是否需要 |
| ledger_management_page.dart | LedgerManagementPage | - | 未匹配 | ✅ | 检查是否需要 |
| ledger_settings_page.dart | LedgerSettingsPage | 15.08 | 账本设置 | ✅ | 正常 |
| localized_budget_page.dart | LocalizedBudgetPage | - | 未匹配 | ✅ | 检查是否需要 |
| location_analysis_page.dart | LocationAnalysisPage | - | 未匹配 | ✅ | 检查是否需要 |
| location_service_settings_page.dart | LocationServiceSettingsPage | 8.14 | 位置服务设置 | ✅ | 正常 |
| login_page.dart | LoginPage | - | 未匹配 | ✅ | 检查是否需要 |
| member_budget_page.dart | MemberBudgetPage | - | 未匹配 | ✅ | 检查是否需要 |
| member_comparison_page.dart | MemberComparisonPage | - | 未匹配 | ✅ | 检查是否需要 |
| member_management_page.dart | MemberManagementPage | 15.03 | 成员管理 | ✅ | 正常 |
| member_permission_page.dart | MemberPermissionPage | - | 未匹配 | ✅ | 检查是否需要 |
| membership_page.dart | MembershipPage | - | 未匹配 | ✅ | 检查是否需要 |
| mode_upgrade_page.dart | ModeUpgradePage | - | 未匹配 | ✅ | 检查是否需要 |
| money_age_budget_page.dart | MoneyAgeBudgetPage | - | 未匹配 | ✅ | 检查是否需要 |
| money_age_influence_page.dart | MoneyAgeInfluencePage | 2.04 | 影响因素分析 | ✅ | 正常 |
| money_age_location_page.dart | MoneyAgeLocationPage | - | 未匹配 | ✅ | 检查是否需要 |
| money_age_page.dart | MoneyAgePage | - | 未匹配 | ✅ | 检查是否需要 |
| money_age_progress_page.dart | MoneyAgeProgressPage | - | 未匹配 | ✅ | 检查是否需要 |
| money_age_resource_pool_page.dart | MoneyAgeResourcePoolPage | - | 未匹配 | ✅ | 检查是否需要 |
| money_age_transaction_page.dart | MoneyAgeTransactionPage | - | 未匹配 | ✅ | 检查是否需要 |
| reports/monthly_report_page.dart | MonthlyReportPage | 7.01 | 月度报告 | ✅ | 正常 |
| multi_currency_report_page.dart | MultiCurrencyReportPage | - | 未匹配 | ✅ | 检查是否需要 |
| multi_transaction_confirm_page.dart | MultiTransactionConfirmPage | - | 未匹配 | ✅ | 检查是否需要 |
| multimodal_input_page.dart | MultimodalInputPage | - | 未匹配 | ✅ | 检查是否需要 |
| multimodal_wakeup_settings_page.dart | MultimodalWakeupSettingsPage | - | 未匹配 | ❌ | **可能需要删除** |
| ai/natural_language_search_page.dart | NaturalLanguageSearchPage | 14.06 | 自然语言搜索 | ✅ | 正常 |
| growth/negative_experience_recovery_page.dart | NegativeExperienceRecoveryPage | - | 未匹配 | ✅ | 检查是否需要 |
| exception/network_error_page.dart | NetworkErrorPage | 11.01 | 网络错误页面 | ✅ | 正常 |
| notification_settings_page.dart | NotificationSettingsPage | 8.07 | 通知设置 | ✅ | 正常 |
| growth/nps_survey_page.dart | NpsSurveyPage | - | 未匹配 | ✅ | 检查是否需要 |
| exception/offline_queue_page.dart | OfflineQueuePage | - | 未匹配 | ✅ | 检查是否需要 |
| onboarding_complete_page.dart | OnboardingCompletePage | - | 未匹配 | ✅ | 检查是否需要 |
| onboarding_features_page.dart | OnboardingFeaturesPage | - | 未匹配 | ✅ | 检查是否需要 |
| onboarding_first_transaction_page.dart | OnboardingFirstTransactionPage | - | 未匹配 | ✅ | 检查是否需要 |
| onboarding_flow_page.dart | OnboardingFlowPage | - | 未匹配 | ✅ | 检查是否需要 |
| onboarding_welcome_page.dart | OnboardingWelcomePage | - | 未匹配 | ✅ | 检查是否需要 |
| pdf_preview_page.dart | PdfPreviewPage | - | 未匹配 | ✅ | 检查是否需要 |
| peer_comparison_page.dart | PeerComparisonPage | - | 未匹配 | ✅ | 检查是否需要 |
| observability/performance_monitor_page.dart | PerformanceMonitorPage | - | 未匹配 | ✅ | 检查是否需要 |
| period_comparison_page.dart | PeriodComparisonPage | - | 未匹配 | ✅ | 检查是否需要 |
| bill_reminders/periodic_income_page.dart | PeriodicIncomePage | - | 未匹配 | ✅ | 检查是否需要 |
| pin_settings_page.dart | PinSettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| privacy_mode_page.dart | PrivacyModePage | - | 未匹配 | ✅ | 检查是否需要 |
| profile_page.dart | ProfilePage | 1.05 | 个人中心 Profile | ✅ | 正常 |
| quick_entry_page.dart | QuickEntryPage | - | 未匹配 | ✅ | 检查是否需要 |
| receipt_detail_page.dart | ReceiptDetailPage | - | 未匹配 | ✅ | 检查是否需要 |
| recording_time_stats_page.dart | RecordingTimeStatsPage | - | 未匹配 | ✅ | 检查是否需要 |
| recurring_management_page.dart | RecurringManagementPage | - | 未匹配 | ✅ | 检查是否需要 |
| region_settings_page.dart | RegionSettingsPage | 8.05 | 区域设置 | ✅ | 正常 |
| register_page.dart | RegisterPage | - | 未匹配 | ✅ | 检查是否需要 |
| reimbursement_page.dart | ReimbursementPage | - | 未匹配 | ✅ | 检查是否需要 |
| resident_location_page.dart | ResidentLocationPage | - | 未匹配 | ✅ | 检查是否需要 |
| settings/responsive_layout_preview_page.dart | ResponsiveLayoutPreviewPage | - | 未匹配 | ✅ | 检查是否需要 |
| savings_goal_page.dart | SavingsGoalPage | - | 未匹配 | ✅ | 检查是否需要 |
| search_result_page.dart | SearchResultPage | 9.02 | 搜索结果 | ✅ | 正常 |
| security_audit_log_page.dart | SecurityAuditLogPage | 8.24 | 安全审计日志 | ✅ | 正常 |
| security_settings_page.dart | SecuritySettingsPage | 8.13 | 安全设置 | ✅ | 正常 |
| settings_page.dart | SettingsPage | 8.01 | 系统设置 | ✅ | 正常 |
| smart_allocation_page.dart | SmartAllocationPage | - | 未匹配 | ✅ | 检查是否需要 |
| bill_reminders/smart_bill_suggestion_page.dart | SmartBillSuggestionPage | 13.05 | 智能账单建议 | ✅ | 正常 |
| ai/smart_classification_page.dart | SmartClassificationPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/smart_directory_discovery_page.dart | SmartDirectoryDiscoveryPage | - | 未匹配 | ✅ | 检查是否需要 |
| smart_feature_recommendation_page.dart | SmartFeatureRecommendationPage | - | 未匹配 | ✅ | 检查是否需要 |
| import/smart_format_detection_page.dart | SmartFormatDetectionPage | 5.09 | 智能格式检测 | ✅ | 正常 |
| import/smart_import_page.dart | SmartImportPage | - | 未匹配 | ✅ | 检查是否需要 |
| bill_reminders/smart_periodic_detection_page.dart | SmartPeriodicDetectionPage | - | 未匹配 | ✅ | 检查是否需要 |
| smart_text_input_page.dart | SmartTextInputPage | - | 未匹配 | ✅ | 检查是否需要 |
| source_data_settings_page.dart | SourceDataSettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| ai/spending_prediction_page.dart | SpendingPredictionPage | - | 未匹配 | ✅ | 检查是否需要 |
| split_transaction_page.dart | SplitTransactionPage | - | 未匹配 | ✅ | 检查是否需要 |
| statistics_page.dart | StatisticsPage | - | 未匹配 | ✅ | 检查是否需要 |
| streak_page.dart | StreakPage | - | 未匹配 | ✅ | 检查是否需要 |
| subscription_waste_page.dart | SubscriptionWastePage | - | 未匹配 | ✅ | 检查是否需要 |
| exception/sync_conflict_page.dart | SyncConflictPage | - | 未匹配 | ✅ | 检查是否需要 |
| sync_settings_page.dart | SyncSettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| observability/system_log_page.dart | SystemLogPage | 12.03 | 系统日志 | ✅ | 正常 |
| system_settings_page.dart | SystemSettingsPage | - | 未匹配 | ✅ | 检查是否需要 |
| tag_filter_page.dart | TagFilterPage | 9.05 | 标签筛选 | ✅ | 正常 |
| tag_statistics_page.dart | TagStatisticsPage | - | 未匹配 | ✅ | 检查是否需要 |
| template_management_page.dart | TemplateManagementPage | - | 未匹配 | ✅ | 检查是否需要 |
| today_allowance_page.dart | TodayAllowancePage | - | 未匹配 | ✅ | 检查是否需要 |
| import/transaction_comparison_page.dart | TransactionComparisonPage | 5.03 | 交易对比 | ✅ | 正常 |
| transaction_detail_page.dart | TransactionDetailPage | 4.03 | 交易详情 | ✅ | 正常 |
| transaction_list_page.dart | TransactionListPage | 4.02 | 交易列表 | ✅ | 正常 |
| reports/trend_drill_page.dart | TrendDrillPage | - | 未匹配 | ✅ | 检查是否需要 |
| trends_page.dart | TrendsPage | 1.02 | 趋势分析 Trends | ✅ | 正常 |
| unexpected_expense_page.dart | UnexpectedExpensePage | - | 未匹配 | ✅ | 检查是否需要 |
| upgrade_vote_page.dart | UpgradeVotePage | - | 未匹配 | ✅ | 检查是否需要 |
| user_profile_visualization_page.dart | UserProfileVisualizationPage | - | 未匹配 | ✅ | 检查是否需要 |
| vault_ai_suggestion_page.dart | VaultAiSuggestionPage | 3.05 | 智能分配建议 | ⚠️ | 需添加入口 |
| vault_allocation_page.dart | VaultAllocationPage | 3.03 | 资金分配 | ✅ | 正常 |
| vault_budget_age_page.dart | VaultBudgetAgePage | - | 未匹配 | ✅ | 检查是否需要 |
| vault_carryover_page.dart | VaultCarryoverPage | - | 未匹配 | ✅ | 检查是否需要 |
| vault_create_page.dart | VaultCreatePage | 3.04 | 创建小金库 | ✅ | 正常 |
| vault_detail_page.dart | VaultDetailPage | 3.02 | 小金库详情 | ✅ | 正常 |
| vault_health_page.dart | VaultHealthPage | 3.06 | 状态警告 | ✅ | 正常 |
| vault_localized_page.dart | VaultLocalizedPage | - | 未匹配 | ✅ | 检查是否需要 |
| vault_overview_page.dart | VaultOverviewPage | 3.01 | 小金库概览 | ✅ | 正常 |
| vault_smart_allocation_page.dart | VaultSmartAllocationPage | - | 未匹配 | ✅ | 检查是否需要 |
| vault_spending_intercept_page.dart | VaultSpendingInterceptPage | - | 未匹配 | ✅ | 检查是否需要 |
| vault_zero_based_page.dart | VaultZeroBasedPage | 3.09 | 零基预算分配 | ✅ | 正常 |
| vault_pages.dart | VaultsPage | - | 未匹配 | ✅ | 检查是否需要 |
| growth/viral_campaign_page.dart | ViralCampaignPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_assistant_page.dart | VoiceAssistantPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_budget_page.dart | VoiceBudgetPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_chat_page.dart | VoiceChatPage | - | 未匹配 | ✅ | 检查是否需要 |
| ai/voice_config_page.dart | VoiceConfigPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_edit_record_page.dart | VoiceEditRecordPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_history_page.dart | VoiceHistoryPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_invite_page.dart | VoiceInvitePage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_money_age_page.dart | VoiceMoneyAgePage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_recognition_page.dart | VoiceRecognitionPage | - | 未匹配 | ✅ | 检查是否需要 |
| voice_undo_page.dart | VoiceUndoPage | - | 未匹配 | ✅ | 检查是否需要 |
| wants_needs_insight_page.dart | WantsNeedsInsightPage | - | 未匹配 | ✅ | 检查是否需要 |
| welcome_back_page.dart | WelcomeBackPage | - | 未匹配 | ✅ | 检查是否需要 |
| wishlist_page.dart | WishlistPage | - | 未匹配 | ✅ | 检查是否需要 |
| zero_based_budget_page.dart | ZeroBasedBudgetPage | - | 未匹配 | ✅ | 检查是否需要 |
