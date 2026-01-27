<template>
  <div class="transaction-list">
    <div class="page-header">
      <h2 class="page-title">交易管理</h2>
      <el-button type="primary" @click="handleExport">
        <font-awesome-icon icon="download" class="el-icon" />导出数据
      </el-button>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="用户ID">
          <el-input v-model="filters.user_id" placeholder="用户ID" clearable />
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="filters.type" placeholder="全部" clearable>
            <el-option label="收入" value="income" />
            <el-option label="支出" value="expense" />
          </el-select>
        </el-form-item>
        <el-form-item label="金额范围" class="amount-range">
          <el-input-number v-model="filters.min_amount" :min="0" placeholder="最小" controls-position="right" />
          <span class="range-separator">-</span>
          <el-input-number v-model="filters.max_amount" :min="0" placeholder="最大" controls-position="right" />
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
            <font-awesome-icon icon="search" class="el-icon" />搜索
          </el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- Stats Summary -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总交易数" :value="summary.total_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总收入" :value="summary.total_income" :precision="2" prefix="¥" value-style="color: #52c41a" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总支出" :value="summary.total_expense" :precision="2" prefix="¥" value-style="color: #ff4d4f" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="净收入" :value="summary.net_income" :precision="2" prefix="¥" :value-style="{ color: summary.net_income >= 0 ? '#52c41a' : '#ff4d4f' }" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Transaction Table -->
    <div class="table-container">
      <el-table v-loading="loading" :data="transactions" stripe>
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
        <el-table-column prop="category_name" label="分类" width="120" />
        <el-table-column prop="book_name" label="账本" width="120" />
        <el-table-column prop="note" label="备注" min-width="150" show-overflow-tooltip>
          <template #default="{ row }">
            {{ row.note || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="交易时间" width="160">
          <template #default="{ row }">
            {{ formatTransactionDateTime(row) }}
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="160">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
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
    <el-dialog v-model="detailVisible" title="交易详情" width="500px">
      <el-descriptions v-if="currentTransaction" :column="1" border>
        <el-descriptions-item label="类型">
          <el-tag :type="currentTransaction.type === 'income' ? 'success' : 'danger'">
            {{ currentTransaction.type === 'income' ? '收入' : '支出' }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="金额">
          <span :class="currentTransaction.type === 'income' ? 'text-success' : 'text-danger'">
            ¥{{ formatMoney(currentTransaction.amount) }}
          </span>
        </el-descriptions-item>
        <el-descriptions-item label="分类">{{ currentTransaction.category_name }}</el-descriptions-item>
        <el-descriptions-item label="账户">{{ currentTransaction.account_name || '-' }}</el-descriptions-item>
        <el-descriptions-item label="账本">{{ currentTransaction.book_name }}</el-descriptions-item>
        <el-descriptions-item label="备注">{{ currentTransaction.note || '-' }}</el-descriptions-item>
        <el-descriptions-item label="交易时间">{{ formatTransactionDateTime(currentTransaction) }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatDateTime(currentTransaction.created_at) }}</el-descriptions-item>
        <el-descriptions-item label="更新时间">{{ formatDateTime(currentTransaction.updated_at) }}</el-descriptions-item>
      </el-descriptions>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import * as dataApi from '@/api/data'
import type { Transaction } from '@/types'

const route = useRoute()

// State
const loading = ref(false)
const transactions = ref<Transaction[]>([])
const summary = reactive({
  total_count: 0,
  total_income: 0,
  total_expense: 0,
  net_income: 0,
})
const filters = reactive({
  user_id: (route.query.user_id as string) || '',
  type: '',
  min_amount: undefined as number | undefined,
  max_amount: undefined as number | undefined,
  dateRange: null as [string, string] | null,
})
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0,
})
const detailVisible = ref(false)
const currentTransaction = ref<Transaction | null>(null)

// Fetch data
const fetchTransactions = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (filters.user_id) params.user_id = filters.user_id
    if (filters.type) params.type = filters.type
    if (filters.min_amount !== undefined) params.min_amount = filters.min_amount
    if (filters.max_amount !== undefined) params.max_amount = filters.max_amount
    if (filters.dateRange) {
      params.start_date = filters.dateRange[0]
      params.end_date = filters.dateRange[1]
    }

    const response = await dataApi.getTransactions(params)
    transactions.value = response.items
    pagination.total = response.total

    // Update summary
    if (response.summary) {
      Object.assign(summary, response.summary)
    }
  } catch (e) {
    ElMessage.error('获取交易列表失败')
  } finally {
    loading.value = false
  }
}

// Handlers
const handleSearch = () => {
  pagination.page = 1
  fetchTransactions()
}

const handleReset = () => {
  filters.user_id = ''
  filters.type = ''
  filters.min_amount = undefined
  filters.max_amount = undefined
  filters.dateRange = null
  handleSearch()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchTransactions()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchTransactions()
}

const handleView = (row: Transaction) => {
  currentTransaction.value = row
  detailVisible.value = true
}

const handleExport = async () => {
  try {
    const params: any = { format: 'xlsx' }
    if (filters.user_id) params.user_id = filters.user_id
    if (filters.type) params.type = filters.type
    if (filters.dateRange) {
      params.start_date = filters.dateRange[0]
      params.end_date = filters.dateRange[1]
    }

    const blob = await dataApi.exportTransactions(params)
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `transactions_${new Date().toISOString().split('T')[0]}.xlsx`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('导出成功')
  } catch (e) {
    ElMessage.error('导出失败')
  }
}

// Formatters
const formatDateTime = (date: string | null | undefined) => {
  if (!date) return '-'
  const d = new Date(date)
  if (isNaN(d.getTime())) return '-'
  return d.toLocaleString('zh-CN')
}

const formatTransactionDateTime = (row: Transaction) => {
  // Combine transaction_date and transaction_time
  const dateStr = row.transaction_date
  const timeStr = row.transaction_time
  if (!dateStr) return '-'
  if (timeStr) {
    // Combine date and time
    const d = new Date(`${dateStr}T${timeStr}`)
    if (!isNaN(d.getTime())) {
      return d.toLocaleString('zh-CN')
    }
  }
  // Fallback to date only
  const d = new Date(dateStr)
  if (isNaN(d.getTime())) return '-'
  return d.toLocaleDateString('zh-CN')
}

const formatMoney = (amount: number | string | null | undefined) => {
  if (amount === null || amount === undefined) return '0.00'
  const num = typeof amount === 'string' ? parseFloat(amount) : amount
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

// Init
onMounted(() => {
  fetchTransactions()
})
</script>

<style scoped lang="scss">
.transaction-list {
  .amount-range {
    :deep(.el-form-item__content) {
      display: flex;
      align-items: center;
      gap: 8px;
    }
  }

  .range-separator {
    color: #999;
    flex-shrink: 0;
  }
}
</style>
