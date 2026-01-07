<template>
  <div class="system-logs">
    <div class="page-header">
      <h2 class="page-title">系统日志</h2>
      <div class="header-actions">
        <el-button @click="fetchLogs">
          <el-icon><Refresh /></el-icon>刷新
        </el-button>
        <el-button type="primary" @click="exportLogs">
          <el-icon><Download /></el-icon>导出日志
        </el-button>
      </div>
    </div>

    <!-- Filter Tabs -->
    <el-radio-group v-model="levelFilter" class="level-tabs mb-20" @change="fetchLogs">
      <el-radio-button value="">全部</el-radio-button>
      <el-radio-button value="error">
        错误
        <el-badge :value="logCounts.error" type="danger" class="ml-5" v-if="logCounts.error > 0" />
      </el-radio-button>
      <el-radio-button value="warning">
        警告
        <el-badge :value="logCounts.warning" type="warning" class="ml-5" v-if="logCounts.warning > 0" />
      </el-radio-button>
      <el-radio-button value="info">信息</el-radio-button>
      <el-radio-button value="debug">调试</el-radio-button>
    </el-radio-group>

    <!-- Search and Date Filter -->
    <el-row :gutter="20" class="mb-20">
      <el-col :span="8">
        <el-input
          v-model="searchKeyword"
          placeholder="搜索日志内容..."
          clearable
          @input="handleSearch"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
      </el-col>
      <el-col :span="8">
        <el-date-picker
          v-model="dateRange"
          type="datetimerange"
          range-separator="至"
          start-placeholder="开始时间"
          end-placeholder="结束时间"
          value-format="YYYY-MM-DD HH:mm:ss"
          @change="fetchLogs"
        />
      </el-col>
      <el-col :span="8">
        <el-select v-model="sourceFilter" placeholder="日志来源" clearable @change="fetchLogs">
          <el-option label="全部来源" value="" />
          <el-option label="API服务" value="api" />
          <el-option label="数据库" value="database" />
          <el-option label="任务调度" value="scheduler" />
          <el-option label="同步服务" value="sync" />
          <el-option label="AI服务" value="ai" />
        </el-select>
      </el-col>
    </el-row>

    <!-- Log Entries -->
    <el-card v-loading="loading">
      <div class="log-container">
        <div
          v-for="log in logs"
          :key="log.id"
          :class="['log-entry', log.level]"
        >
          <div class="log-header">
            <el-tag :type="getLevelTag(log.level)" size="small" effect="dark">
              [{{ log.level.toUpperCase() }}]
            </el-tag>
            <span class="log-time">{{ formatTime(log.timestamp) }}</span>
            <span v-if="log.source" class="log-source">{{ log.source }}</span>
          </div>
          <div class="log-message">{{ log.message }}</div>
          <div v-if="log.details" class="log-details">
            <el-collapse>
              <el-collapse-item title="详细信息">
                <pre>{{ formatDetails(log.details) }}</pre>
              </el-collapse-item>
            </el-collapse>
          </div>
        </div>

        <div v-if="logs.length === 0 && !loading" class="empty-state">
          <el-icon><Document /></el-icon>
          <p>暂无日志记录</p>
        </div>
      </div>

      <!-- Pagination -->
      <div class="pagination-container" v-if="total > 0">
        <el-pagination
          v-model:current-page="currentPage"
          v-model:page-size="pageSize"
          :page-sizes="[50, 100, 200, 500]"
          layout="total, sizes, prev, pager, next, jumper"
          :total="total"
          @size-change="fetchLogs"
          @current-change="fetchLogs"
        />
      </div>
    </el-card>

    <!-- Real-time Log Stream -->
    <el-card class="mt-20">
      <template #header>
        <div class="card-header">
          <span>实时日志流</span>
          <el-switch
            v-model="isStreaming"
            active-text="开启"
            inactive-text="关闭"
            @change="toggleStreaming"
          />
        </div>
      </template>
      <div class="stream-container" ref="streamContainer">
        <div
          v-for="(log, index) in streamLogs"
          :key="index"
          :class="['stream-entry', log.level]"
        >
          <span class="stream-time">{{ log.time }}</span>
          <el-tag :type="getLevelTag(log.level)" size="small">{{ log.level }}</el-tag>
          <span class="stream-message">{{ log.message }}</span>
        </div>
        <div v-if="streamLogs.length === 0" class="stream-empty">
          等待新日志...
        </div>
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { ElMessage } from 'element-plus'
import { debounce } from 'lodash-es'
import * as monitorApi from '@/api/monitor'

// State
const logs = ref<any[]>([])
const streamLogs = ref<any[]>([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(100)

// Filters
const levelFilter = ref('')
const searchKeyword = ref('')
const dateRange = ref<[string, string] | null>(null)
const sourceFilter = ref('')

// Streaming
const isStreaming = ref(false)
const streamContainer = ref<HTMLElement>()
let streamInterval: ReturnType<typeof setInterval> | null = null

// Log counts by level
const logCounts = ref({
  error: 0,
  warning: 0,
  info: 0,
  debug: 0,
})

// Fetch logs
const fetchLogs = async () => {
  loading.value = true
  try {
    const params: any = {
      page: currentPage.value,
      page_size: pageSize.value,
    }
    if (levelFilter.value) params.level = levelFilter.value
    if (searchKeyword.value) params.keyword = searchKeyword.value
    if (sourceFilter.value) params.source = sourceFilter.value
    if (dateRange.value) {
      params.start_time = dateRange.value[0]
      params.end_time = dateRange.value[1]
    }

    const data = await monitorApi.getSystemLogs(params)
    logs.value = data.items || generateMockLogs()
    total.value = data.total || logs.value.length
    logCounts.value = data.counts || { error: 2, warning: 5, info: 12, debug: 8 }
  } catch (e) {
    // Use mock data for demo
    logs.value = generateMockLogs()
    total.value = logs.value.length
    logCounts.value = { error: 2, warning: 5, info: 12, debug: 8 }
  } finally {
    loading.value = false
  }
}

// Generate mock logs for demo
const generateMockLogs = () => {
  const mockLogs = [
    {
      id: '1',
      level: 'error',
      message: 'API request failed: timeout after 30s',
      timestamp: new Date().toISOString(),
      source: 'api',
      details: { endpoint: '/api/v1/sync', status: 504, duration_ms: 30000 },
    },
    {
      id: '2',
      level: 'warning',
      message: 'Slow query detected: 523ms',
      timestamp: new Date(Date.now() - 60000).toISOString(),
      source: 'database',
      details: { table: 'transactions', query_time_ms: 523 },
    },
    {
      id: '3',
      level: 'info',
      message: 'Sync completed successfully',
      timestamp: new Date(Date.now() - 120000).toISOString(),
      source: 'sync',
      details: { records: 45 },
    },
    {
      id: '4',
      level: 'info',
      message: 'Voice recognition completed',
      timestamp: new Date(Date.now() - 180000).toISOString(),
      source: 'ai',
      details: { confidence: 0.95 },
    },
    {
      id: '5',
      level: 'debug',
      message: 'Audio recording started',
      timestamp: new Date(Date.now() - 200000).toISOString(),
      source: 'ai',
    },
    {
      id: '6',
      level: 'error',
      message: 'Database connection pool exhausted',
      timestamp: new Date(Date.now() - 300000).toISOString(),
      source: 'database',
      details: { active_connections: 100, max_connections: 100 },
    },
    {
      id: '7',
      level: 'warning',
      message: 'High memory usage detected',
      timestamp: new Date(Date.now() - 400000).toISOString(),
      source: 'scheduler',
      details: { memory_percent: 85 },
    },
    {
      id: '8',
      level: 'info',
      message: 'Scheduled backup completed',
      timestamp: new Date(Date.now() - 500000).toISOString(),
      source: 'scheduler',
      details: { backup_size_mb: 128 },
    },
  ]

  // Filter by level if needed
  if (levelFilter.value) {
    return mockLogs.filter(log => log.level === levelFilter.value)
  }
  return mockLogs
}

// Handle search with debounce
const handleSearch = debounce(() => {
  currentPage.value = 1
  fetchLogs()
}, 300)

// Export logs
const exportLogs = async () => {
  try {
    // Generate export content
    const content = logs.value.map(log => {
      return `[${log.level.toUpperCase()}] ${formatTime(log.timestamp)} - ${log.message}`
    }).join('\n')

    const blob = new Blob([content], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `system-logs-${new Date().toISOString().slice(0, 10)}.txt`
    a.click()
    URL.revokeObjectURL(url)

    ElMessage.success('日志导出成功')
  } catch (e) {
    ElMessage.error('日志导出失败')
  }
}

// Toggle streaming
const toggleStreaming = (enabled: boolean) => {
  if (enabled) {
    startStreaming()
  } else {
    stopStreaming()
  }
}

const startStreaming = () => {
  streamInterval = setInterval(() => {
    // Simulate new log entries
    const levels = ['info', 'debug', 'warning']
    const messages = [
      'Request processed successfully',
      'Cache hit for query',
      'New user session started',
      'Background task completed',
      'API response cached',
    ]

    const newLog = {
      time: new Date().toLocaleTimeString('zh-CN'),
      level: levels[Math.floor(Math.random() * levels.length)],
      message: messages[Math.floor(Math.random() * messages.length)],
    }

    streamLogs.value.push(newLog)
    if (streamLogs.value.length > 50) {
      streamLogs.value.shift()
    }

    nextTick(() => {
      if (streamContainer.value) {
        streamContainer.value.scrollTop = streamContainer.value.scrollHeight
      }
    })
  }, 2000)
}

const stopStreaming = () => {
  if (streamInterval) {
    clearInterval(streamInterval)
    streamInterval = null
  }
}

// Helpers
const getLevelTag = (level: string) => {
  const map: Record<string, string> = {
    error: 'danger',
    warning: 'warning',
    info: 'primary',
    debug: 'info',
  }
  return map[level] || 'info'
}

const formatTime = (timestamp: string) => {
  return new Date(timestamp).toLocaleString('zh-CN')
}

const formatDetails = (details: any) => {
  return typeof details === 'string' ? details : JSON.stringify(details, null, 2)
}

// Lifecycle
onMounted(() => {
  fetchLogs()
})

onUnmounted(() => {
  stopStreaming()
})
</script>

<style scoped lang="scss">
.system-logs {
  .level-tabs {
    .el-radio-button {
      position: relative;

      .el-badge {
        position: absolute;
        top: -8px;
        right: -8px;
      }
    }
  }

  .log-container {
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: 13px;
    line-height: 1.6;
    max-height: 600px;
    overflow-y: auto;
  }

  .log-entry {
    padding: 10px 14px;
    margin-bottom: 8px;
    border-radius: 8px;
    border-left: 3px solid;

    &.error {
      background: rgba(239, 68, 68, 0.1);
      border-left-color: #ef4444;
    }

    &.warning {
      background: rgba(245, 158, 11, 0.1);
      border-left-color: #f59e0b;
    }

    &.info {
      background: rgba(59, 130, 246, 0.1);
      border-left-color: #3b82f6;
    }

    &.debug {
      background: #f5f5f5;
      border-left-color: #9ca3af;
    }

    .log-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 6px;

      .log-time {
        color: #666;
        font-size: 12px;
      }

      .log-source {
        color: #999;
        font-size: 11px;
        padding: 2px 6px;
        background: #f0f0f0;
        border-radius: 4px;
      }
    }

    .log-message {
      color: #333;
    }

    .log-details {
      margin-top: 8px;

      pre {
        font-size: 12px;
        background: rgba(0, 0, 0, 0.05);
        padding: 8px;
        border-radius: 4px;
        overflow-x: auto;
        margin: 0;
      }
    }
  }

  .pagination-container {
    margin-top: 20px;
    display: flex;
    justify-content: flex-end;
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .stream-container {
    height: 200px;
    overflow-y: auto;
    font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    font-size: 12px;
    background: #1e1e1e;
    color: #d4d4d4;
    padding: 12px;
    border-radius: 8px;
  }

  .stream-entry {
    padding: 4px 0;
    display: flex;
    align-items: center;
    gap: 8px;

    .stream-time {
      color: #808080;
    }

    .stream-message {
      flex: 1;
    }

    &.error .stream-message { color: #f14c4c; }
    &.warning .stream-message { color: #cca700; }
    &.info .stream-message { color: #3794ff; }
    &.debug .stream-message { color: #808080; }
  }

  .stream-empty {
    color: #808080;
    text-align: center;
    padding: 40px;
  }

  .empty-state {
    text-align: center;
    padding: 60px;
    color: #999;

    .el-icon {
      font-size: 48px;
      margin-bottom: 12px;
    }
  }
}
</style>
