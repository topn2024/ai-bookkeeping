<template>
  <div class="alerts-management">
    <div class="page-header">
      <h2 class="page-title">告警管理</h2>
      <el-button type="primary" @click="handleAddRule">
        <el-icon><Plus /></el-icon>添加规则
      </el-button>
    </div>

    <!-- Alert Summary -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="活动告警" :value="summary.active_count" value-style="color: #ff4d4f" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="今日告警" :value="summary.today_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="告警规则" :value="summary.rule_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="已处理率" :value="summary.resolved_rate" suffix="%" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Active Alerts -->
    <el-card class="mb-20">
      <template #header>
        <div class="card-header">
          <span>活动告警</span>
          <el-button type="success" text @click="acknowledgeAll" :disabled="activeAlerts.length === 0">
            全部确认
          </el-button>
        </div>
      </template>
      <el-table :data="activeAlerts" size="small" stripe>
        <el-table-column prop="severity" label="级别" width="100">
          <template #default="{ row }">
            <el-tag :type="getSeverityTag(row.severity)" size="small">
              {{ getSeverityText(row.severity) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="200" />
        <el-table-column prop="source" label="来源" width="120" />
        <el-table-column prop="triggered_at" label="触发时间" width="160">
          <template #default="{ row }">
            {{ formatDateTime(row.triggered_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="count" label="触发次数" width="100" />
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleViewAlert(row)">详情</el-button>
            <el-button type="success" text size="small" @click="handleAcknowledge(row)">确认</el-button>
            <el-button type="warning" text size="small" @click="handleResolve(row)">解决</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="activeAlerts.length === 0" class="empty-state">
        <el-icon><CircleCheck /></el-icon>
        <p>当前没有活动告警</p>
      </div>
    </el-card>

    <!-- Alert Rules -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>告警规则</span>
          <el-input
            v-model="ruleSearch"
            placeholder="搜索规则"
            style="width: 200px;"
            clearable
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
        </div>
      </template>
      <el-table :data="filteredRules" size="small" stripe>
        <el-table-column prop="name" label="规则名称" min-width="150" />
        <el-table-column prop="metric" label="监控指标" width="150" />
        <el-table-column prop="condition" label="触发条件" width="150">
          <template #default="{ row }">
            {{ row.operator }} {{ row.threshold }}{{ row.unit }}
          </template>
        </el-table-column>
        <el-table-column prop="severity" label="级别" width="100">
          <template #default="{ row }">
            <el-tag :type="getSeverityTag(row.severity)" size="small">
              {{ getSeverityText(row.severity) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="enabled" label="状态" width="100">
          <template #default="{ row }">
            <el-switch v-model="row.enabled" @change="handleToggleRule(row)" />
          </template>
        </el-table-column>
        <el-table-column prop="notification" label="通知方式" width="150">
          <template #default="{ row }">
            <el-tag v-for="n in row.notifications" :key="n" size="small" class="mr-5">{{ n }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleEditRule(row)">编辑</el-button>
            <el-button type="danger" text size="small" @click="handleDeleteRule(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- Alert Detail Dialog -->
    <el-dialog v-model="alertDetailVisible" title="告警详情" width="600px">
      <el-descriptions v-if="currentAlert" :column="2" border>
        <el-descriptions-item label="级别">
          <el-tag :type="getSeverityTag(currentAlert.severity)">
            {{ getSeverityText(currentAlert.severity) }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="状态">
          <el-tag :type="getAlertStatusTag(currentAlert.status)">
            {{ getAlertStatusText(currentAlert.status) }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="标题" :span="2">{{ currentAlert.title }}</el-descriptions-item>
        <el-descriptions-item label="来源">{{ currentAlert.source }}</el-descriptions-item>
        <el-descriptions-item label="触发次数">{{ currentAlert.count }}</el-descriptions-item>
        <el-descriptions-item label="触发时间">{{ formatDateTime(currentAlert.triggered_at) }}</el-descriptions-item>
        <el-descriptions-item label="最后更新">{{ formatDateTime(currentAlert.updated_at) }}</el-descriptions-item>
        <el-descriptions-item label="描述" :span="2">{{ currentAlert.description }}</el-descriptions-item>
      </el-descriptions>

      <div v-if="currentAlert?.details" class="mt-20">
        <h4>详细信息</h4>
        <pre class="alert-details">{{ JSON.stringify(currentAlert.details, null, 2) }}</pre>
      </div>
    </el-dialog>

    <!-- Rule Edit Dialog -->
    <el-dialog v-model="ruleDialogVisible" :title="editingRule ? '编辑规则' : '添加规则'" width="600px">
      <el-form ref="ruleFormRef" :model="ruleForm" :rules="ruleFormRules" label-width="100px">
        <el-form-item label="规则名称" prop="name">
          <el-input v-model="ruleForm.name" placeholder="输入规则名称" />
        </el-form-item>
        <el-form-item label="监控指标" prop="metric">
          <el-select v-model="ruleForm.metric" placeholder="选择监控指标">
            <el-option label="CPU使用率" value="cpu_usage" />
            <el-option label="内存使用率" value="memory_usage" />
            <el-option label="磁盘使用率" value="disk_usage" />
            <el-option label="API响应时间" value="api_response_time" />
            <el-option label="错误率" value="error_rate" />
            <el-option label="活动连接数" value="active_connections" />
          </el-select>
        </el-form-item>
        <el-form-item label="触发条件" prop="operator">
          <el-col :span="8">
            <el-select v-model="ruleForm.operator">
              <el-option label="大于" value=">" />
              <el-option label="小于" value="<" />
              <el-option label="等于" value="=" />
              <el-option label="大于等于" value=">=" />
              <el-option label="小于等于" value="<=" />
            </el-select>
          </el-col>
          <el-col :span="8">
            <el-input-number v-model="ruleForm.threshold" :min="0" style="width: 100%;" />
          </el-col>
          <el-col :span="8">
            <el-select v-model="ruleForm.unit">
              <el-option label="%" value="%" />
              <el-option label="ms" value="ms" />
              <el-option label="个" value="" />
            </el-select>
          </el-col>
        </el-form-item>
        <el-form-item label="告警级别" prop="severity">
          <el-radio-group v-model="ruleForm.severity">
            <el-radio-button label="critical">严重</el-radio-button>
            <el-radio-button label="warning">警告</el-radio-button>
            <el-radio-button label="info">信息</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="通知方式" prop="notifications">
          <el-checkbox-group v-model="ruleForm.notifications">
            <el-checkbox label="email">邮件</el-checkbox>
            <el-checkbox label="sms">短信</el-checkbox>
            <el-checkbox label="webhook">Webhook</el-checkbox>
          </el-checkbox-group>
        </el-form-item>
        <el-form-item label="静默时间" prop="silence_minutes">
          <el-input-number v-model="ruleForm.silence_minutes" :min="1" :max="1440" />
          <span class="ml-10">分钟</span>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="ruleDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitRule">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import * as monitorApi from '@/api/monitor'

// State
const activeAlerts = ref<any[]>([])
const alertRules = ref<any[]>([])
const ruleSearch = ref('')
const summary = reactive({
  active_count: 0,
  today_count: 0,
  rule_count: 0,
  resolved_rate: 0,
})

// Alert detail
const alertDetailVisible = ref(false)
const currentAlert = ref<any>(null)

// Rule dialog
const ruleDialogVisible = ref(false)
const editingRule = ref<any>(null)
const saving = ref(false)
const ruleFormRef = ref<FormInstance>()
const ruleForm = reactive({
  name: '',
  metric: '',
  operator: '>',
  threshold: 80,
  unit: '%',
  severity: 'warning',
  notifications: ['email'] as string[],
  silence_minutes: 5,
})
const ruleFormRules: FormRules = {
  name: [{ required: true, message: '请输入规则名称', trigger: 'blur' }],
  metric: [{ required: true, message: '请选择监控指标', trigger: 'change' }],
  severity: [{ required: true, message: '请选择告警级别', trigger: 'change' }],
  notifications: [{ required: true, type: 'array', min: 1, message: '请选择通知方式', trigger: 'change' }],
}

// Computed
const filteredRules = computed(() => {
  if (!ruleSearch.value) return alertRules.value
  const keyword = ruleSearch.value.toLowerCase()
  return alertRules.value.filter(r => r.name.toLowerCase().includes(keyword))
})

// Fetch data
const fetchAlerts = async () => {
  try {
    const data = await monitorApi.getActiveAlerts()
    activeAlerts.value = data.items || []
    Object.assign(summary, data.summary || {})
  } catch (e) {
    ElMessage.error('获取告警列表失败')
  }
}

const fetchRules = async () => {
  try {
    const data = await monitorApi.getAlertRules()
    alertRules.value = data.items || []
  } catch (e) {
    ElMessage.error('获取告警规则失败')
  }
}

// Handlers
const handleViewAlert = (alert: any) => {
  currentAlert.value = alert
  alertDetailVisible.value = true
}

const handleAcknowledge = async (alert: any) => {
  try {
    await monitorApi.acknowledgeAlert(alert.id)
    ElMessage.success('已确认告警')
    fetchAlerts()
  } catch (e) {
    ElMessage.error('确认失败')
  }
}

const handleResolve = async (alert: any) => {
  try {
    await monitorApi.resolveAlert(alert.id)
    ElMessage.success('已解决告警')
    fetchAlerts()
  } catch (e) {
    ElMessage.error('解决失败')
  }
}

const acknowledgeAll = async () => {
  try {
    await ElMessageBox.confirm('确定要确认所有活动告警吗？', '批量确认', { type: 'warning' })
    await monitorApi.acknowledgeAllAlerts()
    ElMessage.success('已确认所有告警')
    fetchAlerts()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('操作失败')
    }
  }
}

const handleAddRule = () => {
  editingRule.value = null
  Object.assign(ruleForm, {
    name: '',
    metric: '',
    operator: '>',
    threshold: 80,
    unit: '%',
    severity: 'warning',
    notifications: ['email'],
    silence_minutes: 5,
  })
  ruleDialogVisible.value = true
}

const handleEditRule = (rule: any) => {
  editingRule.value = rule
  Object.assign(ruleForm, {
    name: rule.name,
    metric: rule.metric,
    operator: rule.operator,
    threshold: rule.threshold,
    unit: rule.unit,
    severity: rule.severity,
    notifications: rule.notifications || ['email'],
    silence_minutes: rule.silence_minutes || 5,
  })
  ruleDialogVisible.value = true
}

const submitRule = async () => {
  if (!ruleFormRef.value) return
  await ruleFormRef.value.validate(async (valid) => {
    if (!valid) return

    saving.value = true
    try {
      if (editingRule.value) {
        await monitorApi.updateAlertRule(editingRule.value.id, ruleForm)
        ElMessage.success('更新成功')
      } else {
        await monitorApi.createAlertRule(ruleForm)
        ElMessage.success('创建成功')
      }
      ruleDialogVisible.value = false
      fetchRules()
    } catch (e) {
      ElMessage.error('保存失败')
    } finally {
      saving.value = false
    }
  })
}

const handleToggleRule = async (rule: any) => {
  try {
    await monitorApi.toggleAlertRule(rule.id, rule.enabled)
    ElMessage.success(rule.enabled ? '规则已启用' : '规则已禁用')
  } catch (e) {
    rule.enabled = !rule.enabled
    ElMessage.error('操作失败')
  }
}

const handleDeleteRule = async (rule: any) => {
  try {
    await ElMessageBox.confirm(`确定要删除规则 "${rule.name}" 吗？`, '确认删除', { type: 'warning' })
    await monitorApi.deleteAlertRule(rule.id)
    ElMessage.success('删除成功')
    fetchRules()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

// Helpers
const getSeverityTag = (severity: string) => {
  const map: Record<string, string> = {
    critical: 'danger',
    warning: 'warning',
    info: 'info',
  }
  return map[severity] || ''
}

const getSeverityText = (severity: string) => {
  const map: Record<string, string> = {
    critical: '严重',
    warning: '警告',
    info: '信息',
  }
  return map[severity] || severity
}

const getAlertStatusTag = (status: string) => {
  const map: Record<string, string> = {
    active: 'danger',
    acknowledged: 'warning',
    resolved: 'success',
  }
  return map[status] || ''
}

const getAlertStatusText = (status: string) => {
  const map: Record<string, string> = {
    active: '活动',
    acknowledged: '已确认',
    resolved: '已解决',
  }
  return map[status] || status
}

const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Init
onMounted(() => {
  fetchAlerts()
  fetchRules()
})
</script>

<style scoped lang="scss">
.alerts-management {
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .empty-state {
    text-align: center;
    padding: 40px;
    color: #999;

    .el-icon {
      font-size: 48px;
      color: #52c41a;
    }
  }

  .mr-5 {
    margin-right: 5px;
  }

  .alert-details {
    background: #f5f5f5;
    padding: 12px;
    border-radius: 4px;
    font-size: 12px;
    overflow-x: auto;
  }

  h4 {
    margin-bottom: 10px;
    color: #333;
  }
}
</style>
