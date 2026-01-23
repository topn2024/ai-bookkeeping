# 发明专利申请

**发明名称**:多成员协作的家庭账本管理系统及方法

**技术领域**:分布式系统与协作管理技术领域

**申请人**:李北华

**发明人**:李北华

**申请日**:2026-1-18

---

## 说明书

### 发明名称

多成员协作的家庭账本管理系统及方法

### 技术领域

[0001] 本发明涉及分布式系统与协作管理技术领域,具体涉及一种多成员协作的家庭账本管理系统及方法,可应用于家庭财务管理、团队记账、共享账本等场景。

### 背景技术

[0002] 根据统计数据,中国有4.9亿个家庭,其中超过60%的家庭有共同财务管理需求。然而,现有记账应用主要面向个人用户,缺乏多成员协作功能,导致家庭财务管理效率低下。

[0003] **现有技术一(共享账号)**:部分家庭通过共享一个账号实现协作。技术缺陷:(1)无权限控制,所有成员权限相同;(2)无法区分操作者;(3)数据冲突无法解决;(4)隐私无法保护;(5)成员退出后数据处理困难。

[0004] **现有技术二(手动同步)**:部分家庭通过手动导出导入数据同步。技术缺陷:(1)操作繁琐,效率低;(2)容易遗漏数据;(3)版本冲突无法自动解决;(4)实时性差;(5)无协作机制。

[0005] **现有技术三(云同步)**:部分应用提供云同步功能。技术缺陷:(1)仅同步数据,无协作机制;(2)无权限控制;(3)冲突解决简单(后写覆盖);(4)无操作日志;(5)无回滚机制。

[0006] **现有技术四(协作软件)**:通用协作软件(如石墨文档)提供多人协作。技术缺陷:(1)非财务专用,功能不匹配;(2)无财务数据特殊处理;(3)无智能分摊算法;(4)无家庭场景优化;(5)学习成本高。

[0007] 综上所述,现有技术存在以下共性技术问题:(1)缺乏细粒度权限控制;(2)无协作冲突检测与解决;(3)无家庭财务数据隔离;(4)无智能分摊算法;(5)成员管理机制不完善。

### 发明内容

#### 发明目的

[0008] 本发明的目的在于提供一种多成员协作的家庭账本管理系统及方法,解决现有技术中缺乏权限控制、无冲突解决、无数据隔离、无智能分摊等技术问题。

#### 技术方案

[0009] 本发明提出一种**权限控制 + 冲突解决 + 数据隔离 + 智能分摊 + 成员管理**的五维家庭协作系统,包括:

##### 核心技术方案一:细粒度权限控制

[0010] **权限数据结构**:
```
FamilyBook {
  book_id: UUID,
  book_name: String,
  owner_id: String,           // 创建者
  members: List<Member>,      // 成员列表
  created_at: DateTime,
  settings: BookSettings
}

Member {
  user_id: String,
  role: Enum,                 // 角色:所有者/管理员/成员/只读
  permissions: Permissions,   // 权限配置
  joined_at: DateTime,
  invited_by: String
}

Permissions {
  can_view: Boolean,          // 查看权限
  can_add: Boolean,           // 添加权限
  can_edit: Boolean,          // 编辑权限
  can_delete: Boolean,        // 删除权限
  can_export: Boolean,        // 导出权限
  can_invite: Boolean,        // 邀请权限
  can_manage_members: Boolean,// 成员管理权限
  view_scope: Enum,           // 查看范围:全部/自己/指定成员
  edit_scope: Enum            // 编辑范围:全部/自己
}
```

[0011] **基于角色的访问控制算法**:
```
算法1:权限检查与控制
输入:用户 User, 操作 Operation, 目标数据 Target
输出:是否允许 Boolean

预定义角色权限:
1. 所有者(Owner):
   - 全部权限
   - 可以删除账本
   - 可以转让所有权

2. 管理员(Admin):
   - 查看、添加、编辑、删除(全部数据)
   - 可以邀请成员
   - 可以管理成员(除所有者外)
   - 不能删除账本

3. 成员(Member):
   - 查看(全部数据)
   - 添加(自己的记录)
   - 编辑、删除(仅自己的记录)
   - 不能邀请成员

4. 只读(Viewer):
   - 仅查看权限
   - 不能添加、编辑、删除
   - 不能邀请成员

权限检查流程:
function check_permission(user, operation, target):
  // 1. 获取用户角色
  member = get_member(user.id, target.book_id)
  if member is None:
    return False  // 非成员

  // 2. 检查操作权限
  if operation == "view":
    if not member.permissions.can_view:
      return False
    // 检查查看范围
    if member.permissions.view_scope == "self":
      return target.created_by == user.id
    elif member.permissions.view_scope == "specified":
      return target.created_by in member.allowed_users

  elif operation == "edit":
    if not member.permissions.can_edit:
      return False
    // 检查编辑范围
    if member.permissions.edit_scope == "self":
      return target.created_by == user.id

  elif operation == "delete":
    if not member.permissions.can_delete:
      return False
    // 删除权限通常限制为自己的记录
    return target.created_by == user.id

  return True

动态权限调整:
// 所有者可以自定义成员权限
function customize_permissions(owner, member, new_permissions):
  if owner.role != "Owner":
    raise PermissionError("仅所有者可以调整权限")

  member.permissions = new_permissions
  log_permission_change(owner, member, new_permissions)
```

##### 核心技术方案二:协作冲突检测与解决

[0012] **冲突检测算法**:
```
算法2:多人协作冲突检测
输入:操作 Operation, 本地版本 LocalVersion, 服务器版本 ServerVersion
输出:冲突类型 ConflictType, 解决策略 Resolution

冲突类型:
1. 编辑冲突:
   - 两个用户同时编辑同一条记录
   - 检测:version_conflict(local, server)

2. 删除冲突:
   - 用户A编辑,用户B删除
   - 检测:record_not_found(server)

3. 金额冲突:
   - 两个用户对同一记录设置不同金额
   - 检测:amount_mismatch(local, server)

4. 分类冲突:
   - 两个用户对同一记录设置不同分类
   - 检测:category_mismatch(local, server)

冲突检测流程:
function detect_conflict(operation, local, server):
  // 1. 版本号检查
  if local.version != server.version:
    conflict_type = "version_conflict"

    // 2. 具体冲突分析
    if server.deleted:
      return ("delete_conflict", "server_deleted")

    if local.amount != server.amount:
      return ("amount_conflict", "manual_resolve")

    if local.category != server.category:
      return ("category_conflict", "manual_resolve")

    if local.description != server.description:
      return ("description_conflict", "auto_merge")

  return (None, None)

冲突解决策略:
1. 自动合并(Auto Merge):
   - 适用于:备注、标签等非关键字段
   - 策略:合并两个版本的内容
   - 示例:备注A="超市购物",备注B="买菜" → "超市购物;买菜"

2. 最后写入优先(Last Write Wins):
   - 适用于:时间戳明确的情况
   - 策略:保留最新的修改
   - 记录冲突日志

3. 手动解决(Manual Resolve):
   - 适用于:金额、分类等关键字段
   - 策略:提示用户选择保留哪个版本
   - 提供对比界面

4. 版本保留(Keep Both):
   - 适用于:无法自动判断的情况
   - 策略:保留两个版本,标记为冲突
   - 用户后续手动处理

冲突解决实现:
function resolve_conflict(conflict_type, local, server):
  if conflict_type == "description_conflict":
    // 自动合并备注
    merged = merge_descriptions(local.description, server.description)
    return create_merged_version(local, server, merged)

  elif conflict_type == "amount_conflict":
    // 手动解决
    return prompt_user_choice(local, server)

  elif conflict_type == "delete_conflict":
    // 服务器已删除,询问用户
    return prompt_restore_or_discard(local)

  elif conflict_type == "version_conflict":
    // 最后写入优先
    if local.updated_at > server.updated_at:
      return local
    else:
      return server
```

##### 核心技术方案三:家庭财务数据隔离

[0013] **数据隔离算法**:
```
算法3:个人与家庭数据隔离
输入:用户 User
输出:可见数据集 VisibleData

数据分类:
1. 个人账本:
   - 仅用户自己可见
   - 不与家庭成员共享
   - 独立的预算和统计

2. 家庭账本:
   - 家庭成员可见(根据权限)
   - 共享预算和统计
   - 支持协作记账

3. 共享记录:
   - 特定记录可以从个人账本共享到家庭账本
   - 共享后保留原始记录的副本
   - 共享记录的修改需要权限

数据隔离实现:
function get_visible_data(user):
  visible_data = []

  // 1. 个人账本数据
  personal_books = get_personal_books(user.id)
  visible_data.extend(personal_books)

  // 2. 家庭账本数据
  family_books = get_family_books(user.id)
  for book in family_books:
    member = get_member(user.id, book.id)

    // 根据权限过滤数据
    if member.permissions.view_scope == "all":
      visible_data.extend(book.records)
    elif member.permissions.view_scope == "self":
      visible_data.extend(filter(book.records, created_by=user.id))
    elif member.permissions.view_scope == "specified":
      visible_data.extend(filter(book.records,
                          created_by in member.allowed_users))

  return visible_data

数据共享机制:
function share_to_family(user, record, family_book):
  // 1. 权限检查
  if not check_permission(user, "add", family_book):
    raise PermissionError("无权限添加到家庭账本")

  // 2. 创建共享副本
  shared_record = copy(record)
  shared_record.book_id = family_book.id
  shared_record.shared_from = record.id
  shared_record.shared_by = user.id
  shared_record.shared_at = now()

  // 3. 保留原始记录
  record.shared_to = shared_record.id

  // 4. 保存
  save(shared_record)
  save(record)

  return shared_record

成员退出处理:
function handle_member_exit(user, family_book):
  // 1. 数据处理选项
  options = [
    "保留数据(归属家庭账本)",
    "删除自己的数据",
    "转移数据到个人账本"
  ]

  choice = prompt_user(options)

  if choice == "保留数据":
    // 数据保留在家庭账本,标记创建者为"已退出成员"
    mark_records_as_orphaned(user.id, family_book.id)

  elif choice == "删除自己的数据":
    // 删除用户创建的所有记录
    delete_records(user.id, family_book.id)

  elif choice == "转移数据":
    // 将数据转移到个人账本
    transfer_to_personal(user.id, family_book.id)

  // 2. 移除成员
  remove_member(user.id, family_book.id)
```

##### 核心技术方案四:智能分摊算法

[0014] **智能分摊算法**:
```
算法4:多人消费智能分摊
输入:消费记录 Expense, 参与成员 Participants, 分摊规则 Rule
输出:分摊结果 SplitResult

分摊规则:
1. 平均分摊(AA制):
   - 每人金额 = 总金额 / 人数
   - 适用于:聚餐、团购等

2. 按比例分摊:
   - 每人金额 = 总金额 × 比例
   - 适用于:按收入比例分摊房租等

3. 按份额分摊:
   - 每人金额 = 单价 × 份数
   - 适用于:点餐(每人点不同菜品)

4. 自定义分摊:
   - 手动指定每人金额
   - 适用于:复杂场景

分摊计算:
function calculate_split(expense, participants, rule):
  if rule.type == "equal":
    // 平均分摊
    per_person = expense.amount / len(participants)
    return {p: per_person for p in participants}

  elif rule.type == "ratio":
    // 按比例分摊
    total_ratio = sum(rule.ratios.values())
    return {p: expense.amount × rule.ratios[p] / total_ratio
            for p in participants}

  elif rule.type == "share":
    // 按份额分摊
    return {p: rule.unit_price × rule.shares[p]
            for p in participants}

  elif rule.type == "custom":
    // 自定义分摊
    return rule.custom_amounts

债务关系计算:
function calculate_debts(splits):
  // 1. 计算每人的净支付
  net_payments = {}
  for split in splits:
    payer = split.payer
    for participant, amount in split.amounts.items():
      if participant not in net_payments:
        net_payments[participant] = 0

      if participant == payer:
        net_payments[participant] += split.total - amount
      else:
        net_payments[participant] -= amount

  // 2. 分离债权人和债务人
  creditors = {p: amt for p, amt in net_payments.items() if amt > 0}
  debtors = {p: -amt for p, amt in net_payments.items() if amt < 0}

  // 3. 最小化转账次数
  debts = []
  while creditors and debtors:
    creditor = max(creditors, key=creditors.get)
    debtor = max(debtors, key=debtors.get)

    amount = min(creditors[creditor], debtors[debtor])
    debts.append({
      "from": debtor,
      "to": creditor,
      "amount": amount
    })

    creditors[creditor] -= amount
    debtors[debtor] -= amount

    if creditors[creditor] == 0:
      del creditors[creditor]
    if debtors[debtor] == 0:
      del debtors[debtor]

  return debts

清算建议:
function suggest_settlement(debts):
  // 按金额排序,优先清算大额债务
  sorted_debts = sort(debts, key=lambda d: d.amount, reverse=True)

  suggestions = []
  for debt in sorted_debts:
    suggestions.append({
      "message": f"{debt.from}应向{debt.to}支付{debt.amount}元",
      "priority": "高" if debt.amount > 100 else "中" if debt.amount > 50 else "低",
      "payment_methods": ["微信", "支付宝", "银行转账"]
    })

  return suggestions
```
