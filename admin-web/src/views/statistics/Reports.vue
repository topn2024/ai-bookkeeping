<template>
  <div class="reports">
    <div class="page-header">
      <h2 class="page-title">报表中心</h2>
      <el-button type="primary" @click="handleGenerateReport">
        <el-icon><DocumentAdd /></el-icon>生成报表
      </el-button>
    </div>

    <!-- Quick Reports -->
    <el-row :gutter="20" class="mb-20">
      <el-col v-for="report in quickReports" :key="report.type" :span="6">
        <el-card shadow="hover" class="report-card" @click="downloadQuickReport(report.type)">
          <div class="report-icon" :style="{ backgroundColor: report.color + '20', color: report.color }">
            <el-icon :size="32"><component :is="report.icon" /></el-icon>
          </div>
          <div class="report-info">
            <h3>{{ report.name }}</h3>
            <p>{{ report.description }}</p>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Report History -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>报表历史</span>
          <el-input
            v-model="searchKeyword"
            placeholder="搜索报表"
            style="width: 200px;"
            clearable
            @clear="fetchReports"
            @keyup.enter="fetchReports"
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
        </div>
      </template>

      <el-table v-loading="loading" :data="reports" stripe>
        <el-table-column prop="name" label="报表名称" min-width="200" />
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="getReportTypeTag(row.type)" size="small">
              {{ getReportTypeText(row.type) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusTag(row.status)" size="small">
              {{ getStatusText(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="file_size" label="大小" width="100">
          <template #default="{ row }">
            {{ formatFileSize(row.file_size) }}
          </template>
        </el-table-column>
        <el-table-column prop="created_by" label="创建人" width="120" />
        <el-table-column prop="created_at" label="创建时间" width="160">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button
              v-if="row.status === 'completed'"
              type="primary"
              text
              size="small"
              @click="handleDownload(row)"
            >
              下载
            </el-button>
            <el-button type="danger" text size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-container">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :total="pagination.total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <!-- Generate Report Dialog -->
    <el-dialog v-model="generateDialogVisible" title="生成报表" width="600px">
      <el-form ref="generateFormRef" :model="generateForm" :rules="generateRules" label-width="100px">
        <el-form-item label="报表类型" prop="type">
          <el-select v-model="generateForm.type" placeholder="选择报表类型">
            <el-option label="用户报表" value="user" />
            <el-option label="交易报表" value="transaction" />
            <el-option label="财务报表" value="financial" />
            <el-option label="综合报表" value="comprehensive" />
          </el-select>
        </el-form-item>
        <el-form-item label="报表名称" prop="name">
          <el-input v-model="generateForm.name" placeholder="自定义报表名称" />
        </el-form-item>
        <el-form-item label="时间范围" prop="dateRange">
          <el-date-picker
            v-model="generateForm.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
          />
        </el-form-item>
        <el-form-item label="导出格式" prop="format">
          <el-radio-group v-model="generateForm.format">
            <el-radio-button label="xlsx">Excel</el-radio-button>
            <el-radio-button label="csv">CSV</el-radio-button>
            <el-radio-button label="pdf">PDF</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="包含图表" prop="include_charts">
          <el-switch v-model="generateForm.include_charts" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="generateDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="generating" @click="submitGenerate">生成</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import * as statisticsApi from '@/api/statistics'

// Quick reports config
const quickReports = [
  { type: 'daily', name: '日报', description: '今日数据汇总', icon: 'Calendar', color: '#6495ED' },
  { type: 'weekly', name: '周报', description: '本周数据汇总', icon: 'DataLine', color: '#52c41a' },
  { type: 'monthly', name: '月报', description: '本月数据汇总', icon: 'TrendCharts', color: '#fa8c16' },
  { type: 'annual', name: '年报', description: '本年数据汇总', icon: 'Document', color: '#722ed1' },
]

// State
const loading = ref(false)
const reports = ref<any[]>([])
const searchKeyword = ref('')
const pagination = reactive({
  page: 1,
  pageSize: 10,
  total: 0,
})

// Generate dialog
const generateDialogVisible = ref(false)
const generating = ref(false)
const generateFormRef = ref<FormInstance>()
const generateForm = reactive({
  type: '',
  name: '',
  dateRange: null as [string, string] | null,
  format: 'xlsx',
  include_charts: true,
})
const generateRules: FormRules = {
  type: [{ required: true, message: '请选择报表类型', trigger: 'change' }],
  dateRange: [{ required: true, message: '请选择时间范围', trigger: 'change' }],
  format: [{ required: true, message: '请选择导出格式', trigger: 'change' }],
}

// Fetch data
const fetchReports = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (searchKeyword.value) params.keyword = searchKeyword.value

    const response = await statisticsApi.getReports(params)
    reports.value = response.items
    pagination.total = response.total
  } catch (e) {
    ElMessage.error('获取报表列表失败')
  } finally {
    loading.value = false
  }
}

// Handlers
const handlePageChange = (page: number) => {
  pagination.page = page
  fetchReports()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchReports()
}

const handleGenerateReport = () => {
  generateForm.type = ''
  generateForm.name = ''
  generateForm.dateRange = null
  generateForm.format = 'xlsx'
  generateForm.include_charts = true
  generateDialogVisible.value = true
}

const submitGenerate = async () => {
  if (!generateFormRef.value) return
  await generateFormRef.value.validate(async (valid) => {
    if (!valid) return

    generating.value = true
    try {
      await statisticsApi.generateReport({
        type: generateForm.type,
        name: generateForm.name || undefined,
        start_date: generateForm.dateRange![0],
        end_date: generateForm.dateRange![1],
        format: generateForm.format,
        include_charts: generateForm.include_charts,
      })
      ElMessage.success('报表生成任务已创建')
      generateDialogVisible.value = false
      fetchReports()
    } catch (e) {
      ElMessage.error('生成报表失败')
    } finally {
      generating.value = false
    }
  })
}

const downloadQuickReport = async (type: string) => {
  try {
    ElMessage.info('正在生成报表...')
    const blob = await statisticsApi.downloadQuickReport(type)
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${type}_report_${new Date().toISOString().split('T')[0]}.xlsx`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('下载成功')
  } catch (e) {
    ElMessage.error('下载失败')
  }
}

const handleDownload = async (report: any) => {
  try {
    const blob = await statisticsApi.downloadReport(report.id)
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `${report.name}.${report.format || 'xlsx'}`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('下载成功')
  } catch (e) {
    ElMessage.error('下载失败')
  }
}

const handleDelete = async (report: any) => {
  try {
    await ElMessageBox.confirm(`确定要删除报表 "${report.name}" 吗？`, '确认删除', { type: 'warning' })
    await statisticsApi.deleteReport(report.id)
    ElMessage.success('删除成功')
    fetchReports()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

// Formatters
const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

const formatFileSize = (bytes: number) => {
  if (!bytes) return '-'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
}

const getReportTypeTag = (type: string) => {
  const map: Record<string, string> = {
    user: 'primary',
    transaction: 'success',
    financial: 'warning',
    comprehensive: 'danger',
  }
  return map[type] || ''
}

const getReportTypeText = (type: string) => {
  const map: Record<string, string> = {
    user: '用户报表',
    transaction: '交易报表',
    financial: '财务报表',
    comprehensive: '综合报表',
  }
  return map[type] || type
}

const getStatusTag = (status: string) => {
  const map: Record<string, string> = {
    pending: 'warning',
    processing: 'info',
    completed: 'success',
    failed: 'danger',
  }
  return map[status] || ''
}

const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    pending: '等待中',
    processing: '生成中',
    completed: '已完成',
    failed: '失败',
  }
  return map[status] || status
}

// Init
onMounted(() => {
  fetchReports()
})
</script>

<style scoped lang="scss">
.reports {
  .report-card {
    cursor: pointer;
    transition: all 0.3s;

    &:hover {
      transform: translateY(-4px);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }

    :deep(.el-card__body) {
      display: flex;
      align-items: center;
      padding: 20px;
    }

    .report-icon {
      width: 64px;
      height: 64px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 16px;
    }

    .report-info {
      h3 {
        margin: 0 0 8px;
        font-size: 16px;
        color: #333;
      }

      p {
        margin: 0;
        font-size: 12px;
        color: #999;
      }
    }
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
}
</style>
