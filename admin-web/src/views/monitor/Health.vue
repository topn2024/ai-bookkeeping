<template>
  <div class="system-health">
    <div class="page-header">
      <h2 class="page-title">系统健康</h2>
      <div class="header-actions">
        <el-button @click="fetchHealth">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
        <el-tag :type="overallStatus === 'healthy' ? 'success' : overallStatus === 'degraded' ? 'warning' : 'danger'" size="large">
          {{ overallStatus === 'healthy' ? '系统正常' : overallStatus === 'degraded' ? '系统降级' : '系统异常' }}
        </el-tag>
      </div>
    </div>

    <!-- Service Status Cards -->
    <el-row :gutter="20" class="mb-20">
      <el-col v-for="service in services" :key="service.name" :span="6">
        <el-card shadow="hover" :class="['service-card', service.status]">
          <div class="service-header">
            <span class="service-name">{{ service.name }}</span>
            <el-tag :type="getStatusTag(service.status)" size="small">
              {{ getStatusText(service.status) }}
            </el-tag>
          </div>
          <div class="service-details">
            <div class="detail-item">
              <span class="label">响应时间</span>
              <span class="value">{{ service.response_time }}ms</span>
            </div>
            <div class="detail-item">
              <span class="label">最后检查</span>
              <span class="value">{{ formatTime(service.last_check) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Health Metrics -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="12">
        <el-card>
          <template #header>API响应时间趋势</template>
          <div ref="responseTimeChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>服务可用性</template>
          <div ref="availabilityChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Recent Health Events -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>健康事件</span>
          <el-select v-model="eventFilter" placeholder="筛选" style="width: 120px;" @change="fetchEvents">
            <el-option label="全部" value="" />
            <el-option label="错误" value="error" />
            <el-option label="警告" value="warning" />
            <el-option label="信息" value="info" />
          </el-select>
        </div>
      </template>
      <el-timeline>
        <el-timeline-item
          v-for="event in healthEvents"
          :key="event.id"
          :type="getEventType(event.level)"
          :timestamp="formatDateTime(event.created_at)"
          placement="top"
        >
          <el-card shadow="never">
            <div class="event-header">
              <span class="event-service">{{ event.service }}</span>
              <el-tag :type="getEventType(event.level)" size="small">{{ event.level }}</el-tag>
            </div>
            <p class="event-message">{{ event.message }}</p>
            <div v-if="event.details" class="event-details">
              <el-collapse>
                <el-collapse-item title="详细信息">
                  <pre>{{ JSON.stringify(event.details, null, 2) }}</pre>
                </el-collapse-item>
              </el-collapse>
            </div>
          </el-card>
        </el-timeline-item>
      </el-timeline>
      <div v-if="healthEvents.length === 0" class="empty-state">
        <el-icon><CircleCheck /></el-icon>
        <p>暂无健康事件</p>
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import * as monitorApi from '@/api/monitor'

// Refs
const responseTimeChart = ref<HTMLElement>()
const availabilityChart = ref<HTMLElement>()

// State
const services = ref<any[]>([])
const healthEvents = ref<any[]>([])
const eventFilter = ref('')

// Chart instances
let responseTimeChartInstance: echarts.ECharts | null = null
let availabilityChartInstance: echarts.ECharts | null = null
let refreshInterval: ReturnType<typeof setInterval> | null = null

// Computed
const overallStatus = computed(() => {
  if (services.value.some(s => s.status === 'down')) return 'unhealthy'
  if (services.value.some(s => s.status === 'degraded')) return 'degraded'
  return 'healthy'
})

// Fetch data
const fetchHealth = async () => {
  try {
    const data = await monitorApi.getSystemHealth()
    services.value = data.services || []
    renderResponseTimeChart(data.response_time_trend || [])
    renderAvailabilityChart(data.availability || [])
  } catch (e) {
    ElMessage.error('获取系统健康状态失败')
  }
}

const fetchEvents = async () => {
  try {
    const params: any = { limit: 20 }
    if (eventFilter.value) params.level = eventFilter.value

    const data = await monitorApi.getHealthEvents(params)
    healthEvents.value = data.items || []
  } catch (e) {
    ElMessage.error('获取健康事件失败')
  }
}

// Render charts
const renderResponseTimeChart = (data: any[]) => {
  if (!responseTimeChart.value) return

  if (!responseTimeChartInstance) {
    responseTimeChartInstance = echarts.init(responseTimeChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['API', '数据库', '缓存'], bottom: 0 },
    grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.time) },
    yAxis: { type: 'value', name: 'ms' },
    series: [
      { name: 'API', type: 'line', smooth: true, data: data.map(d => d.api), itemStyle: { color: '#1890ff' } },
      { name: '数据库', type: 'line', smooth: true, data: data.map(d => d.database), itemStyle: { color: '#52c41a' } },
      { name: '缓存', type: 'line', smooth: true, data: data.map(d => d.cache), itemStyle: { color: '#fa8c16' } },
    ],
  }

  responseTimeChartInstance.setOption(option)
}

const renderAvailabilityChart = (data: any[]) => {
  if (!availabilityChart.value) return

  if (!availabilityChartInstance) {
    availabilityChartInstance = echarts.init(availabilityChart.value)
  }

  const option = {
    tooltip: { trigger: 'axis', formatter: '{b}: {c}%' },
    grid: { left: '3%', right: '4%', bottom: '3%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: data.map(d => d.service) },
    yAxis: { type: 'value', min: 90, max: 100, axisLabel: { formatter: '{value}%' } },
    series: [{
      type: 'bar',
      data: data.map(d => ({
        value: d.availability,
        itemStyle: { color: d.availability >= 99 ? '#52c41a' : d.availability >= 95 ? '#fa8c16' : '#ff4d4f' },
      })),
      label: { show: true, position: 'top', formatter: '{c}%' },
    }],
  }

  availabilityChartInstance.setOption(option)
}

// Helpers
const getStatusTag = (status: string) => {
  const map: Record<string, string> = {
    healthy: 'success',
    degraded: 'warning',
    down: 'danger',
  }
  return map[status] || ''
}

const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    healthy: '正常',
    degraded: '降级',
    down: '宕机',
  }
  return map[status] || status
}

const getEventType = (level: string) => {
  const map: Record<string, string> = {
    error: 'danger',
    warning: 'warning',
    info: 'primary',
  }
  return map[level] || ''
}

const formatTime = (date: string) => {
  const d = new Date(date)
  return d.toLocaleTimeString('zh-CN')
}

const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Resize
const handleResize = () => {
  responseTimeChartInstance?.resize()
  availabilityChartInstance?.resize()
}

// Lifecycle
onMounted(() => {
  fetchHealth()
  fetchEvents()
  window.addEventListener('resize', handleResize)

  // Auto refresh every 30 seconds
  refreshInterval = setInterval(() => {
    fetchHealth()
  }, 30000)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  responseTimeChartInstance?.dispose()
  availabilityChartInstance?.dispose()
  if (refreshInterval) clearInterval(refreshInterval)
})
</script>

<style scoped lang="scss">
.system-health {
  .header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .service-card {
    transition: all 0.3s;

    &.healthy {
      border-left: 4px solid #52c41a;
    }

    &.degraded {
      border-left: 4px solid #fa8c16;
    }

    &.down {
      border-left: 4px solid #ff4d4f;
    }

    .service-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;

      .service-name {
        font-weight: 600;
        font-size: 16px;
      }
    }

    .service-details {
      .detail-item {
        display: flex;
        justify-content: space-between;
        padding: 4px 0;
        font-size: 13px;

        .label {
          color: #999;
        }

        .value {
          color: #333;
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

  .event-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;

    .event-service {
      font-weight: 600;
    }
  }

  .event-message {
    margin: 0;
    color: #666;
  }

  .event-details {
    margin-top: 8px;

    pre {
      font-size: 12px;
      background: #f5f5f5;
      padding: 8px;
      border-radius: 4px;
      overflow-x: auto;
    }
  }

  .empty-state {
    text-align: center;
    padding: 40px;
    color: #999;

    .el-icon {
      font-size: 48px;
      color: #52c41a;
    }
  }
}
</style>
