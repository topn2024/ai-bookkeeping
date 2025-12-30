<template>
  <div class="book-list">
    <div class="page-header">
      <h2 class="page-title">账本管理</h2>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="用户ID">
          <el-input v-model="filters.user_id" placeholder="用户ID" clearable style="width: 150px;" />
        </el-form-item>
        <el-form-item label="账本类型">
          <el-select v-model="filters.type" placeholder="全部" clearable style="width: 150px;">
            <el-option label="个人账本" value="personal" />
            <el-option label="家庭账本" value="family" />
            <el-option label="商业账本" value="business" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">
            <el-icon><Search /></el-icon>搜索
          </el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- Book Table -->
    <div class="table-container">
      <el-table v-loading="loading" :data="books" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="账本名称" min-width="150" />
        <el-table-column prop="user_id" label="用户ID" width="100" />
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="getBookTypeTag(row.type)" size="small">
              {{ getBookTypeText(row.type) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="currency" label="货币" width="80" />
        <el-table-column prop="transaction_count" label="交易数" width="100" />
        <el-table-column prop="total_income" label="总收入" width="120">
          <template #default="{ row }">
            <span class="text-success">¥{{ formatMoney(row.total_income || 0) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="total_expense" label="总支出" width="120">
          <template #default="{ row }">
            <span class="text-danger">¥{{ formatMoney(row.total_expense || 0) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="is_default" label="默认" width="80">
          <template #default="{ row }">
            <el-tag v-if="row.is_default" type="success" size="small">是</el-tag>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="160">
          <template #default="{ row }">
            {{ formatDateTime(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="viewTransactions(row)">交易</el-button>
            <el-button type="info" text size="small" @click="handleView(row)">详情</el-button>
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

    <!-- Detail Dialog -->
    <el-dialog v-model="detailVisible" title="账本详情" width="600px">
      <el-descriptions v-if="currentBook" :column="2" border>
        <el-descriptions-item label="ID">{{ currentBook.id }}</el-descriptions-item>
        <el-descriptions-item label="用户ID">{{ currentBook.user_id }}</el-descriptions-item>
        <el-descriptions-item label="账本名称">{{ currentBook.name }}</el-descriptions-item>
        <el-descriptions-item label="类型">
          <el-tag :type="getBookTypeTag(currentBook.type)">
            {{ getBookTypeText(currentBook.type) }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="货币">{{ currentBook.currency }}</el-descriptions-item>
        <el-descriptions-item label="默认账本">{{ currentBook.is_default ? '是' : '否' }}</el-descriptions-item>
        <el-descriptions-item label="交易数">{{ currentBook.transaction_count }}</el-descriptions-item>
        <el-descriptions-item label="成员数">{{ currentBook.member_count || 1 }}</el-descriptions-item>
        <el-descriptions-item label="总收入">
          <span class="text-success">¥{{ formatMoney(currentBook.total_income || 0) }}</span>
        </el-descriptions-item>
        <el-descriptions-item label="总支出">
          <span class="text-danger">¥{{ formatMoney(currentBook.total_expense || 0) }}</span>
        </el-descriptions-item>
        <el-descriptions-item label="描述" :span="2">{{ currentBook.description || '-' }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatDateTime(currentBook.created_at) }}</el-descriptions-item>
        <el-descriptions-item label="更新时间">{{ formatDateTime(currentBook.updated_at) }}</el-descriptions-item>
      </el-descriptions>

      <!-- Book Members (if family/business) -->
      <div v-if="currentBook && currentBook.type !== 'personal'" class="mt-20">
        <h4>账本成员</h4>
        <el-table :data="currentBook.members || []" size="small" stripe>
          <el-table-column prop="user_id" label="用户ID" />
          <el-table-column prop="nickname" label="昵称" />
          <el-table-column prop="role" label="角色">
            <template #default="{ row }">
              <el-tag :type="row.role === 'owner' ? 'warning' : 'info'" size="small">
                {{ row.role === 'owner' ? '所有者' : '成员' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="joined_at" label="加入时间">
            <template #default="{ row }">
              {{ formatDateTime(row.joined_at) }}
            </template>
          </el-table-column>
        </el-table>
      </div>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import * as dataApi from '@/api/data'
import type { Book } from '@/types'

const router = useRouter()

// State
const loading = ref(false)
const books = ref<Book[]>([])
const filters = reactive({
  user_id: '',
  type: '',
})
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0,
})
const detailVisible = ref(false)
const currentBook = ref<Book | null>(null)

// Fetch data
const fetchBooks = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (filters.user_id) params.user_id = filters.user_id
    if (filters.type) params.type = filters.type

    const response = await dataApi.getBooks(params)
    books.value = response.items
    pagination.total = response.total
  } catch (e) {
    ElMessage.error('获取账本列表失败')
  } finally {
    loading.value = false
  }
}

// Handlers
const handleSearch = () => {
  pagination.page = 1
  fetchBooks()
}

const handleReset = () => {
  filters.user_id = ''
  filters.type = ''
  handleSearch()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchBooks()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchBooks()
}

const handleView = async (book: Book) => {
  try {
    const detail = await dataApi.getBookDetail(book.id)
    currentBook.value = detail
    detailVisible.value = true
  } catch (e) {
    ElMessage.error('获取账本详情失败')
  }
}

const viewTransactions = (book: Book) => {
  router.push(`/data/transactions?book_id=${book.id}`)
}

// Formatters
const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

const formatMoney = (amount: number) => {
  return amount.toFixed(2)
}

const getBookTypeTag = (type: string) => {
  const map: Record<string, string> = {
    personal: '',
    family: 'warning',
    business: 'danger',
  }
  return map[type] || ''
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
  fetchBooks()
})
</script>

<style scoped lang="scss">
.book-list {
  h4 {
    margin-bottom: 10px;
    color: #333;
  }
}
</style>
