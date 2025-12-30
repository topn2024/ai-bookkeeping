<template>
  <div class="category-list">
    <div class="page-header">
      <h2 class="page-title">分类管理</h2>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="类型">
          <el-select v-model="filters.type" placeholder="全部" clearable style="width: 120px;">
            <el-option label="收入" value="income" />
            <el-option label="支出" value="expense" />
          </el-select>
        </el-form-item>
        <el-form-item label="级别">
          <el-select v-model="filters.level" placeholder="全部" clearable style="width: 120px;">
            <el-option label="一级分类" :value="1" />
            <el-option label="二级分类" :value="2" />
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

    <!-- Category Stats -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总分类数" :value="stats.total_count" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="收入分类" :value="stats.income_count" value-style="color: #52c41a" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="支出分类" :value="stats.expense_count" value-style="color: #ff4d4f" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="自定义分类" :value="stats.custom_count" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Category Table -->
    <div class="table-container">
      <el-table
        v-loading="loading"
        :data="categories"
        stripe
        row-key="id"
        :tree-props="{ children: 'children' }"
      >
        <el-table-column prop="name" label="分类名称" min-width="200">
          <template #default="{ row }">
            <span class="category-name">
              <span v-if="row.icon" class="category-icon">{{ row.icon }}</span>
              {{ row.name }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="type" label="类型" width="100">
          <template #default="{ row }">
            <el-tag :type="row.type === 'income' ? 'success' : 'danger'" size="small">
              {{ row.type === 'income' ? '收入' : '支出' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="level" label="级别" width="100">
          <template #default="{ row }">
            <el-tag :type="row.level === 1 ? 'primary' : 'info'" size="small">
              {{ row.level === 1 ? '一级' : '二级' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="is_system" label="系统分类" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.is_system" type="warning" size="small">系统</el-tag>
            <span v-else>自定义</span>
          </template>
        </el-table-column>
        <el-table-column prop="usage_count" label="使用次数" width="120" />
        <el-table-column prop="sort_order" label="排序" width="80" />
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
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Detail Dialog -->
    <el-dialog v-model="detailVisible" title="分类详情" width="500px">
      <el-descriptions v-if="currentCategory" :column="1" border>
        <el-descriptions-item label="ID">{{ currentCategory.id }}</el-descriptions-item>
        <el-descriptions-item label="名称">
          <span class="category-name">
            <span v-if="currentCategory.icon" class="category-icon">{{ currentCategory.icon }}</span>
            {{ currentCategory.name }}
          </span>
        </el-descriptions-item>
        <el-descriptions-item label="类型">
          <el-tag :type="currentCategory.type === 'income' ? 'success' : 'danger'">
            {{ currentCategory.type === 'income' ? '收入' : '支出' }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="级别">{{ currentCategory.level === 1 ? '一级分类' : '二级分类' }}</el-descriptions-item>
        <el-descriptions-item label="父分类">{{ currentCategory.parent_name || '-' }}</el-descriptions-item>
        <el-descriptions-item label="系统分类">{{ currentCategory.is_system ? '是' : '否' }}</el-descriptions-item>
        <el-descriptions-item label="使用次数">{{ currentCategory.usage_count }}</el-descriptions-item>
        <el-descriptions-item label="排序">{{ currentCategory.sort_order }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">{{ formatDateTime(currentCategory.created_at) }}</el-descriptions-item>
      </el-descriptions>

      <!-- Usage Chart -->
      <div class="mt-20">
        <h4>使用趋势（近30天）</h4>
        <div ref="usageChart" class="chart-container" style="height: 200px;"></div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import * as dataApi from '@/api/data'
import type { Category } from '@/types'

// State
const loading = ref(false)
const categories = ref<Category[]>([])
const stats = reactive({
  total_count: 0,
  income_count: 0,
  expense_count: 0,
  custom_count: 0,
})
const filters = reactive({
  type: '',
  level: undefined as number | undefined,
})
const pagination = reactive({
  page: 1,
  pageSize: 50,
  total: 0,
})
const detailVisible = ref(false)
const currentCategory = ref<Category | null>(null)
const usageChart = ref<HTMLElement>()
let usageChartInstance: echarts.ECharts | null = null

// Fetch data
const fetchCategories = async () => {
  loading.value = true
  try {
    const params: any = {
      page: pagination.page,
      page_size: pagination.pageSize,
    }
    if (filters.type) params.type = filters.type
    if (filters.level !== undefined) params.level = filters.level

    const response = await dataApi.getCategories(params)
    categories.value = response.items
    pagination.total = response.total

    if (response.stats) {
      Object.assign(stats, response.stats)
    }
  } catch (e) {
    ElMessage.error('获取分类列表失败')
  } finally {
    loading.value = false
  }
}

// Handlers
const handleSearch = () => {
  pagination.page = 1
  fetchCategories()
}

const handleReset = () => {
  filters.type = ''
  filters.level = undefined
  handleSearch()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchCategories()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchCategories()
}

const handleView = async (category: Category) => {
  try {
    const detail = await dataApi.getCategoryDetail(category.id)
    currentCategory.value = detail
    detailVisible.value = true

    // Render usage chart after dialog opens
    await nextTick()
    renderUsageChart(detail.usage_trend || [])
  } catch (e) {
    ElMessage.error('获取分类详情失败')
  }
}

const renderUsageChart = (data: any[]) => {
  if (!usageChart.value) return

  if (!usageChartInstance) {
    usageChartInstance = echarts.init(usageChart.value)
  }

  const option = {
    tooltip: {
      trigger: 'axis',
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: data.map(d => d.date),
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        type: 'line',
        smooth: true,
        areaStyle: { opacity: 0.3 },
        data: data.map(d => d.count),
        itemStyle: { color: '#1890ff' },
      },
    ],
  }

  usageChartInstance.setOption(option)
}

// Formatters
const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Init
onMounted(() => {
  fetchCategories()
})
</script>

<style scoped lang="scss">
.category-list {
  .category-name {
    display: inline-flex;
    align-items: center;

    .category-icon {
      margin-right: 8px;
      font-size: 18px;
    }
  }

  h4 {
    margin-bottom: 10px;
    color: #333;
  }
}
</style>
