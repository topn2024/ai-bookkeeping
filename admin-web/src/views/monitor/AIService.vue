<template>
  <div class="ai-service-monitor">
    <div class="page-header">
      <h2 class="page-title">AI服务监控</h2>
      <div class="header-actions">
        <el-button @click="fetchData">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
      </div>
    </div>

    <!-- AI Engine Status Card -->
    <el-card class="status-card mb-20" :body-style="{ padding: 0 }">
      <div class="status-gradient">
        <div class="status-content">
          <div class="status-icon">
            <el-icon :size="32"><MagicStick /></el-icon>
          </div>
          <div class="status-info">
            <h3>AI识别引擎</h3>
            <p>{{ aiStatus.provider }} · {{ aiStatus.status === 'healthy' ? '运行正常' : '服务异常' }}</p>
          </div>
          <el-tag :type="aiStatus.status === 'healthy' ? 'success' : 'danger'" size="large">
            {{ aiStatus.status === 'healthy' ? '在线' : '离线' }}
          </el-tag>
        </div>
        <div class="status-metrics">
          <div class="metric-item">
            <div class="metric-value">{{ aiStatus.success_rate }}%</div>
            <div class="metric-label">成功率</div>
          </div>
          <div class="metric-item">
            <div class="metric-value">{{ aiStatus.avg_response_time }}s</div>
            <div class="metric-label">平均响应</div>
          </div>
          <div class="metric-item">
            <div class="metric-value">{{ aiStatus.today_calls }}</div>
            <div class="metric-label">今日调用</div>
          </div>
        </div>
      </div>
    </el-card>

    <el-row :gutter="20" class="mb-20">
      <!-- Recognition Type Statistics -->
      <el-col :span="12">
        <el-card>
          <template #header>识别类型统计</template>
          <div class="recognition-list">
            <div
              v-for="item in recognitionStats"
              :key="item.type"
              class="recognition-item"
            >
              <div class="recognition-icon" :style="{ background: item.bgColor }">
                <el-icon :color="item.color"><component :is="item.icon" /></el-icon>
              </div>
              <div class="recognition-info">
                <div class="recognition-name">{{ item.name }}</div>
                <div class="recognition-details">
                  成功率 {{ item.success_rate }}% · 平均 {{ item.avg_time }}s
                </div>
              </div>
              <div class="recognition-count">{{ item.count }}次</div>
            </div>
          </div>
        </el-card>
      </el-col>

      <!-- Token Usage -->
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>本月Token使用</span>
              <el-tag size="small">{{ tokenUsage.reset_date }}</el-tag>
            </div>
          </template>
          <div class="token-usage">
            <div class="token-header">
              <span>已使用</span>
              <span class="token-numbers">
                {{ formatNumber(tokenUsage.used) }} / {{ formatNumber(tokenUsage.total) }}
              </span>
            </div>
            <el-progress
              :percentage="tokenUsage.percentage"
              :stroke-width="12"
              :color="getProgressColor(tokenUsage.percentage)"
            />
            <div class="token-footer">
              <span>剩余 {{ formatNumber(tokenUsage.remaining) }}</span>
              <span>{{ tokenUsage.prediction }}</span>
            </div>
          </div>

          <!-- Token breakdown -->
          <el-divider />
          <div class="token-breakdown">
            <div class="breakdown-item">
              <span class="breakdown-label">语音识别</span>
              <span class="breakdown-value">{{ formatNumber(tokenUsage.voice_tokens) }}</span>
            </div>
            <div class="breakdown-item">
              <span class="breakdown-label">图片OCR</span>
              <span class="breakdown-value">{{ formatNumber(tokenUsage.ocr_tokens) }}</span>
            </div>
            <div class="breakdown-item">
              <span class="breakdown-label">智能分类</span>
              <span class="breakdown-value">{{ formatNumber(tokenUsage.classify_tokens) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Charts Row -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="12">
        <el-card>
          <template #header>调用趋势 (近7天)</template>
          <div ref="callTrendChart" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>响应时间分布</template>
          <div ref="responseTimeChart" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Recent AI Calls -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>最近调用记录</span>
          <el-select v-model="callFilter" placeholder="筛选类型" style="width: 120px;" @change="fetchCalls">
            <el-option label="全部" value="" />
            <el-option label="语音识别" value="voice" />
            <el-option label="图片OCR" value="ocr" />
            <el-option label="智能分类" value="classify" />
          </el-select>
        </div>
      </template>
      <el-table :data="recentCalls" stripe>
        <el-table-column prop="id" label="ID" width="100" />
        <el-table-column prop="type" label="类型" width="120">
          <template #default="{ row }">
            <el-tag :type="getTypeTag(row.type)" size="small">{{ getTypeName(row.type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="input_preview" label="输入预览" min-width="200" show-overflow-tooltip />
        <el-table-column prop="response_time" label="响应时间" width="100">
          <template #default="{ row }">{{ row.response_time }}ms</template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 'success' ? 'success' : 'danger'" size="small">
              {{ row.status === 'success' ? '成功' : '失败' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tokens" label="Token" width="80" />
        <el-table-column prop="created_at" label="时间" width="180">
          <template #default="{ row }">{{ formatDateTime(row.created_at) }}</template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { ElMessage } from 'element-plus'
import * as monitorApi from '@/api/monitor'

// Refs
const callTrendChart = ref<HTMLElement>()
const responseTimeChart = ref<HTMLElement>()

// Chart instances
let callTrendChartInstance: echarts.ECharts | null = null
let responseTimeChartInstance: echarts.ECharts | null = null

// State
const aiStatus = ref({
  provider: '通义千问',
  status: 'healthy',
  success_rate: 98.5,
  avg_response_time: 1.2,
  today_calls: 156,
})

const recognitionStats = ref([
  {
    type: 'voice',
    name: '语音识别',
    icon: 'Microphone',
    color: '#6366f1',
    bgColor: 'rgba(99, 102, 241, 0.15)',
    success_rate: 99.1,
    avg_time: 0.8,
    count: 89,
  },
  {
    type: 'ocr',
    name: '图片OCR',
    icon: 'Picture',
    color: '#6366f1',
    bgColor: 'rgba(99, 102, 241, 0.15)',
    success_rate: 97.2,
    avg_time: 1.5,
    count: 45,
  },
  {
    type: 'classify',
    name: '智能分类',
    icon: 'ChatDotRound',
    color: '#6366f1',
    bgColor: 'rgba(99, 102, 241, 0.15)',
    success_rate: 98.8,
    avg_time: 0.3,
    count: 22,
  },
])

const tokenUsage = ref({
  used: 45680,
  total: 100000,
  remaining: 54320,
  percentage: 45.68,
  reset_date: '月底重置',
  prediction: '预计可用至月底',
  voice_tokens: 28000,
  ocr_tokens: 12000,
  classify_tokens: 5680,
})

const recentCalls = ref<any[]>([])
const callFilter = ref('')

// Fetch data
const fetchData = async () => {
  try {
    const data = await monitorApi.getAIServiceStatus()
    if (data) {
      aiStatus.value = data.status || aiStatus.value
      recognitionStats.value = data.recognition_stats || recognitionStats.value
      tokenUsage.value = data.token_usage || tokenUsage.value
    }
  } catch (e) {
    // Use default mock data
  }

  renderCharts()
  fetchCalls()
}

const fetchCalls = async () => {
  try {
    const params: any = { limit: 10 }
    if (callFilter.value) params.type = callFilter.value

    const data = await monitorApi.getAICalls(params)
    recentCalls.value = data.items || generateMockCalls()
  } catch (e) {
    recentCalls.value = generateMockCalls()
  }
}

// Generate mock calls
const generateMockCalls = () => {
  return [
    {
      id: 'AI001',
      type: 'voice',
      input_preview: '今天午餐花了35元',
      response_time: 820,
      status: 'success',
      tokens: 128,
      created_at: new Date().toISOString(),
    },
    {
      id: 'AI002',
      type: 'ocr',
      input_preview: '收据图片识别',
      response_time: 1520,
      status: 'success',
      tokens: 256,
      created_at: new Date(Date.now() - 300000).toISOString(),
    },
    {
      id: 'AI003',
      type: 'classify',
      input_preview: '滴滴打车 - 交通出行',
      response_time: 280,
      status: 'success',
      tokens: 64,
      created_at: new Date(Date.now() - 600000).toISOString(),
    },
    {
      id: 'AI004',
      type: 'voice',
      input_preview: '买菜花了二十块',
      response_time: 750,
      status: 'success',
      tokens: 112,
      created_at: new Date(Date.now() - 900000).toISOString(),
    },
    {
      id: 'AI005',
      type: 'ocr',
      input_preview: '发票识别超时',
      response_time: 5000,
      status: 'failed',
      tokens: 0,
      created_at: new Date(Date.now() - 1200000).toISOString(),
    },
  ]
}

// Render charts
const renderCharts = () => {
  renderCallTrendChart()
  renderResponseTimeChart()
}

const renderCallTrendChart = () => {
  if (!callTrendChart.value) return

  if (!callTrendChartInstance) {
    callTrendChartInstance = echarts.init(callTrendChart.value)
  }

  const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['语音识别', '图片OCR', '智能分类'], bottom: 0 },
    grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
    xAxis: { type: 'category', data: days },
    yAxis: { type: 'value', name: '次数' },
    series: [
      {
        name: '语音识别',
        type: 'line',
        smooth: true,
        data: [65, 78, 82, 95, 89, 72, 89],
        itemStyle: { color: '#6366f1' },
        areaStyle: { color: 'rgba(99, 102, 241, 0.1)' },
      },
      {
        name: '图片OCR',
        type: 'line',
        smooth: true,
        data: [28, 35, 42, 38, 45, 30, 45],
        itemStyle: { color: '#8b5cf6' },
        areaStyle: { color: 'rgba(139, 92, 246, 0.1)' },
      },
      {
        name: '智能分类',
        type: 'line',
        smooth: true,
        data: [15, 18, 22, 25, 22, 18, 22],
        itemStyle: { color: '#a855f7' },
        areaStyle: { color: 'rgba(168, 85, 247, 0.1)' },
      },
    ],
  }

  callTrendChartInstance.setOption(option)
}

const renderResponseTimeChart = () => {
  if (!responseTimeChart.value) return

  if (!responseTimeChartInstance) {
    responseTimeChartInstance = echarts.init(responseTimeChart.value)
  }

  const option = {
    tooltip: { trigger: 'item' },
    legend: { orient: 'vertical', left: 'left' },
    series: [
      {
        type: 'pie',
        radius: ['40%', '70%'],
        avoidLabelOverlap: false,
        itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 },
        label: { show: false },
        emphasis: {
          label: { show: true, fontSize: 14, fontWeight: 'bold' },
        },
        labelLine: { show: false },
        data: [
          { value: 65, name: '<500ms', itemStyle: { color: '#10b981' } },
          { value: 25, name: '500-1000ms', itemStyle: { color: '#f59e0b' } },
          { value: 8, name: '1-2s', itemStyle: { color: '#f97316' } },
          { value: 2, name: '>2s', itemStyle: { color: '#ef4444' } },
        ],
      },
    ],
  }

  responseTimeChartInstance.setOption(option)
}

// Helpers
const formatNumber = (num: number) => {
  return num.toLocaleString()
}

const getProgressColor = (percentage: number) => {
  if (percentage < 50) return '#10b981'
  if (percentage < 80) return '#f59e0b'
  return '#ef4444'
}

const getTypeTag = (type: string) => {
  const map: Record<string, string> = {
    voice: 'primary',
    ocr: 'success',
    classify: 'warning',
  }
  return map[type] || ''
}

const getTypeName = (type: string) => {
  const map: Record<string, string> = {
    voice: '语音识别',
    ocr: '图片OCR',
    classify: '智能分类',
  }
  return map[type] || type
}

const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Resize
const handleResize = () => {
  callTrendChartInstance?.resize()
  responseTimeChartInstance?.resize()
}

// Lifecycle
onMounted(() => {
  fetchData()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  callTrendChartInstance?.dispose()
  responseTimeChartInstance?.dispose()
})
</script>

<style scoped lang="scss">
.ai-service-monitor {
  .status-card {
    .status-gradient {
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      padding: 24px;
      color: white;
    }

    .status-content {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 20px;

      .status-icon {
        width: 56px;
        height: 56px;
        background: rgba(255, 255, 255, 0.2);
        border-radius: 16px;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .status-info {
        flex: 1;

        h3 {
          margin: 0 0 4px 0;
          font-size: 18px;
        }

        p {
          margin: 0;
          opacity: 0.9;
          font-size: 13px;
        }
      }
    }

    .status-metrics {
      display: flex;
      gap: 32px;

      .metric-item {
        .metric-value {
          font-size: 28px;
          font-weight: 700;
        }

        .metric-label {
          font-size: 12px;
          opacity: 0.9;
        }
      }
    }
  }

  .recognition-list {
    .recognition-item {
      display: flex;
      align-items: center;
      padding: 14px 0;
      border-bottom: 1px solid #f0f0f0;

      &:last-child {
        border-bottom: none;
      }

      .recognition-icon {
        width: 40px;
        height: 40px;
        border-radius: 10px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 20px;
      }

      .recognition-info {
        flex: 1;
        margin-left: 14px;

        .recognition-name {
          font-weight: 500;
          margin-bottom: 2px;
        }

        .recognition-details {
          font-size: 12px;
          color: #999;
        }
      }

      .recognition-count {
        font-size: 15px;
        font-weight: 600;
        color: #333;
      }
    }
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .token-usage {
    .token-header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
      font-size: 14px;

      .token-numbers {
        font-weight: 600;
      }
    }

    .token-footer {
      display: flex;
      justify-content: space-between;
      margin-top: 10px;
      font-size: 12px;
      color: #999;
    }
  }

  .token-breakdown {
    .breakdown-item {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      font-size: 13px;

      .breakdown-label {
        color: #666;
      }

      .breakdown-value {
        font-weight: 500;
      }
    }
  }

  .chart-container {
    width: 100%;
    height: 300px;
  }
}
</style>
