# 语音操作执行

## 新增需求

### 需求：配置操作执行器

系统必须支持用户通过语音执行各种配置操作，包括分类管理、标签管理、账本管理、成员管理、信用卡管理、储蓄目标管理和定期交易管理。

#### 场景：添加分类
**前置条件**：用户已登录应用
**操作步骤**：
1. 用户说"添加一个餐饮分类"
2. 系统识别意图为 config.category
3. 系统解析参数：operation=add, categoryName=餐饮
4. 系统调用 CategoryConfigAction 执行
5. 系统创建新分类并保存到数据库

**预期结果**：
- 系统返回"已添加分类: 餐饮"
- 数据库中新增一条分类记录
- 用户可以在分类列表中看到新分类

#### 场景：设置信用卡还款日
**前置条件**：用户已添加信用卡
**操作步骤**：
1. 用户说"设置招商银行信用卡还款日为每月20号"
2. 系统识别意图为 config.creditCard
3. 系统解析参数：operation=setRepaymentDate, cardName=招商银行, repaymentDay=20
4. 系统调用 CreditCardConfigAction 执行
5. 系统更新信用卡还款日

**预期结果**：
- 系统返回"已设置招商银行信用卡还款日为20号"
- 数据库中信用卡记录已更新
- 系统会在还款日前提醒用户

#### 场景：查询账本列表
**前置条件**：用户已创建多个账本
**操作步骤**：
1. 用户说"查看我的账本列表"
2. 系统识别意图为 config.ledger
3. 系统解析参数：operation=query
4. 系统调用 LedgerConfigAction 执行
5. 系统查询所有账本

**预期结果**：
- 系统返回"您有3个账本：个人账本、家庭账本、公司账本"
- 显示每个账本的基本信息

---

### 需求：小金库操作执行器

系统必须支持用户通过语音管理小金库，包括创建、查询、转账和预算设置。

#### 场景：查询小金库余额
**前置条件**：用户已创建小金库
**操作步骤**：
1. 用户说"查询旅游基金余额"
2. 系统识别意图为 vault.query
3. 系统解析参数：vaultName=旅游基金
4. 系统调用 VaultQueryAction 执行
5. 系统查询小金库余额

**预期结果**：
- 系统返回"旅游基金余额: 5000元"
- 显示小金库的详细信息

#### 场景：小金库转账
**前置条件**：用户已创建小金库且有足够余额
**操作步骤**：
1. 用户说"从旅游基金转500元到应急基金"
2. 系统识别意图为 vault.transfer
3. 系统解析参数：fromVault=旅游基金, toVault=应急基金, amount=500
4. 系统调用 VaultTransferAction 执行
5. 系统执行转账操作

**预期结果**：
- 系统返回"已从旅游基金转账500元到应急基金"
- 两个小金库余额已更新
- 生成转账记录

---

### 需求：钱龄操作执行器

系统必须支持用户通过语音查询钱龄健康度、设置提醒和查看报告。

#### 场景：查询钱龄健康度
**前置条件**：用户有交易记录
**操作步骤**：
1. 用户说"查询我的钱龄健康度"
2. 系统识别意图为 moneyAge.query
3. 系统调用 MoneyAgeQueryAction 执行
4. 系统计算平均钱龄和健康等级

**预期结果**：
- 系统返回"平均钱龄: 25.3天，健康等级: health"
- 显示钱龄分布图表
- 提供改善建议

#### 场景：设置钱龄提醒
**前置条件**：用户已登录
**操作步骤**：
1. 用户说"当钱龄超过30天时提醒我"
2. 系统识别意图为 moneyAge.reminder
3. 系统解析参数：threshold=30
4. 系统调用 MoneyAgeReminderAction 执行
5. 系统设置提醒规则

**预期结果**：
- 系统返回"已设置钱龄提醒，超过30天时会通知您"
- 当钱龄超过阈值时发送通知

---

### 需求：数据操作执行器

系统必须支持用户通过语音导出数据、备份数据和查看统计。

#### 场景：导出CSV数据
**前置条件**：用户有交易记录
**操作步骤**：
1. 用户说"导出本月的交易记录为CSV"
2. 系统识别意图为 data.export
3. 系统解析参数：format=csv, timeRange=thisMonth
4. 系统调用 DataExportAction 执行
5. 系统生成CSV文件

**预期结果**：
- 系统返回"已导出本月交易记录，共50条"
- 生成CSV文件并保存到指定位置
- 提供文件下载链接

#### 场景：备份数据
**前置条件**：用户已登录
**操作步骤**：
1. 用户说"备份我的数据"
2. 系统识别意图为 data.backup
3. 系统调用 DataBackupAction 执行
4. 系统创建数据备份

**预期结果**：
- 系统返回"数据备份成功，备份文件: backup_20260118.db"
- 备份文件保存到本地或云端
- 记录备份历史

---

### 需求：自动化操作执行器

系统必须支持用户通过语音触发屏幕识别记账和账单同步。

#### 场景：屏幕识别记账
**前置条件**：用户在支付成功页面
**操作步骤**：
1. 用户说"识别屏幕上的账单"
2. 系统识别意图为 automation.screenRecognition
3. 系统调用 ScreenRecognitionAction 执行
4. 系统截取屏幕并进行OCR识别
5. 系统解析账单信息并创建交易记录

**预期结果**：
- 系统返回"已识别并记录: 星巴克 35元"
- 自动创建交易记录
- 标记来源为图片识别

#### 场景：同步支付宝账单
**前置条件**：用户已授权支付宝账单访问
**操作步骤**：
1. 用户说"同步支付宝账单"
2. 系统识别意图为 automation.alipaySync
3. 系统调用 AlipayBillSyncAction 执行
4. 系统获取支付宝账单数据
5. 系统批量导入交易记录

**预期结果**：
- 系统返回"已同步支付宝账单，新增20条记录"
- 自动去重，避免重复导入
- 标记来源为支付宝导入

## 修改需求

### 需求：完善 BookkeepingOperationAdapter

系统必须修复 BookkeepingOperationAdapter 中的 TODO 占位符，实现实际的数据库操作。

#### 场景：添加交易记录
**前置条件**：用户已登录
**操作步骤**：
1. 用户说"记一笔50元的午餐"
2. 系统识别意图为 transaction.expense
3. 系统解析参数：amount=50, category=餐饮
4. 系统调用 BookkeepingOperationAdapter._addTransaction
5. 系统创建 Transaction 对象并调用 DatabaseService.insertTransaction

**预期结果**：
- 系统返回"已记录: 餐饮 50元"
- 数据库中新增一条交易记录
- 交易来源标记为 voice

#### 场景：查询交易记录
**前置条件**：用户有交易记录
**操作步骤**：
1. 用户说"查询我本月的支出"
2. 系统识别意图为 transaction.query
3. 系统解析参数：queryType=summary, timeRange=thisMonth
4. 系统调用 BookkeepingOperationAdapter._query
5. 系统调用 DatabaseService.getTransactions 并计算统计数据

**预期结果**：
- 系统返回"本月支出: 3500元，收入: 8000元，余额: 4500元"
- 显示详细的统计信息

#### 场景：删除交易记录
**前置条件**：用户有交易记录
**操作步骤**：
1. 用户说"删除最后一笔交易"
2. 系统识别意图为 transaction.delete
3. 系统通过消歧服务确定目标交易
4. 系统调用 BookkeepingOperationAdapter._delete
5. 系统调用 DatabaseService.deleteTransaction

**预期结果**：
- 系统返回"已删除交易: 餐饮 50元"
- 数据库中交易记录已删除

#### 场景：修改交易记录
**前置条件**：用户有交易记录
**操作步骤**：
1. 用户说"把最后一笔交易改成60元"
2. 系统识别意图为 transaction.modify
3. 系统通过消歧服务确定目标交易
4. 系统解析参数：amount=60
5. 系统调用 BookkeepingOperationAdapter._modify
6. 系统调用 DatabaseService.updateTransaction

**预期结果**：
- 系统返回"已修改交易金额为60元"
- 数据库中交易记录已更新

---

### 需求：完善导航操作

系统必须实现 BookkeepingOperationAdapter 中的导航操作，实际调用 VoiceNavigationService。

#### 场景：导航到预算页面
**前置条件**：用户已登录
**操作步骤**：
1. 用户说"打开预算页面"
2. 系统识别意图为 navigation.page
3. 系统解析参数：targetPage=budget
4. 系统调用 BookkeepingOperationAdapter._navigate
5. 系统调用 VoiceNavigationService.navigateTo

**预期结果**：
- 系统返回"正在打开预算页面"
- 应用导航到预算页面
- 页面正确显示

#### 场景：导航到统计页面
**前置条件**：用户已登录
**操作步骤**：
1. 用户说"查看统计报表"
2. 系统识别意图为 navigation.page
3. 系统解析参数：targetPage=statistics
4. 系统调用 BookkeepingOperationAdapter._navigate
5. 系统调用 VoiceNavigationService.navigateTo

**预期结果**：
- 系统返回"正在打开统计页面"
- 应用导航到统计页面
- 显示统计图表
