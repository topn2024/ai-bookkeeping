<template>
  <div class="dashboard">
    <!-- Stats Cards -->
    <div class="card-grid">
      <el-card v-for="stat in statsCards" :key="stat.key" class="stats-card" shadow="hover">
        <div class="stats-content">
          <div class="stats-icon" :style="{ backgroundColor: stat.color + '20', color: stat.color }">
            <el-icon :size="24"><component :is="stat.icon" /></el-icon>
          </div>
          <div class="stats-info">
            <div class="stats-value">{{ getStatValue(stat.key) }}</div>
            <div class="stats-label">{{ getStatLabel(stat.key) }}</div>
            <div v-if="getStatChange(stat.key) !== null" class="stats-trend" :class="getStatChangeType(stat.key)">
              <el-icon><CaretTop v-if="getStatChange(stat.key) >= 0" /><CaretBottom v-else /></el-icon>
              {{ Math.abs(getStatChange(stat.key) || 0).toFixed(1) }}%
            </div>
          </div>
        </div>
      </el-card>
    </div>

    <!-- Charts Row -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="16">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>用户增长趋势</span>
              <el-radio-group v-model="trendPeriod" size="small" @change="fetchTrends">
                <el-radio-button label="7">7天</el-radio-button>
                <el-radio-button label="30">30天</el-radio-button>
                <el-radio-button label="90">90天</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div ref="userTrendChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card>
          <template #header>
            <span>交易类型分布</span>
          </template>
          <div ref="transactionPieChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Activity Heatmap -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="24">
        <el-card>
          <template #header>
            <span>用户活跃热力图</span>
          </template>
          <div ref="heatmapChart" class="chart-container" style="height: 200px;"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Recent Users & Transactions -->
    <el-row :gutter="20">
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>最近注册用户</span>
              <el-button type="primary" text @click="$router.push('/users')">查看全部</el-button>
            </div>
          </template>
          <el-table :data="recentUsers" size="small" stripe>
            <el-table-column prop="display_name" label="用户" width="150">
              <template #default="{ row }">
                <div class="user-cell">
                  <el-avatar :size="32" :src="row.avatar_url">
                    {{ row.display_name?.charAt(0) || '?' }}
                  </el-avatar>
                  <span>{{ row.display_name || '未设置' }}</span>
                </div>
              </template>
            </el-table-column>
            <el-table-column prop="email_masked" label="邮箱" width="130" />
            <el-table-column prop="created_at" label="注册时间">
              <template #default="{ row }">
                {{ formatDate(row.created_at) }}
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>最近交易记录</span>
              <el-button type="primary" text @click="$router.push('/data/transactions')">查看全部</el-button>
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
            <el-table-column prop="amount" label="金额" width="100">
              <template #default="{ row }">
                <span :class="row.type === 'income' ? 'text-success' : 'text-danger'">
                  {{ row.type === 'income' ? '+' : '-' }}{{ formatMoney(row.amount) }}
                </span>
              </template>
            </el-table-column>
            <el-table-column prop="category_name" label="分类" />
            <el-table-column prop="created_at" label="时间">
              <template #default="{ row }">
                {{ formatDate(row.created_at) }}
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import * as dashboardApi from '@/api/dashboard'
import { formatNumber, formatMoney, formatShortDate } from '@/utils'
import type { DashboardStats } from '@/types'

// Refs
const userTrendChart = ref<HTMLElement>()
const transactionPieChart = ref<HTMLElement>()
const heatmapChart = ref<HTMLElement>()

// State
const stats = reactive<DashboardStats>({} as DashboardStats)
const trendPeriod = ref('7')
const recentUsers = ref<any[]>([])
const recentTransactions = ref<any[]>([])

// Chart instances
let userTrendChartInstance: echarts.ECharts | null = null
let transactionPieChartInstance: echarts.ECharts | null = null
let heatmapChartInstance: echarts.ECharts | null = null

// Stats cards config - 匹配后端 DashboardStatsResponse 结构
const statsCards = [
  { key: 'today_new_users', label: '今日新增', icon: 'User', color: '#1890ff', isStatCard: true },
  { key: 'today_active_users', label: '今日活跃', icon: 'UserFilled', color: '#52c41a', isStatCard: true },
  { key: 'today_transactions', label: '今日交易', icon: 'Tickets', color: '#722ed1', isStatCard: true },
  { key: 'today_amount', label: '今日金额', icon: 'Timer', color: '#fa8c16', isStatCard: true },
]

// Formatters - use shared utilities
const formatDate = formatShortDate

// 获取 StatCard 数据的辅助函数
const getStatValue = (key: string) => {
  const statCard = (stats as any)[key]
  if (statCard && typeof statCard === 'object' && 'value' in statCard) {
    return statCard.value
  }
  return statCard || 0
}

const getStatLabel = (key: string) => {
  const statCard = (stats as any)[key]
  if (statCard && typeof statCard === 'object' && 'label' in statCard) {
    return statCard.label
  }
  return ''
}

const getStatChange = (key: string): number | null => {
  const statCard = (stats as any)[key]
  if (statCard && typeof statCard === 'object' && 'change' in statCard) {
    return statCard.change
  }
  return null
}

const getStatChangeType = (key: string) => {
  const statCard = (stats as any)[key]
  if (statCard && typeof statCard === 'object' && 'change_type' in statCard) {
    return statCard.change_type === 'up' ? 'up' : 'down'
  }
  return 'flat'
}

const getTrendClass = (value: number) => {
  return value >= 0 ? 'up' : 'down'
}

// Fetch data
const fetchStats = async () => {
  try {
    const data = await dashboardApi.getDashboardStats()
    Object.assign(stats, data)
  } catch (e) {
    console.error('Failed to fetch stats:', e)
  }
}

const fetchTrends = async () => {
  try {
    // 使用 period 格式 (7d, 30d, 90d)
    const period = `${trendPeriod.value}d`
    const data = await dashboardApi.getUserTrend(period)
    renderUserTrendChart(data)
  } catch (e) {
    console.error('Failed to fetch trends:', e)
  }
}

const fetchRecentData = async () => {
  try {
    const data = await dashboardApi.getRecentActivity()
    recentUsers.value = data.recent_users || []
    recentTransactions.value = data.recent_transactions || []
  } catch (e) {
    console.error('Failed to fetch recent data:', e)
  }
}

const fetchHeatmap = async () => {
  try {
    const data = await dashboardApi.getActivityHeatmap()
    renderHeatmapChart(data)
  } catch (e) {
    console.error('Failed to fetch heatmap:', e)
  }
}

// Render charts
const renderUserTrendChart = (data: any) => {
  if (!userTrendChart.value) return

  if (!userTrendChartInstance) {
    userTrendChartInstance = echarts.init(userTrendChart.value)
  }

  // 适配后端返回的数据格式
  // 后端返回: { new_users: { label, data: [{date, value}] }, active_users: {...}, period }
  const newUsersData = data.new_users?.data || []
  const activeUsersData = data.active_users?.data || []

  // 提取日期和值
  const dates = newUsersData.map((item: any) => item.date)
  const newUsersValues = newUsersData.map((item: any) => item.value)
  const activeUsersValues = activeUsersData.map((item: any) => item.value)

  const option = {
    tooltip: {
      trigger: 'axis',
    },
    legend: {
      data: ['新增用户', '活跃用户'],
      bottom: 0,
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '15%',
      top: '10%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: dates,
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '新增用户',
        type: 'line',
        smooth: true,
        areaStyle: { opacity: 0.3 },
        data: newUsersValues,
        itemStyle: { color: '#1890ff' },
      },
      {
        name: '活跃用户',
        type: 'line',
        smooth: true,
        areaStyle: { opacity: 0.3 },
        data: activeUsersValues,
        itemStyle: { color: '#52c41a' },
      },
    ],
  }

  userTrendChartInstance.setOption(option)
}

const renderTransactionPieChart = () => {
  if (!transactionPieChart.value) return

  if (!transactionPieChartInstance) {
    transactionPieChartInstance = echarts.init(transactionPieChart.value)
  }

  const option = {
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: 10,
      top: 'center',
    },
    series: [
      {
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['40%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 10,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: false,
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
        },
        data: [
          { value: stats.income_count || 0, name: '收入', itemStyle: { color: '#52c41a' } },
          { value: stats.expense_count || 0, name: '支出', itemStyle: { color: '#ff4d4f' } },
        ],
      },
    ],
  }

  transactionPieChartInstance.setOption(option)
}

const renderHeatmapChart = (data: any) => {
  if (!heatmapChart.value) return

  if (!heatmapChartInstance) {
    heatmapChartInstance = echarts.init(heatmapChart.value)
  }

  const hours = Array.from({ length: 24 }, (_, i) => `${i}:00`)
  const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']

  // 将后端返回的 7x24 矩阵转换为 echarts 需要的格式
  // 后端: heatmap_matrix[day][hour] = count
  // echarts: [[hour, day, value], ...]
  const heatmapData: [number, number, number][] = []
  const matrix = data.heatmap_matrix || []

  for (let day = 0; day < 7; day++) {
    for (let hour = 0; hour < 24; hour++) {
      const value = matrix[day]?.[hour] || 0
      heatmapData.push([hour, day, value])
    }
  }

  const maxValue = data.max_value || Math.max(...heatmapData.map(d => d[2]), 1)

  const option = {
    tooltip: {
      position: 'top',
      formatter: (params: any) => {
        return `${days[params.value[1]]} ${hours[params.value[0]]}<br/>交易数: ${params.value[2]}`
      },
    },
    grid: {
      height: '70%',
      top: '10%',
      left: '10%',
      right: '10%',
    },
    xAxis: {
      type: 'category',
      data: hours,
      splitArea: { show: true },
    },
    yAxis: {
      type: 'category',
      data: days,
      splitArea: { show: true },
    },
    visualMap: {
      min: 0,
      max: maxValue,
      calculable: true,
      orient: 'horizontal',
      left: 'center',
      bottom: 0,
      inRange: {
        color: ['#f0f9eb', '#67c23a'],
      },
    },
    series: [
      {
        type: 'heatmap',
        data: heatmapData,
        label: { show: false },
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
      },
    ],
  }

  heatmapChartInstance.setOption(option)
}

// Handle resize
const handleResize = () => {
  userTrendChartInstance?.resize()
  transactionPieChartInstance?.resize()
  heatmapChartInstance?.resize()
}

// Lifecycle
onMounted(async () => {
  await Promise.all([fetchStats(), fetchTrends(), fetchRecentData(), fetchHeatmap()])
  renderTransactionPieChart()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  userTrendChartInstance?.dispose()
  transactionPieChartInstance?.dispose()
  heatmapChartInstance?.dispose()
})
</script>

<style scoped lang="scss">
.dashboard {
  .stats-card {
    .stats-content {
      display: flex;
      align-items: center;

      .stats-icon {
        width: 56px;
        height: 56px;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-right: 16px;
      }

      .stats-info {
        flex: 1;

        .stats-value {
          font-size: 28px;
          font-weight: 600;
          color: #333;
          line-height: 1.2;
        }

        .stats-label {
          font-size: 14px;
          color: #999;
          margin-top: 4px;
        }

        .stats-trend {
          display: flex;
          align-items: center;
          font-size: 12px;
          margin-top: 8px;

          &.up {
            color: #52c41a;
          }

          &.down {
            color: #ff4d4f;
          }

          .el-icon {
            margin-right: 2px;
          }
        }
      }
    }
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .chart-container {
    width: 100%;
    height: 300px;
  }

  .user-cell {
    display: flex;
    align-items: center;

    .el-avatar {
      margin-right: 8px;
    }
  }
}
</style>
