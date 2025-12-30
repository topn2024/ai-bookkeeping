<template>
  <div class="transaction-analysis">
    <div class="page-header">
      <h2 class="page-title">交易分析</h2>
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
          <el-statistic title="交易总额" :value="metrics.total_amount" :precision="2" prefix="¥" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总收入" :value="metrics.total_income" :precision="2" prefix="¥" value-style="color: #52c41a" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="总支出" :value="metrics.total_expense" :precision="2" prefix="¥" value-style="color: #ff4d4f" />
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <el-statistic title="交易笔数" :value="metrics.transaction_count" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Charts Row 1 -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="16">
        <el-card>
          <template #header>交易趋势</template>
          <div ref="trendChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card>
          <template #header>收支比例</template>
          <div ref="ratioChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Charts Row 2 -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="12">
        <el-card>
          <template #header>支出分类TOP10</template>
          <div ref="expenseCategoryChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>收入分类TOP10</template>
          <div ref="incomeCategoryChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Charts Row 3 -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="12">
        <el-card>
          <template #header>金额分布</template>
          <div ref="amountDistChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>交易时段分布</template>
          <div ref="timeDistChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Top Users -->
    <el-card>
      <template #header>交易活跃用户TOP20</template>
      <el-table :data="topUsers" size="small" stripe>
        <el-table-column type="index" label="排名" width="80" />
        <el-table-column prop="user_id" label="用户ID" width="100" />
        <el-table-column prop="nickname" label="昵称" />
        <el-table-column prop="transaction_count" label="交易笔数" width="120" />
        <el-table-column prop="total_income" label="总收入" width="150">
          <template #default="{ row }">
            <span class="text-success">¥{{ formatMoney(row.total_income) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="total_expense" label="总支出" width="150">
          <template #default="{ row }">
            <span class="text-danger">¥{{ formatMoney(row.total_expense) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="avg_amount" label="平均金额" width="120">
          <template #default="{ row }">
            ¥{{ formatMoney(row.avg_amount) }}
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
const trendChart = ref<HTMLElement>()
const ratioChart = ref<HTMLElement>()
const expenseCategoryChart = ref<HTMLElement>()
const incomeCategoryChart = ref<HTMLElement>()
const amountDistChart = ref<HTMLElement>()
const timeDistChart = ref<HTMLElement>()

// State
const period = ref('30')
const metrics = reactive({
  total_amount: 0,
  total_income: 0,
  total_expense: 0,
  transaction_count: 0,
})
const topUsers = ref<any[]>([])

// Chart instances
let trendChartInstance: echarts.ECharts | null = null
let ratioChartInstance: echarts.ECharts | null = null
let expenseCategoryChartInstance: echarts.ECharts | null = null
let incomeCategoryChartInstance: echarts.ECharts | null = null
let amountDistChartInstance: echarts.ECharts | null = null
let timeDistChartInstance: echarts.ECharts | null = null

// Fetch data
const fetchData = async () => {
  try {
    const data = await statisticsApi.getTransactionStats(Number(period.value))

    Object.assign(metrics, data.metrics)
    topUsers.value = data.top_users || []

    renderTrendChart(data.trend || [])
    renderRatioChart(data.metrics)
    renderExpenseCategoryChart(data.expense_categories || [])
    renderIncomeCategoryChart(data.income_categories || [])
    renderAmountDistChart(data.amount_distribution || [])
    renderTimeDistChart(data.time_distribution || [])
  } catch (e) {
    ElMessage.error('获取交易分析数据失败')
  }
}

// Render charts
const renderTrendChart = (data: any[]) => {
  if (!trendChart.value) return

  if (!trendChartInstance) {
    trendChartInstance = echarts.init(trendChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['收入', '支出', '净额'], bottom: 0 },
    grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.date) },
    yAxis: { type: 'value' },
    series: [
      { name: '收入', type: 'bar', stack: 'total', data: data.map(d => d.income), itemStyle: { color: '#52c41a' } },
      { name: '支出', type: 'bar', stack: 'total', data: data.map(d => -d.expense), itemStyle: { color: '#ff4d4f' } },
      { name: '净额', type: 'line', smooth: true, data: data.map(d => d.net), itemStyle: { color: '#1890ff' } },
    ],
  }

  trendChartInstance.setOption(option)
}

const renderRatioChart = (data: any) => {
  if (!ratioChart.value) return

  if (!ratioChartInstance) {
    ratioChartInstance = echarts.init(ratioChart.value)
  }

  const option = {
    tooltip: { trigger: 'item', formatter: '{b}: ¥{c} ({d}%)' },
    series: [{
      type: 'pie',
      radius: ['50%', '70%'],
      avoidLabelOverlap: false,
      itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 },
      label: { show: true, position: 'center', formatter: () => `净额\n¥${formatMoney(data.total_income - data.total_expense)}` },
      emphasis: { label: { show: true, fontSize: 14, fontWeight: 'bold' } },
      data: [
        { value: data.total_income, name: '收入', itemStyle: { color: '#52c41a' } },
        { value: data.total_expense, name: '支出', itemStyle: { color: '#ff4d4f' } },
      ],
    }],
  }

  ratioChartInstance.setOption(option)
}

const renderExpenseCategoryChart = (data: any[]) => {
  if (!expenseCategoryChart.value) return

  if (!expenseCategoryChartInstance) {
    expenseCategoryChartInstance = echarts.init(expenseCategoryChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '3%', right: '15%', bottom: '3%', top: '3%', containLabel: true },
    xAxis: { type: 'value' },
    yAxis: { type: 'category', data: data.map(d => d.category).reverse() },
    series: [{
      type: 'bar',
      data: data.map(d => d.amount).reverse(),
      itemStyle: { color: '#ff4d4f' },
      label: { show: true, position: 'right', formatter: (p: any) => '¥' + formatMoney(p.value) },
    }],
  }

  expenseCategoryChartInstance.setOption(option)
}

const renderIncomeCategoryChart = (data: any[]) => {
  if (!incomeCategoryChart.value) return

  if (!incomeCategoryChartInstance) {
    incomeCategoryChartInstance = echarts.init(incomeCategoryChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '3%', right: '15%', bottom: '3%', top: '3%', containLabel: true },
    xAxis: { type: 'value' },
    yAxis: { type: 'category', data: data.map(d => d.category).reverse() },
    series: [{
      type: 'bar',
      data: data.map(d => d.amount).reverse(),
      itemStyle: { color: '#52c41a' },
      label: { show: true, position: 'right', formatter: (p: any) => '¥' + formatMoney(p.value) },
    }],
  }

  incomeCategoryChartInstance.setOption(option)
}

const renderAmountDistChart = (data: any[]) => {
  if (!amountDistChart.value) return

  if (!amountDistChartInstance) {
    amountDistChartInstance = echarts.init(amountDistChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.range) },
    yAxis: { type: 'value' },
    series: [{
      type: 'bar',
      data: data.map(d => d.count),
      itemStyle: {
        color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: '#1890ff' },
          { offset: 1, color: '#69c0ff' },
        ]),
      },
    }],
  }

  amountDistChartInstance.setOption(option)
}

const renderTimeDistChart = (data: any[]) => {
  if (!timeDistChart.value) return

  if (!timeDistChartInstance) {
    timeDistChartInstance = echarts.init(timeDistChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.hour + ':00') },
    yAxis: { type: 'value' },
    series: [{
      type: 'line',
      smooth: true,
      areaStyle: { opacity: 0.3 },
      data: data.map(d => d.count),
      itemStyle: { color: '#722ed1' },
    }],
  }

  timeDistChartInstance.setOption(option)
}

// Helpers
const formatMoney = (amount: number) => {
  return amount.toFixed(2)
}

// Resize
const handleResize = () => {
  trendChartInstance?.resize()
  ratioChartInstance?.resize()
  expenseCategoryChartInstance?.resize()
  incomeCategoryChartInstance?.resize()
  amountDistChartInstance?.resize()
  timeDistChartInstance?.resize()
}

// Lifecycle
onMounted(() => {
  fetchData()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  trendChartInstance?.dispose()
  ratioChartInstance?.dispose()
  expenseCategoryChartInstance?.dispose()
  incomeCategoryChartInstance?.dispose()
  amountDistChartInstance?.dispose()
  timeDistChartInstance?.dispose()
})
</script>

<style scoped lang="scss">
.transaction-analysis {
  .chart-container {
    width: 100%;
    height: 300px;
  }
}
</style>
