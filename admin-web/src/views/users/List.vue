<template>
  <div class="user-list">
    <div class="page-header">
      <h2 class="page-title">用户管理</h2>
      <el-button type="primary" @click="handleExport">
        <el-icon><Download /></el-icon>导出用户
      </el-button>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="关键词">
          <el-input v-model="filters.keyword" placeholder="手机号/昵称" clearable @keyup.enter="handleSearch" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filters.is_active" placeholder="全部" clearable>
            <el-option label="正常" :value="true" />
            <el-option label="禁用" :value="false" />
          </el-select>
        </el-form-item>
        <el-form-item label="注册时间">
          <el-date-picker
            v-model="filters.dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
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

    <!-- User Table -->
    <div class="table-container">
      <el-table
        v-loading="loading"
        :data="users"
        stripe
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="50" />
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="display_name" label="用户信息" min-width="180">
          <template #default="{ row }">
            <div class="user-info-cell">
              <el-avatar :size="40" :src="row.avatar_url">
                {{ row.display_name?.charAt(0) || '?' }}
              </el-avatar>
              <div class="user-details">
                <div class="user-name">{{ row.display_name || '-' }}</div>
                <div class="user-email">{{ row.email_masked }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="is_premium" label="会员" width="80">
          <template #default="{ row }">
            <el-tag :type="row.is_premium ? 'warning' : 'info'" size="small">
              {{ row.is_premium ? '会员' : '普通' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="is_active" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.is_active ? 'success' : 'danger'" size="small">
              {{ row.is_active ? '正常' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="transaction_count" label="交易数" width="100" />
        <el-table-column prop="created_at" label="注册时间" width="180">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="last_login_at" label="最后登录" width="180">
          <template #default="{ row }">
            {{ row.last_login_at ? formatDateTime(row.last_login_at) : '-' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleView(row)">查看</el-button>
            <el-button
              v-if="row.is_active"
              type="warning"
              text
              size="small"
              @click="handleDisable(row)"
            >
              禁用
            </el-button>
            <el-button
              v-else
              type="success"
              text
              size="small"
              @click="handleEnable(row)"
            >
              启用
            </el-button>
            <el-button
              type="danger"
              text
              size="small"
              @click="handleDelete(row)"
            >
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- Pagination -->
      <div class="pagination-container">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :total="pagination.total"
          :page-sizes="[10, 20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Batch Actions -->
    <div v-if="selectedUsers.length > 0" class="batch-actions">
      <el-alert type="info" :closable="false">
        <template #title>
          已选择 {{ selectedUsers.length }} 个用户
          <el-button type="primary" text @click="handleBatchDisable">批量禁用</el-button>
          <el-button type="success" text @click="handleBatchEnable">批量启用</el-button>
          <el-button type="danger" text @click="handleBatchDelete">批量删除</el-button>
        </template>
      </el-alert>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as usersApi from '@/api/users'
import { formatDateTime } from '@/utils'
import type { AppUser } from '@/types'

const router = useRouter()

// State
const loading = ref(false)
const users = ref<AppUser[]>([])
const selectedUsers = ref<AppUser[]>([])
const filters = reactive({
  keyword: '',
  is_active: null as boolean | null,
  dateRange: null as [string, string] | null,
})
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0,
})

// Fetch users
const fetchUsers = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (filters.keyword) params.search = filters.keyword
    if (filters.is_active !== null) params.is_active = filters.is_active
    if (filters.dateRange) {
      params.start_date = filters.dateRange[0]
      params.end_date = filters.dateRange[1]
    }

    const response = await usersApi.getUsers(params)
    users.value = response.items
    pagination.total = response.total
  } catch (e) {
    ElMessage.error('获取用户列表失败')
  } finally {
    loading.value = false
  }
}

// Handlers
const handleSearch = () => {
  pagination.page = 1
  fetchUsers()
}

const handleReset = () => {
  filters.keyword = ''
  filters.is_active = null
  filters.dateRange = null
  handleSearch()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchUsers()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchUsers()
}

const handleSelectionChange = (selection: AppUser[]) => {
  selectedUsers.value = selection
}

const handleView = (user: AppUser) => {
  router.push(`/users/${user.id}`)
}

const handleDisable = async (user: AppUser) => {
  try {
    await ElMessageBox.confirm(`确定要禁用用户 "${user.display_name || user.email_masked}" 吗？`, '确认禁用', {
      type: 'warning',
    })
    await usersApi.disableUser(user.id)
    ElMessage.success('禁用成功')
    fetchUsers()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('禁用失败')
    }
  }
}

const handleEnable = async (user: AppUser) => {
  try {
    await usersApi.enableUser(user.id)
    ElMessage.success('启用成功')
    fetchUsers()
  } catch (e) {
    ElMessage.error('启用失败')
  }
}

const handleDelete = async (user: AppUser) => {
  try {
    await ElMessageBox.confirm(`确定要删除用户 "${user.display_name || user.email_masked}" 吗？此操作不可恢复！`, '确认删除', {
      type: 'warning',
    })
    await usersApi.deleteUser(user.id)
    ElMessage.success('删除成功')
    fetchUsers()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const handleBatchDisable = async () => {
  try {
    await ElMessageBox.confirm(`确定要禁用选中的 ${selectedUsers.value.length} 个用户吗？`, '批量禁用', {
      type: 'warning',
    })
    await usersApi.batchOperation({
      user_ids: selectedUsers.value.map(u => u.id),
      operation: 'disable',
    })
    ElMessage.success('批量禁用成功')
    fetchUsers()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('批量禁用失败')
    }
  }
}

const handleBatchEnable = async () => {
  try {
    await usersApi.batchOperation({
      user_ids: selectedUsers.value.map(u => u.id),
      operation: 'enable',
    })
    ElMessage.success('批量启用成功')
    fetchUsers()
  } catch (e: any) {
    ElMessage.error('批量启用失败')
  }
}

const handleBatchDelete = async () => {
  try {
    await ElMessageBox.confirm(`确定要删除选中的 ${selectedUsers.value.length} 个用户吗？此操作不可恢复！`, '批量删除', {
      type: 'warning',
    })
    await usersApi.batchOperation({
      user_ids: selectedUsers.value.map(u => u.id),
      operation: 'delete',
    })
    ElMessage.success('批量删除成功')
    fetchUsers()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('批量删除失败')
    }
  }
}

const handleExport = async () => {
  try {
    const blob = await usersApi.exportUsers({
      format: 'xlsx',
      is_active: filters.is_active ?? undefined,
    })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `users_${new Date().toISOString().split('T')[0]}.xlsx`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('导出成功')
  } catch (e) {
    ElMessage.error('导出失败')
  }
}

// Init
onMounted(() => {
  fetchUsers()
})
</script>

<style scoped lang="scss">
.user-list {
  .user-info-cell {
    display: flex;
    align-items: center;

    .el-avatar {
      margin-right: 12px;
    }

    .user-details {
      .user-name {
        font-weight: 500;
        color: #333;
      }

      .user-email {
        font-size: 12px;
        color: #999;
      }
    }
  }

  .batch-actions {
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 100;

    :deep(.el-alert) {
      padding: 12px 20px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    }
  }
}
</style>
