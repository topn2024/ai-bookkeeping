<template>
  <div class="backup-list">
    <div class="page-header">
      <h2 class="page-title">备份管理</h2>
      <el-button type="primary" @click="handleCreateBackup">
        <el-icon><Plus /></el-icon>创建备份
      </el-button>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="用户ID">
          <el-input v-model="filters.user_id" placeholder="用户ID" clearable style="width: 150px;" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filters.status" placeholder="全部" clearable style="width: 120px;">
            <el-option label="进行中" value="pending" />
            <el-option label="已完成" value="completed" />
            <el-option label="失败" value="failed" />
          </el-select>
        </el-form-item>
        <el-form-item label="日期范围">
          <el-date-picker
            v-model="filters.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始"
            end-placeholder="结束"
            value-format="YYYY-MM-DD"
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
          <el-statistic title="总备份数" :value="stats.total_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总大小" :value="stats.total_size" suffix="MB" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="今日备份" :value="stats.today_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="失败备份" :value="stats.failed_count" value-style="color: #ff4d4f" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Backup Table -->
    <div class="table-container">
      <el-table v-loading="loading" :data="backups" stripe>
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="getBackupTypeTag(row.type)" size="small">
              {{ getBackupTypeText(row.type) }}
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
        <el-table-column prop="record_count" label="记录数" width="100" />
        <el-table-column prop="created_at" label="创建时间" width="160">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="expires_at" label="过期时间" width="160">
          <template #default="{ row }">
            {{ row.expires_at ? formatDateTime(row.expires_at) : '永不过期' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
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
            <el-button
              v-if="row.status === 'completed'"
              type="success"
              text
              size="small"
              @click="handleRestore(row)"
            >
              恢复
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
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Create Backup Dialog -->
    <el-dialog v-model="createDialogVisible" title="创建备份" width="500px">
      <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-width="100px">
        <el-form-item label="用户ID" prop="user_id">
          <el-input v-model="createForm.user_id" placeholder="留空则备份所有用户" />
        </el-form-item>
        <el-form-item label="备份类型" prop="type">
          <el-select v-model="createForm.type" placeholder="选择备份类型">
            <el-option label="完整备份" value="full" />
            <el-option label="增量备份" value="incremental" />
            <el-option label="仅交易" value="transactions" />
          </el-select>
        </el-form-item>
        <el-form-item label="过期时间" prop="expires_days">
          <el-input-number v-model="createForm.expires_days" :min="0" :max="365" placeholder="天数，0表示永不过期" style="width: 100%;" />
          <div class="form-tip">0 表示永不过期</div>
        </el-form-item>
        <el-form-item label="备注" prop="note">
          <el-input v-model="createForm.note" type="textarea" rows="3" placeholder="备份说明" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="creating" @click="submitCreate">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import * as dataApi from '@/api/data'
import type { Backup, TagType } from '@/types'

// State
const loading = ref(false)
const backups = ref<Backup[]>([])
const stats = reactive({
  total_count: 0,
  total_size: 0,
  today_count: 0,
  failed_count: 0,
})
const filters = reactive({
  user_id: '',
  status: '',
  dateRange: null as [string, string] | null,
})
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0,
})

// Create dialog
const createDialogVisible = ref(false)
const creating = ref(false)
const createFormRef = ref<FormInstance>()
const createForm = reactive({
  user_id: '',
  type: 'full',
  expires_days: 30,
  note: '',
})
const createRules: FormRules = {
  type: [{ required: true, message: '请选择备份类型', trigger: 'change' }],
}

// Fetch data
const fetchBackups = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (filters.user_id) params.user_id = filters.user_id
    if (filters.status) params.status = filters.status
    if (filters.dateRange) {
      params.start_date = filters.dateRange[0]
      params.end_date = filters.dateRange[1]
    }

    const response = await dataApi.getBackups(params)
    backups.value = response.items
    pagination.total = response.total

    if (response.stats) {
      Object.assign(stats, response.stats)
    }
  } catch (e) {
    ElMessage.error('获取备份列表失败')
  } finally {
    loading.value = false
  }
}

// Handlers
const handleSearch = () => {
  pagination.page = 1
  fetchBackups()
}

const handleReset = () => {
  filters.user_id = ''
  filters.status = ''
  filters.dateRange = null
  handleSearch()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchBackups()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchBackups()
}

const handleCreateBackup = () => {
  createForm.user_id = ''
  createForm.type = 'full'
  createForm.expires_days = 30
  createForm.note = ''
  createDialogVisible.value = true
}

const submitCreate = async () => {
  if (!createFormRef.value) return
  await createFormRef.value.validate(async (valid) => {
    if (!valid) return

    creating.value = true
    try {
      await dataApi.createBackup({
        user_id: createForm.user_id || undefined,
        type: createForm.type,
        expires_days: createForm.expires_days,
        note: createForm.note || undefined,
      })
      ElMessage.success('备份任务已创建')
      createDialogVisible.value = false
      fetchBackups()
    } catch (e) {
      ElMessage.error('创建备份失败')
    } finally {
      creating.value = false
    }
  })
}

const handleDownload = async (backup: Backup) => {
  try {
    const blob = await dataApi.downloadBackup(backup.id)
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `backup_${backup.id}_${new Date().toISOString().split('T')[0]}.zip`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('下载成功')
  } catch (e) {
    ElMessage.error('下载失败')
  }
}

const handleRestore = async (backup: Backup) => {
  try {
    await ElMessageBox.confirm(
      `确定要从备份 #${backup.id} 恢复数据吗？这将覆盖当前数据！`,
      '确认恢复',
      { type: 'warning' }
    )
    await dataApi.restoreBackup(backup.id)
    ElMessage.success('恢复任务已开始')
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('恢复失败')
    }
  }
}

const handleDelete = async (backup: Backup) => {
  try {
    await ElMessageBox.confirm(`确定要删除备份 #${backup.id} 吗？`, '确认删除', { type: 'warning' })
    await dataApi.deleteBackup(backup.id)
    ElMessage.success('删除成功')
    fetchBackups()
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

const getBackupTypeTag = (type: string): TagType => {
  const map: Record<string, TagType> = {
    full: 'primary',
    incremental: 'success',
    transactions: 'info',
  }
  return map[type] || ''
}

const getBackupTypeText = (type: string) => {
  const map: Record<string, string> = {
    full: '完整备份',
    incremental: '增量备份',
    transactions: '仅交易',
  }
  return map[type] || type
}

const getStatusTag = (status: string): TagType => {
  const map: Record<string, TagType> = {
    pending: 'warning',
    completed: 'success',
    failed: 'danger',
  }
  return map[status] || ''
}

const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    pending: '进行中',
    completed: '已完成',
    failed: '失败',
  }
  return map[status] || status
}

// Init
onMounted(() => {
  fetchBackups()
})
</script>
