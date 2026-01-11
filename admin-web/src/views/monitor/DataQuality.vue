<template>
  <div class="data-quality">
    <div class="page-header">
      <h2 class="page-title">数据质量监控</h2>
      <div class="header-actions">
        <el-button @click="fetchOverview">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
        <el-button type="primary" @click="exportReport">
          <el-icon><Download /></el-icon>导出报告
        </el-button>
      </div>
    </div>

    <!-- Overview Cards -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ overview.overall_score }}</div>
          <div class="stat-label">综合评分</div>
          <div class="stat-tag">
            <el-tag :type="getScoreTag(overview.overall_score)">
              {{ getScoreLevel(overview.overall_score) }}
            </el-tag>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card danger">
          <div class="stat-value">{{ overview.recent_issues?.critical || 0 }}</div>
          <div class="stat-label">严重问题</div>
          <div class="stat-subtitle">Critical</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card warning">
          <div class="stat-value">
            {{ (overview.recent_issues?.high || 0) + (overview.recent_issues?.medium || 0) }}
          </div>
          <div class="stat-label">待处理</div>
          <div class="stat-subtitle">High & Medium</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card success">
          <div class="stat-value">{{ resolvedCount }}</div>
          <div class="stat-label">已解决</div>
          <div class="stat-subtitle">近7天</div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Table Quality Scores -->
    <el-card class="mb-20">
      <template #header>数据表质量评分</template>
      <div class="table-scores">
        <div
          v-for="table in overview.by_table"
          :key="table.table_name"
          class="table-score-item"
        >
          <div class="table-info">
            <span class="table-name">{{ table.table_name }}</span>
            <span class="issue-count">{{ table.issue_count }} 个问题</span>
          </div>
          <el-progress
            :percentage="table.score"
            :color="getProgressColor(table.score)"
            :stroke-width="12"
          />
        </div>
        <div v-if="!overview.by_table?.length" class="empty-state">
          <el-icon><CircleCheck /></el-icon>
          <p>所有表数据质量良好</p>
        </div>
      </div>
    </el-card>

    <!-- Issues List -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>问题列表</span>
          <div class="filters">
            <el-select
              v-model="filters.severity"
              placeholder="严重程度"
              clearable
              style="width: 120px; margin-right: 10px"
              @change="fetchChecks"
            >
              <el-option label="Critical" value="critical" />
              <el-option label="High" value="high" />
              <el-option label="Medium" value="medium" />
              <el-option label="Low" value="low" />
            </el-select>
            <el-select
              v-model="filters.status"
              placeholder="状态"
              clearable
              style="width: 120px; margin-right: 10px"
              @change="fetchChecks"
            >
              <el-option label="待处理" value="detected" />
              <el-option label="调查中" value="investigating" />
              <el-option label="已解决" value="fixed" />
              <el-option label="已忽略" value="ignored" />
            </el-select>
            <el-select
              v-model="filters.days"
              placeholder="时间范围"
              style="width: 120px"
              @change="fetchChecks"
            >
              <el-option label="最近7天" :value="7" />
              <el-option label="最近30天" :value="30" />
              <el-option label="最近90天" :value="90" />
            </el-select>
          </div>
        </div>
      </template>

      <el-table
        :data="checks"
        stripe
        style="width: 100%"
        @row-click="showCheckDetail"
        class="clickable-table"
      >
        <el-table-column prop="check_time" label="检查时间" width="180">
          <template #default="{ row }">
            {{ formatDateTime(row.check_time) }}
          </template>
        </el-table-column>
        <el-table-column prop="severity" label="严重程度" width="120">
          <template #default="{ row }">
            <el-tag :type="getSeverityTag(row.severity)">
              {{ row.severity }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="check_type" label="检查类型" width="150">
          <template #default="{ row }">
            {{ getCheckTypeText(row.check_type) }}
          </template>
        </el-table-column>
        <el-table-column prop="target_table" label="目标表" width="150" />
        <el-table-column prop="target_column" label="目标字段" width="150" />
        <el-table-column prop="affected_records" label="影响记录" width="120">
          <template #default="{ row }">
            {{ row.affected_records }} / {{ row.total_records }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="getStatusTag(row.status)">
              {{ getStatusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button
              v-if="row.status === 'detected'"
              type="success"
              size="small"
              @click.stop="resolveCheck(row)"
            >
              标记解决
            </el-button>
            <el-button
              v-if="row.status === 'detected'"
              type="warning"
              size="small"
              @click.stop="ignoreCheck(row)"
            >
              忽略
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- Pagination -->
      <div class="pagination-wrapper">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.page_size"
          :total="pagination.total"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          @current-change="fetchChecks"
          @size-change="fetchChecks"
        />
      </div>
    </el-card>

    <!-- Detail Dialog -->
    <el-dialog
      v-model="detailDialogVisible"
      title="问题详情"
      width="800px"
      destroy-on-close
    >
      <div v-if="selectedCheck" class="check-detail">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="检查时间">
            {{ formatDateTime(selectedCheck.check_time) }}
          </el-descriptions-item>
          <el-descriptions-item label="严重程度">
            <el-tag :type="getSeverityTag(selectedCheck.severity)">
              {{ selectedCheck.severity }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="检查类型">
            {{ getCheckTypeText(selectedCheck.check_type) }}
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="getStatusTag(selectedCheck.status)">
              {{ getStatusText(selectedCheck.status) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="目标表">
            {{ selectedCheck.target_table }}
          </el-descriptions-item>
          <el-descriptions-item label="目标字段">
            {{ selectedCheck.target_column || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="总记录数">
            {{ selectedCheck.total_records }}
          </el-descriptions-item>
          <el-descriptions-item label="受影响记录">
            {{ selectedCheck.affected_records }}
          </el-descriptions-item>
        </el-descriptions>

        <el-divider />

        <h4>问题详情</h4>
        <el-card v-if="selectedCheck.issue_details" shadow="never" class="issue-details">
          <pre>{{ JSON.stringify(selectedCheck.issue_details, null, 2) }}</pre>
        </el-card>

        <template v-if="selectedCheck.resolved_at">
          <el-divider />
          <h4>处理信息</h4>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="处理人">
              {{ selectedCheck.assigned_to || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="处理时间">
              {{ formatDateTime(selectedCheck.resolved_at) }}
            </el-descriptions-item>
            <el-descriptions-item label="处理说明">
              {{ selectedCheck.resolution_notes || '-' }}
            </el-descriptions-item>
          </el-descriptions>
        </template>
      </div>
    </el-dialog>

    <!-- Resolve Dialog -->
    <el-dialog
      v-model="resolveDialogVisible"
      title="标记问题已解决"
      width="500px"
    >
      <el-form :model="resolveForm" label-width="100px">
        <el-form-item label="处理说明" required>
          <el-input
            v-model="resolveForm.resolution_notes"
            type="textarea"
            :rows="4"
            placeholder="请说明如何解决的这个问题"
          />
        </el-form-item>
        <el-form-item label="处理人">
          <el-input
            v-model="resolveForm.assigned_to"
            placeholder="默认为当前管理员"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="resolveDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmResolve">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import axios from 'axios'
import { formatDateTime } from '@/utils/format'

// Types
interface DataQualityCheck {
  id: number
  check_time: string
  check_type: string
  target_table: string
  target_column: string | null
  severity: string
  total_records: number
  affected_records: number
  issue_details: any
  status: string
  assigned_to: string | null
  resolved_at: string | null
  resolution_notes: string | null
}

interface TableQualityScore {
  table_name: string
  score: number
  total_records: number
  issue_count: number
}

interface Overview {
  overall_score: number
  recent_issues: {
    critical: number
    high: number
    medium: number
    low: number
  }
  by_table: TableQualityScore[]
  recent_checks: DataQualityCheck[]
}

// State
const overview = ref<Overview>({
  overall_score: 100,
  recent_issues: { critical: 0, high: 0, medium: 0, low: 0 },
  by_table: [],
  recent_checks: [],
})

const checks = ref<DataQualityCheck[]>([])
const selectedCheck = ref<DataQualityCheck | null>(null)
const detailDialogVisible = ref(false)
const resolveDialogVisible = ref(false)

const filters = ref({
  severity: '',
  status: '',
  days: 7,
})

const pagination = ref({
  page: 1,
  page_size: 20,
  total: 0,
})

const resolveForm = ref({
  resolution_notes: '',
  assigned_to: '',
})

// Computed
const resolvedCount = computed(() => {
  return overview.value.recent_checks?.filter(c => c.status === 'fixed').length || 0
})

// API Functions
const fetchOverview = async () => {
  try {
    const { data } = await axios.get('/admin/monitoring/data-quality/overview', {
      params: { days: filters.value.days },
    })
    overview.value = data
  } catch (e) {
    ElMessage.error('获取数据质量概览失败')
  }
}

const fetchChecks = async () => {
  try {
    const params: any = {
      page: pagination.value.page,
      page_size: pagination.value.page_size,
      days: filters.value.days,
    }
    if (filters.value.severity) {
      params.severity = [filters.value.severity]
    }
    if (filters.value.status) {
      params.status = [filters.value.status]
    }

    const { data } = await axios.get('/admin/monitoring/data-quality/checks', {
      params,
    })

    checks.value = data.items
    pagination.value.total = data.total
  } catch (e) {
    ElMessage.error('获取问题列表失败')
  }
}

// UI Actions
const showCheckDetail = (row: DataQualityCheck) => {
  selectedCheck.value = row
  detailDialogVisible.value = true
}

const resolveCheck = (row: DataQualityCheck) => {
  selectedCheck.value = row
  resolveForm.value = {
    resolution_notes: '',
    assigned_to: '',
  }
  resolveDialogVisible.value = true
}

const confirmResolve = async () => {
  if (!resolveForm.value.resolution_notes) {
    ElMessage.warning('请填写处理说明')
    return
  }

  try {
    await axios.post(
      `/admin/monitoring/data-quality/checks/${selectedCheck.value?.id}/resolve`,
      resolveForm.value
    )
    ElMessage.success('已标记为已解决')
    resolveDialogVisible.value = false
    await fetchOverview()
    await fetchChecks()
  } catch (e) {
    ElMessage.error('操作失败')
  }
}

const ignoreCheck = async (row: DataQualityCheck) => {
  try {
    const notes = await ElMessageBox.prompt('请说明忽略原因', '忽略问题', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      inputPattern: /.+/,
      inputErrorMessage: '请输入忽略原因',
    })

    await axios.post(
      `/admin/monitoring/data-quality/checks/${row.id}/ignore`,
      { resolution_notes: notes.value }
    )
    ElMessage.success('已忽略')
    await fetchOverview()
    await fetchChecks()
  } catch (e) {
    if (e !== 'cancel') {
      ElMessage.error('操作失败')
    }
  }
}

const exportReport = () => {
  ElMessage.info('导出功能开发中...')
}

// Helper Functions
const getScoreTag = (score: number) => {
  if (score >= 95) return 'success'
  if (score >= 85) return 'warning'
  return 'danger'
}

const getScoreLevel = (score: number) => {
  if (score >= 95) return '优秀'
  if (score >= 85) return '良好'
  if (score >= 70) return '一般'
  return '需改进'
}

const getSeverityTag = (severity: string) => {
  const map: Record<string, string> = {
    critical: 'danger',
    high: 'danger',
    medium: 'warning',
    low: 'info',
  }
  return map[severity] || 'info'
}

const getStatusTag = (status: string) => {
  const map: Record<string, string> = {
    detected: 'danger',
    investigating: 'warning',
    fixed: 'success',
    ignored: 'info',
  }
  return map[status] || 'info'
}

const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    detected: '待处理',
    investigating: '调查中',
    fixed: '已解决',
    ignored: '已忽略',
  }
  return map[status] || status
}

const getCheckTypeText = (type: string) => {
  const map: Record<string, string> = {
    null_check: '空值检查',
    range_check: '范围检查',
    consistency_check: '一致性检查',
  }
  return map[type] || type
}

const getProgressColor = (score: number) => {
  if (score >= 95) return '#67c23a'
  if (score >= 85) return '#e6a23c'
  return '#f56c6c'
}

// Lifecycle
onMounted(() => {
  fetchOverview()
  fetchChecks()
})
</script>

<style scoped>
.data-quality {
  padding: 20px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.page-title {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 10px;
}

.mb-20 {
  margin-bottom: 20px;
}

.stat-card {
  text-align: center;
  padding: 10px;
}

.stat-card.danger {
  border-left: 4px solid #f56c6c;
}

.stat-card.warning {
  border-left: 4px solid #e6a23c;
}

.stat-card.success {
  border-left: 4px solid #67c23a;
}

.stat-value {
  font-size: 32px;
  font-weight: bold;
  color: #303133;
  margin-bottom: 8px;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-bottom: 8px;
}

.stat-subtitle {
  font-size: 12px;
  color: #c0c4cc;
}

.stat-tag {
  margin-top: 8px;
}

.table-scores {
  max-height: 400px;
  overflow-y: auto;
}

.table-score-item {
  margin-bottom: 16px;
}

.table-info {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
}

.table-name {
  font-weight: 500;
  color: #303133;
}

.issue-count {
  font-size: 12px;
  color: #909399;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.filters {
  display: flex;
  gap: 10px;
}

.clickable-table :deep(.el-table__row) {
  cursor: pointer;
}

.pagination-wrapper {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
}

.check-detail h4 {
  margin: 16px 0 8px 0;
  font-size: 16px;
  font-weight: 600;
}

.issue-details pre {
  background-color: #f5f7fa;
  padding: 12px;
  border-radius: 4px;
  overflow-x: auto;
  font-size: 12px;
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: #909399;
}

.empty-state .el-icon {
  font-size: 48px;
  color: #67c23a;
  margin-bottom: 16px;
}
</style>
