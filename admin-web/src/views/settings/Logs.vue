<template>
  <div class="audit-logs">
    <div class="page-header">
      <h2 class="page-title">审计日志</h2>
      <el-button type="primary" @click="handleExport">
        <el-icon><Download /></el-icon>导出日志
      </el-button>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="管理员">
          <el-select v-model="filters.admin_id" placeholder="全部" clearable style="width: 150px;">
            <el-option v-for="admin in adminOptions" :key="admin.id" :label="admin.username" :value="admin.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="操作类型">
          <el-select v-model="filters.action" placeholder="全部" clearable style="width: 150px;">
            <el-option v-for="(label, value) in actionOptions" :key="value" :label="label" :value="value" />
          </el-select>
        </el-form-item>
        <el-form-item label="模块">
          <el-select v-model="filters.module" placeholder="全部" clearable style="width: 150px;">
            <el-option v-for="m in moduleOptions" :key="m" :label="m" :value="m" />
          </el-select>
        </el-form-item>
        <el-form-item label="时间范围">
          <el-date-picker
            v-model="filters.dateRange"
            type="datetimerange"
            range-separator="至"
            start-placeholder="开始"
            end-placeholder="结束"
            value-format="YYYY-MM-DD HH:mm:ss"
            style="width: 360px;"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">
            <el-icon><Search /></el-icon>搜索
          </el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- Stats -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="今日操作" :value="stats.today_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="本周操作" :value="stats.week_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="活跃管理员" :value="stats.active_admins" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="敏感操作" :value="stats.sensitive_count" value-style="color: #ff4d4f" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Log Table -->
    <div class="table-container">
      <el-table v-loading="loading" :data="logs" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="admin_username" label="管理员" width="120" />
        <el-table-column prop="action" label="操作" width="120">
          <template #default="{ row }">
            <el-tag :type="getActionTag(row.action)" size="small">
              {{ actionOptions[row.action] || row.action }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="module" label="模块" width="120" />
        <el-table-column prop="description" label="描述" min-width="250" show-overflow-tooltip />
        <el-table-column prop="ip_address" label="IP地址" width="140" />
        <el-table-column prop="user_agent" label="设备" width="120" show-overflow-tooltip>
          <template #default="{ row }">
            {{ parseUserAgent(row.user_agent) }}
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="时间" width="160">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="80" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleView(row)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-container">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :total="pagination.total"
          :page-sizes="[20, 50, 100, 200]"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Detail Dialog -->
    <el-dialog v-model="detailVisible" title="日志详情" width="600px">
      <el-descriptions v-if="currentLog" :column="2" border>
        <el-descriptions-item label="ID">{{ currentLog.id }}</el-descriptions-item>
        <el-descriptions-item label="管理员">{{ currentLog.admin_username }}</el-descriptions-item>
        <el-descriptions-item label="操作">
          <el-tag :type="getActionTag(currentLog.action)">
            {{ actionOptions[currentLog.action] || currentLog.action }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="模块">{{ currentLog.module }}</el-descriptions-item>
        <el-descriptions-item label="描述" :span="2">{{ currentLog.description }}</el-descriptions-item>
        <el-descriptions-item label="IP地址">{{ currentLog.ip_address }}</el-descriptions-item>
        <el-descriptions-item label="位置">{{ currentLog.location || '-' }}</el-descriptions-item>
        <el-descriptions-item label="设备" :span="2">{{ currentLog.user_agent }}</el-descriptions-item>
        <el-descriptions-item label="时间" :span="2">{{ formatDateTime(currentLog.created_at) }}</el-descriptions-item>
      </el-descriptions>

      <div v-if="currentLog?.request_data" class="mt-20">
        <h4>请求数据</h4>
        <pre class="log-data">{{ JSON.stringify(currentLog.request_data, null, 2) }}</pre>
      </div>

      <div v-if="currentLog?.response_data" class="mt-20">
        <h4>响应数据</h4>
        <pre class="log-data">{{ JSON.stringify(currentLog.response_data, null, 2) }}</pre>
      </div>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import * as logsApi from '@/api/logs'
import * as settingsApi from '@/api/settings'
import type { AuditLog } from '@/types'

// State
const loading = ref(false)
const logs = ref<AuditLog[]>([])
const adminOptions = ref<any[]>([])
const actionOptions = ref<Record<string, string>>({})
const moduleOptions = ref<string[]>([])
const stats = reactive({
  today_count: 0,
  week_count: 0,
  active_admins: 0,
  sensitive_count: 0,
})
const filters = reactive({
  admin_id: '',
  action: '',
  module: '',
  dateRange: null as [string, string] | null,
})
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0,
})
const detailVisible = ref(false)
const currentLog = ref<AuditLog | null>(null)

// Fetch data
const fetchLogs = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (filters.admin_id) params.admin_id = filters.admin_id
    if (filters.action) params.action = filters.action
    if (filters.module) params.module = filters.module
    if (filters.dateRange) {
      params.start_date = filters.dateRange[0]
      params.end_date = filters.dateRange[1]
    }

    const response = await logsApi.getLogs(params)
    logs.value = response.items
    pagination.total = response.total
  } catch (e) {
    ElMessage.error('获取日志列表失败')
  } finally {
    loading.value = false
  }
}

const fetchStats = async () => {
  try {
    const data = await logsApi.getLogStats(7)
    Object.assign(stats, data)
  } catch (e) {
    console.error('Failed to fetch stats:', e)
  }
}

const fetchFilters = async () => {
  try {
    const [adminsData, actionsData, modulesData] = await Promise.all([
      settingsApi.getAdmins({ page: 1, page_size: 100 }),
      logsApi.getLogActions(),
      logsApi.getLogModules(),
    ])
    adminOptions.value = adminsData.items || []
    actionOptions.value = actionsData.actions || {}
    moduleOptions.value = modulesData.modules || []
  } catch (e) {
    console.error('Failed to fetch filter options:', e)
  }
}

// Handlers
const handleSearch = () => {
  pagination.page = 1
  fetchLogs()
}

const handleReset = () => {
  filters.admin_id = ''
  filters.action = ''
  filters.module = ''
  filters.dateRange = null
  handleSearch()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchLogs()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchLogs()
}

const handleView = async (log: AuditLog) => {
  try {
    const detail = await logsApi.getLogDetail(log.id)
    currentLog.value = detail
    detailVisible.value = true
  } catch (e) {
    ElMessage.error('获取日志详情失败')
  }
}

const handleExport = async () => {
  try {
    const params: any = { format: 'xlsx' }
    if (filters.admin_id) params.admin_id = filters.admin_id
    if (filters.action) params.action = filters.action
    if (filters.module) params.module = filters.module
    if (filters.dateRange) {
      params.start_date = filters.dateRange[0]
      params.end_date = filters.dateRange[1]
    }

    const blob = await logsApi.exportLogs(params)
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `audit_logs_${new Date().toISOString().split('T')[0]}.xlsx`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('导出成功')
  } catch (e) {
    ElMessage.error('导出失败')
  }
}

// Helpers
const getActionTag = (action: string) => {
  const sensitiveActions = ['delete', 'update_password', 'disable', 'reset']
  if (sensitiveActions.some(a => action.includes(a))) return 'danger'
  if (action.includes('create') || action.includes('add')) return 'success'
  if (action.includes('update') || action.includes('edit')) return 'warning'
  return 'info'
}

const parseUserAgent = (ua: string) => {
  if (!ua) return '-'
  if (ua.includes('Windows')) return 'Windows'
  if (ua.includes('Mac')) return 'Mac'
  if (ua.includes('Linux')) return 'Linux'
  if (ua.includes('iPhone') || ua.includes('iPad')) return 'iOS'
  if (ua.includes('Android')) return 'Android'
  return 'Other'
}

const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Init
onMounted(() => {
  fetchLogs()
  fetchStats()
  fetchFilters()
})
</script>

<style scoped lang="scss">
.audit-logs {
  h4 {
    margin-bottom: 10px;
    color: #333;
  }

  .log-data {
    background: #f5f5f5;
    padding: 12px;
    border-radius: 4px;
    font-size: 12px;
    overflow-x: auto;
    max-height: 200px;
  }
}
</style>
