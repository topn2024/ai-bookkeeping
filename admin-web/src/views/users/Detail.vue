<template>
  <div v-loading="loading" class="user-detail">
    <div class="page-header">
      <div class="header-left">
        <el-button text @click="$router.back()">
          <el-icon><ArrowLeft /></el-icon>返回
        </el-button>
        <h2 class="page-title">用户详情</h2>
      </div>
      <div class="header-actions">
        <el-button v-if="user?.status === 'active'" type="warning" @click="handleDisable">禁用用户</el-button>
        <el-button v-else-if="user?.status === 'disabled'" type="success" @click="handleEnable">启用用户</el-button>
        <el-button v-if="user?.status !== 'deleted'" type="danger" @click="handleDelete">删除用户</el-button>
      </div>
    </div>

    <el-row :gutter="20">
      <!-- Basic Info -->
      <el-col :span="8">
        <el-card>
          <template #header>基本信息</template>
          <div class="user-profile">
            <el-avatar :size="80" :src="user?.avatar_url">
              {{ user?.nickname?.charAt(0) || '?' }}
            </el-avatar>
            <h3>{{ user?.nickname || '-' }}</h3>
            <el-tag :type="getStatusType(user?.status)">{{ getStatusText(user?.status) }}</el-tag>
          </div>
          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="ID">{{ user?.id }}</el-descriptions-item>
            <el-descriptions-item label="手机号">{{ user?.phone }}</el-descriptions-item>
            <el-descriptions-item label="邮箱">{{ user?.email || '-' }}</el-descriptions-item>
            <el-descriptions-item label="性别">{{ getGenderText(user?.gender) }}</el-descriptions-item>
            <el-descriptions-item label="注册时间">{{ formatDateTime(user?.created_at) }}</el-descriptions-item>
            <el-descriptions-item label="最后登录">{{ user?.last_login_at ? formatDateTime(user?.last_login_at) : '-' }}</el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>

      <!-- Statistics -->
      <el-col :span="16">
        <el-card class="mb-20">
          <template #header>数据统计</template>
          <el-row :gutter="20">
            <el-col :span="6">
              <div class="stat-item">
                <div class="stat-value">{{ userStats.transaction_count || 0 }}</div>
                <div class="stat-label">交易笔数</div>
              </div>
            </el-col>
            <el-col :span="6">
              <div class="stat-item">
                <div class="stat-value text-success">¥{{ formatMoney(userStats.total_income || 0) }}</div>
                <div class="stat-label">总收入</div>
              </div>
            </el-col>
            <el-col :span="6">
              <div class="stat-item">
                <div class="stat-value text-danger">¥{{ formatMoney(userStats.total_expense || 0) }}</div>
                <div class="stat-label">总支出</div>
              </div>
            </el-col>
            <el-col :span="6">
              <div class="stat-item">
                <div class="stat-value">{{ userStats.book_count || 0 }}</div>
                <div class="stat-label">账本数</div>
              </div>
            </el-col>
          </el-row>
        </el-card>

        <!-- Recent Transactions -->
        <el-card>
          <template #header>
            <div class="card-header">
              <span>最近交易</span>
              <el-button type="primary" text @click="viewAllTransactions">查看全部</el-button>
            </div>
          </template>
          <el-table :data="recentTransactions" size="small" stripe>
            <el-table-column prop="type" label="类型" width="80">
              <template #default="{ row }">
                <el-tag :type="row.type === 'income' ? 'success' : 'danger'" size="small">
                  {{ row.type === 'income' ? '收入' : '支出' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="amount" label="金额" width="120">
              <template #default="{ row }">
                <span :class="row.type === 'income' ? 'text-success' : 'text-danger'">
                  {{ row.type === 'income' ? '+' : '-' }}¥{{ formatMoney(row.amount) }}
                </span>
              </template>
            </el-table-column>
            <el-table-column prop="category_name" label="分类" />
            <el-table-column prop="note" label="备注">
              <template #default="{ row }">
                {{ row.note || '-' }}
              </template>
            </el-table-column>
            <el-table-column prop="transaction_time" label="时间" width="160">
              <template #default="{ row }">
                {{ formatDateTime(row.transaction_time) }}
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>

    <!-- User Books -->
    <el-card class="mt-20">
      <template #header>用户账本</template>
      <el-table :data="userBooks" size="small" stripe>
        <el-table-column prop="name" label="账本名称" />
        <el-table-column prop="type" label="类型">
          <template #default="{ row }">
            {{ getBookTypeText(row.type) }}
          </template>
        </el-table-column>
        <el-table-column prop="transaction_count" label="交易数" />
        <el-table-column prop="is_default" label="默认账本" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.is_default" type="success" size="small">是</el-tag>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- Login History -->
    <el-card class="mt-20">
      <template #header>登录历史</template>
      <el-table :data="loginHistory" size="small" stripe>
        <el-table-column prop="login_time" label="登录时间">
          <template #default="{ row }">
            {{ formatDateTime(row.login_time) }}
          </template>
        </el-table-column>
        <el-table-column prop="ip_address" label="IP地址" />
        <el-table-column prop="device" label="设备" />
        <el-table-column prop="location" label="位置">
          <template #default="{ row }">
            {{ row.location || '-' }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as usersApi from '@/api/users'
import type { AppUser } from '@/types'

const route = useRoute()
const router = useRouter()

// State
const loading = ref(false)
const user = ref<AppUser | null>(null)
const userStats = ref<any>({})
const recentTransactions = ref<any[]>([])
const userBooks = ref<any[]>([])
const loginHistory = ref<any[]>([])

const userId = route.params.id as string

// Fetch data
const fetchUserDetail = async () => {
  loading.value = true
  try {
    const data = await usersApi.getUserDetail(userId)
    user.value = data.user
    userStats.value = data.stats || {}
    recentTransactions.value = data.recent_transactions || []
    userBooks.value = data.books || []
    loginHistory.value = data.login_history || []
  } catch (e) {
    ElMessage.error('获取用户详情失败')
    router.back()
  } finally {
    loading.value = false
  }
}

// Handlers
const handleDisable = async () => {
  try {
    await ElMessageBox.confirm(`确定要禁用用户 "${user.value?.nickname || user.value?.phone}" 吗？`, '确认禁用', {
      type: 'warning',
    })
    await usersApi.disableUser(userId)
    ElMessage.success('禁用成功')
    fetchUserDetail()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('禁用失败')
    }
  }
}

const handleEnable = async () => {
  try {
    await usersApi.enableUser(userId)
    ElMessage.success('启用成功')
    fetchUserDetail()
  } catch (e) {
    ElMessage.error('启用失败')
  }
}

const handleDelete = async () => {
  try {
    await ElMessageBox.confirm(`确定要删除用户 "${user.value?.nickname || user.value?.phone}" 吗？此操作不可恢复！`, '确认删除', {
      type: 'warning',
    })
    await usersApi.deleteUser(userId)
    ElMessage.success('删除成功')
    router.push('/users')
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

const viewAllTransactions = () => {
  router.push(`/data/transactions?user_id=${userId}`)
}

// Formatters
const formatDateTime = (date: string | undefined) => {
  if (!date) return '-'
  return new Date(date).toLocaleString('zh-CN')
}

const formatMoney = (amount: number) => {
  return amount.toFixed(2)
}

const getStatusType = (status: string | undefined) => {
  const map: Record<string, string> = {
    active: 'success',
    disabled: 'warning',
    deleted: 'danger',
  }
  return map[status || ''] || 'info'
}

const getStatusText = (status: string | undefined) => {
  const map: Record<string, string> = {
    active: '正常',
    disabled: '禁用',
    deleted: '已删除',
  }
  return map[status || ''] || status
}

const getGenderText = (gender: string | undefined) => {
  const map: Record<string, string> = {
    male: '男',
    female: '女',
    other: '其他',
  }
  return map[gender || ''] || '未知'
}

const getBookTypeText = (type: string) => {
  const map: Record<string, string> = {
    personal: '个人账本',
    family: '家庭账本',
    business: '商业账本',
  }
  return map[type] || type
}

// Init
onMounted(() => {
  fetchUserDetail()
})
</script>

<style scoped lang="scss">
.user-detail {
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;

    .header-left {
      display: flex;
      align-items: center;

      .page-title {
        margin-left: 10px;
      }
    }
  }

  .user-profile {
    text-align: center;
    padding: 20px 0;

    .el-avatar {
      margin-bottom: 16px;
    }

    h3 {
      margin: 0 0 8px;
      font-size: 18px;
    }
  }

  .stat-item {
    text-align: center;
    padding: 20px;

    .stat-value {
      font-size: 24px;
      font-weight: 600;
      color: #333;
    }

    .stat-label {
      font-size: 14px;
      color: #999;
      margin-top: 8px;
    }
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
}
</style>
