<template>
  <div class="system-resources">
    <div class="page-header">
      <h2 class="page-title">系统资源</h2>
      <el-button @click="fetchResources">
        <el-icon><Refresh /></el-icon>刷新
      </el-button>
    </div>

    <!-- Resource Gauges -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="resource-gauge">
            <el-progress
              type="dashboard"
              :percentage="resources.cpu_usage"
              :color="getProgressColor(resources.cpu_usage)"
              :width="120"
            />
            <div class="gauge-label">CPU使用率</div>
            <div class="gauge-detail">{{ resources.cpu_cores }} 核心</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="resource-gauge">
            <el-progress
              type="dashboard"
              :percentage="resources.memory_usage"
              :color="getProgressColor(resources.memory_usage)"
              :width="120"
            />
            <div class="gauge-label">内存使用率</div>
            <div class="gauge-detail">{{ formatBytes(resources.memory_used) }} / {{ formatBytes(resources.memory_total) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="resource-gauge">
            <el-progress
              type="dashboard"
              :percentage="resources.disk_usage"
              :color="getProgressColor(resources.disk_usage)"
              :width="120"
            />
            <div class="gauge-label">磁盘使用率</div>
            <div class="gauge-detail">{{ formatBytes(resources.disk_used) }} / {{ formatBytes(resources.disk_total) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover">
          <div class="resource-gauge">
            <el-progress
              type="dashboard"
              :percentage="resources.network_usage || 0"
              :color="getProgressColor(resources.network_usage || 0)"
              :width="120"
            />
            <div class="gauge-label">网络使用率</div>
            <div class="gauge-detail">{{ formatSpeed(resources.network_in) }} / {{ formatSpeed(resources.network_out) }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Charts -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>CPU & 内存趋势</span>
              <el-radio-group v-model="trendPeriod" size="small" @change="fetchTrends">
                <el-radio-button label="1h">1小时</el-radio-button>
                <el-radio-button label="6h">6小时</el-radio-button>
                <el-radio-button label="24h">24小时</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div ref="cpuMemoryChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>网络流量</template>
          <div ref="networkChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Process List -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>进程列表</span>
          <el-input
            v-model="processSearch"
            placeholder="搜索进程"
            clearable
            class="process-search"
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
        </div>
      </template>
      <el-table :data="filteredProcesses" size="small" stripe max-height="400">
        <el-table-column prop="pid" label="PID" width="80" />
        <el-table-column prop="name" label="进程名" min-width="150" />
        <el-table-column prop="cpu" label="CPU%" width="100" sortable>
          <template #default="{ row }">
            <span :class="{ 'text-danger': row.cpu > 80 }">{{ row.cpu.toFixed(1) }}%</span>
          </template>
        </el-table-column>
        <el-table-column prop="memory" label="内存%" width="100" sortable>
          <template #default="{ row }">
            <span :class="{ 'text-danger': row.memory > 80 }">{{ row.memory.toFixed(1) }}%</span>
          </template>
        </el-table-column>
        <el-table-column prop="memory_bytes" label="内存使用" width="120">
          <template #default="{ row }">
            {{ formatBytes(row.memory_bytes) }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 'running' ? 'success' : 'warning'" size="small">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="uptime" label="运行时间" width="120">
          <template #default="{ row }">
            {{ formatUptime(row.uptime) }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- Database Stats -->
    <el-card class="mt-20">
      <template #header>数据库状态</template>
      <el-row :gutter="20">
        <el-col :span="6">
          <el-statistic title="活动连接数" :value="dbStats.active_connections" />
        </el-col>
        <el-col :span="6">
          <el-statistic title="查询总数" :value="dbStats.total_queries" />
        </el-col>
        <el-col :span="6">
          <el-statistic title="慢查询数" :value="dbStats.slow_queries" />
        </el-col>
        <el-col :span="6">
          <el-statistic title="数据库大小" :value="formatBytes(dbStats.database_size)" />
        </el-col>
      </el-row>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import * as monitorApi from '@/api/monitor'

// Refs
const cpuMemoryChart = ref<HTMLElement>()
const networkChart = ref<HTMLElement>()

// State
const resources = reactive({
  cpu_usage: 0,
  cpu_cores: 0,
  memory_usage: 0,
  memory_used: 0,
  memory_total: 0,
  disk_usage: 0,
  disk_used: 0,
  disk_total: 0,
  network_usage: 0,
  network_in: 0,
  network_out: 0,
})
const processes = ref<any[]>([])
const processSearch = ref('')
const dbStats = reactive({
  active_connections: 0,
  total_queries: 0,
  slow_queries: 0,
  database_size: 0,
})
const trendPeriod = ref('1h')

// Chart instances
let cpuMemoryChartInstance: echarts.ECharts | null = null
let networkChartInstance: echarts.ECharts | null = null
let refreshInterval: ReturnType<typeof setInterval> | null = null

// Computed
const filteredProcesses = computed(() => {
  if (!processSearch.value) return processes.value
  const keyword = processSearch.value.toLowerCase()
  return processes.value.filter(p => p.name.toLowerCase().includes(keyword))
})

// Fetch data
const fetchResources = async () => {
  try {
    const data = await monitorApi.getSystemResources()
    Object.assign(resources, data.resources)
    processes.value = data.processes || []
    Object.assign(dbStats, data.database || {})
  } catch (e) {
    ElMessage.error('获取系统资源失败')
  }
}

const fetchTrends = async () => {
  try {
    // Convert period string to hours number
    const hoursMap: Record<string, number> = { '1h': 1, '6h': 6, '24h': 24 }
    const hours = hoursMap[trendPeriod.value] || 24
    const data = await monitorApi.getResourceTrends(hours)
    renderCpuMemoryChart(data.trends || [])
    renderNetworkChart(data.trends || [])
  } catch (e) {
    ElMessage.error('获取资源趋势失败')
  }
}

// Render charts
const renderCpuMemoryChart = (data: any[]) => {
  if (!cpuMemoryChart.value) return

  if (!cpuMemoryChartInstance) {
    cpuMemoryChartInstance = echarts.init(cpuMemoryChart.value)
  }

  // Format timestamp for display
  const formatTime = (ts: string) => {
    const date = new Date(ts)
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['CPU', '内存'], bottom: 0 },
    grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => formatTime(d.timestamp)) },
    yAxis: { type: 'value', max: 100, axisLabel: { formatter: '{value}%' } },
    series: [
      { name: 'CPU', type: 'line', smooth: true, areaStyle: { opacity: 0.3 }, data: data.map(d => d.cpu_percent), itemStyle: { color: '#6495ED' } },
      { name: '内存', type: 'line', smooth: true, areaStyle: { opacity: 0.3 }, data: data.map(d => d.memory_percent), itemStyle: { color: '#52c41a' } },
    ],
  }

  cpuMemoryChartInstance.setOption(option)
}

const renderNetworkChart = (data: any[]) => {
  if (!networkChart.value) return

  if (!networkChartInstance) {
    networkChartInstance = echarts.init(networkChart.value)
  }

  // Format timestamp for display
  const formatTime = (ts: string) => {
    const date = new Date(ts)
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['入流量', '出流量'], bottom: 0 },
    grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => formatTime(d.timestamp)) },
    yAxis: { type: 'value', axisLabel: { formatter: (v: number) => formatSpeed(v) } },
    series: [
      { name: '入流量', type: 'line', smooth: true, areaStyle: { opacity: 0.3 }, data: data.map(d => d.network_in || 0), itemStyle: { color: '#722ed1' } },
      { name: '出流量', type: 'line', smooth: true, areaStyle: { opacity: 0.3 }, data: data.map(d => d.network_out || 0), itemStyle: { color: '#fa8c16' } },
    ],
  }

  networkChartInstance.setOption(option)
}

// Helpers
const getProgressColor = (percentage: number) => {
  if (percentage < 60) return '#52c41a'
  if (percentage < 80) return '#fa8c16'
  return '#ff4d4f'
}

const formatBytes = (bytes: number) => {
  if (!bytes) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

const formatSpeed = (bytes: number) => {
  if (!bytes) return '0 B/s'
  const k = 1024
  const sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

const formatUptime = (seconds: number) => {
  if (!seconds) return '-'
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  if (days > 0) return `${days}天${hours}小时`
  if (hours > 0) return `${hours}小时${minutes}分`
  return `${minutes}分钟`
}

// Resize
const handleResize = () => {
  cpuMemoryChartInstance?.resize()
  networkChartInstance?.resize()
}

// Lifecycle
onMounted(() => {
  fetchResources()
  fetchTrends()
  window.addEventListener('resize', handleResize)

  // Auto refresh every 10 seconds
  refreshInterval = setInterval(() => {
    fetchResources()
  }, 10000)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  cpuMemoryChartInstance?.dispose()
  networkChartInstance?.dispose()
  if (refreshInterval) clearInterval(refreshInterval)
})
</script>

<style scoped lang="scss">
.system-resources {
  .resource-gauge {
    text-align: center;
    padding: 10px;

    .gauge-label {
      margin-top: 12px;
      font-size: 16px;
      font-weight: 500;
    }

    .gauge-detail {
      margin-top: 4px;
      font-size: 12px;
      color: #999;
    }
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
  }

  .process-search {
    width: 180px;
    max-width: 100%;
  }

  .chart-container {
    width: 100%;
    height: 300px;
  }
}
</style>
