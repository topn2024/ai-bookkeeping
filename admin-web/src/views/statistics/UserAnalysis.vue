<template>
  <div class="user-analysis">
    <div class="page-header">
      <h2 class="page-title">用户分析</h2>
      <el-radio-group v-model="period" @change="fetchData">
        <el-radio-button label="7">近7天</el-radio-button>
        <el-radio-button label="30">近30天</el-radio-button>
        <el-radio-button label="90">近90天</el-radio-button>
      </el-radio-group>
    </div>

    <!-- Key Metrics -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="metric-card">
            <div class="metric-icon" style="background: #e6f7ff; color: #1890ff;">
              <el-icon :size="24"><User /></el-icon>
            </div>
            <div class="metric-info">
              <div class="metric-value">{{ formatNumber(metrics.total_users) }}</div>
              <div class="metric-label">总用户数</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="metric-card">
            <div class="metric-icon" style="background: #f6ffed; color: #52c41a;">
              <el-icon :size="24"><UserFilled /></el-icon>
            </div>
            <div class="metric-info">
              <div class="metric-value">{{ formatNumber(metrics.new_users) }}</div>
              <div class="metric-label">新增用户</div>
              <div class="metric-trend" :class="metrics.new_users_change >= 0 ? 'up' : 'down'">
                {{ metrics.new_users_change >= 0 ? '+' : '' }}{{ metrics.new_users_change?.toFixed(1) }}%
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="metric-card">
            <div class="metric-icon" style="background: #fff7e6; color: #fa8c16;">
              <el-icon :size="24"><TrendCharts /></el-icon>
            </div>
            <div class="metric-info">
              <div class="metric-value">{{ (metrics.retention_rate * 100).toFixed(1) }}%</div>
              <div class="metric-label">留存率</div>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="metric-card">
            <div class="metric-icon" style="background: #fff1f0; color: #ff4d4f;">
              <el-icon :size="24"><Warning /></el-icon>
            </div>
            <div class="metric-info">
              <div class="metric-value">{{ (metrics.churn_rate * 100).toFixed(1) }}%</div>
              <div class="metric-label">流失率</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Charts -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="16">
        <el-card>
          <template #header>用户增长趋势</template>
          <div ref="growthChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card>
          <template #header>用户来源分布</template>
          <div ref="sourceChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="mb-20">
      <el-col :span="12">
        <el-card>
          <template #header>留存率分析</template>
          <div ref="retentionChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>用户活跃度分布</template>
          <div ref="activityChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Cohort Analysis -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>留存队列分析</span>
          <el-button type="primary" text @click="exportCohort">导出报表</el-button>
        </div>
      </template>
      <el-table :data="cohortData" size="small" stripe>
        <el-table-column prop="cohort" label="注册日期" width="120" fixed />
        <el-table-column prop="users" label="用户数" width="100" />
        <el-table-column v-for="i in 7" :key="i" :label="`第${i}天`" width="80">
          <template #default="{ row }">
            <span :style="{ color: getRetentionColor(row[`day${i}`]) }">
              {{ row[`day${i}`] ? (row[`day${i}`] * 100).toFixed(0) + '%' : '-' }}
            </span>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import * as statisticsApi from '@/api/statistics'

// Refs
const growthChart = ref<HTMLElement>()
const sourceChart = ref<HTMLElement>()
const retentionChart = ref<HTMLElement>()
const activityChart = ref<HTMLElement>()

// State
const period = ref('30')
const metrics = reactive({
  total_users: 0,
  new_users: 0,
  new_users_change: 0,
  retention_rate: 0,
  churn_rate: 0,
})
const cohortData = ref<any[]>([])

// Chart instances
let growthChartInstance: echarts.ECharts | null = null
let sourceChartInstance: echarts.ECharts | null = null
let retentionChartInstance: echarts.ECharts | null = null
let activityChartInstance: echarts.ECharts | null = null

// Fetch data
const fetchData = async () => {
  try {
    const [metricsData, retention, cohort] = await Promise.all([
      statisticsApi.getUserStats(Number(period.value)),
      statisticsApi.getRetentionAnalysis(Number(period.value)),
      statisticsApi.getCohortAnalysis(),
    ])

    Object.assign(metrics, metricsData)
    cohortData.value = cohort.cohorts || []

    renderGrowthChart(metricsData.growth_trend || [])
    renderSourceChart(metricsData.source_distribution || [])
    renderRetentionChart(retention.retention_curve || [])
    renderActivityChart(metricsData.activity_distribution || [])
  } catch (e) {
    ElMessage.error('获取用户分析数据失败')
  }
}

// Render charts
const renderGrowthChart = (data: any[]) => {
  if (!growthChart.value) return

  if (!growthChartInstance) {
    growthChartInstance = echarts.init(growthChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['新增用户', '活跃用户', '累计用户'], bottom: 0 },
    grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.date) },
    yAxis: [
      { type: 'value', name: '用户数' },
      { type: 'value', name: '累计', position: 'right' },
    ],
    series: [
      { name: '新增用户', type: 'bar', data: data.map(d => d.new_users), itemStyle: { color: '#1890ff' } },
      { name: '活跃用户', type: 'bar', data: data.map(d => d.active_users), itemStyle: { color: '#52c41a' } },
      { name: '累计用户', type: 'line', yAxisIndex: 1, smooth: true, data: data.map(d => d.total_users), itemStyle: { color: '#722ed1' } },
    ],
  }

  growthChartInstance.setOption(option)
}

const renderSourceChart = (data: any[]) => {
  if (!sourceChart.value) return

  if (!sourceChartInstance) {
    sourceChartInstance = echarts.init(sourceChart.value)
  }

  const option = {
    tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
    legend: { orient: 'vertical', right: 10, top: 'center' },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      center: ['40%', '50%'],
      avoidLabelOverlap: false,
      itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      emphasis: { label: { show: true, fontWeight: 'bold' } },
      data: data.map(d => ({ value: d.count, name: d.source })),
    }],
  }

  sourceChartInstance.setOption(option)
}

const renderRetentionChart = (data: any[]) => {
  if (!retentionChart.value) return

  if (!retentionChartInstance) {
    retentionChartInstance = echarts.init(retentionChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis', formatter: '{b}: {c}%' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map((_, i) => `第${i + 1}天`) },
    yAxis: { type: 'value', max: 100, axisLabel: { formatter: '{value}%' } },
    series: [{
      type: 'line',
      smooth: true,
      areaStyle: { opacity: 0.3 },
      data: data.map(d => (d * 100).toFixed(1)),
      itemStyle: { color: '#fa8c16' },
      markLine: {
        data: [{ type: 'average', name: '平均值' }],
        label: { formatter: '{c}%' },
      },
    }],
  }

  retentionChartInstance.setOption(option)
}

const renderActivityChart = (data: any[]) => {
  if (!activityChart.value) return

  if (!activityChartInstance) {
    activityChartInstance = echarts.init(activityChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.level) },
    yAxis: { type: 'value' },
    series: [{
      type: 'bar',
      data: data.map(d => ({
        value: d.count,
        itemStyle: { color: getActivityColor(d.level) },
      })),
      barWidth: '60%',
    }],
  }

  activityChartInstance.setOption(option)
}

// Helpers
const formatNumber = (num: number) => {
  if (!num) return 0
  if (num >= 10000) return (num / 10000).toFixed(1) + 'w'
  return num.toLocaleString()
}

const getRetentionColor = (rate: number) => {
  if (!rate) return '#999'
  if (rate >= 0.5) return '#52c41a'
  if (rate >= 0.3) return '#fa8c16'
  return '#ff4d4f'
}

const getActivityColor = (level: string) => {
  const colors: Record<string, string> = {
    '高活跃': '#52c41a',
    '中活跃': '#1890ff',
    '低活跃': '#fa8c16',
    '沉默': '#ff4d4f',
  }
  return colors[level] || '#999'
}

const exportCohort = async () => {
  try {
    const blob = await statisticsApi.exportCohortReport()
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `cohort_analysis_${new Date().toISOString().split('T')[0]}.xlsx`
    link.click()
    window.URL.revokeObjectURL(url)
    ElMessage.success('导出成功')
  } catch (e) {
    ElMessage.error('导出失败')
  }
}

// Resize
const handleResize = () => {
  growthChartInstance?.resize()
  sourceChartInstance?.resize()
  retentionChartInstance?.resize()
  activityChartInstance?.resize()
}

// Lifecycle
onMounted(() => {
  fetchData()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  growthChartInstance?.dispose()
  sourceChartInstance?.dispose()
  retentionChartInstance?.dispose()
  activityChartInstance?.dispose()
})
</script>

<style scoped lang="scss">
.user-analysis {
  .metric-card {
    display: flex;
    align-items: center;

    .metric-icon {
      width: 56px;
      height: 56px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 16px;
    }

    .metric-info {
      .metric-value {
        font-size: 24px;
        font-weight: 600;
        color: #333;
      }

      .metric-label {
        font-size: 14px;
        color: #999;
        margin-top: 4px;
      }

      .metric-trend {
        font-size: 12px;
        margin-top: 4px;

        &.up {
          color: #52c41a;
        }

        &.down {
          color: #ff4d4f;
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
}
</style>
