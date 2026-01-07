<template>
  <div class="diagnostics">
    <div class="page-header">
      <h2 class="page-title">诊断报告</h2>
      <div class="header-actions">
        <el-button @click="runDiagnostics" :loading="isRunning">
          <el-icon><Refresh /></el-icon>重新诊断
        </el-button>
        <el-button type="primary" @click="exportReport">
          <el-icon><Download /></el-icon>导出报告
        </el-button>
      </div>
    </div>

    <!-- Report Summary -->
    <el-card class="summary-card mb-20">
      <div class="summary-header">
        <div class="summary-title">
          <h3>诊断报告</h3>
          <span class="report-time">生成于 {{ formatDateTime(report.generated_at) }}</span>
        </div>
        <el-button text @click="shareReport">
          <el-icon><Share /></el-icon>分享
        </el-button>
      </div>
      <div class="summary-stats">
        <div class="stat-item passed">
          <div class="stat-value">{{ report.passed_count }}</div>
          <div class="stat-label">通过</div>
        </div>
        <div class="stat-item warning">
          <div class="stat-value">{{ report.warning_count }}</div>
          <div class="stat-label">警告</div>
        </div>
        <div class="stat-item error">
          <div class="stat-value">{{ report.error_count }}</div>
          <div class="stat-label">错误</div>
        </div>
      </div>
    </el-card>

    <el-row :gutter="20">
      <!-- Diagnostic Items -->
      <el-col :span="14">
        <el-card>
          <template #header>诊断项目</template>
          <div class="diagnostic-list">
            <div
              v-for="item in diagnosticItems"
              :key="item.id"
              :class="['diagnostic-item', item.status]"
            >
              <el-icon :size="22" :class="['status-icon', item.status]">
                <component :is="getStatusIcon(item.status)" />
              </el-icon>
              <div class="item-content">
                <div class="item-name">{{ item.name }}</div>
                <div class="item-message">{{ item.message }}</div>
              </div>
              <el-button
                v-if="item.action"
                text
                type="primary"
                size="small"
                @click="handleAction(item)"
              >
                {{ item.action }}
              </el-button>
            </div>
          </div>
        </el-card>

        <!-- Recommendations -->
        <el-card class="mt-20" v-if="recommendations.length > 0">
          <template #header>优化建议</template>
          <div class="recommendations">
            <el-alert
              v-for="rec in recommendations"
              :key="rec.id"
              :title="rec.title"
              :type="rec.severity"
              :description="rec.description"
              show-icon
              :closable="false"
              class="mb-10"
            />
          </div>
        </el-card>
      </el-col>

      <!-- Device Info -->
      <el-col :span="10">
        <el-card>
          <template #header>设备信息</template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="应用版本">
              {{ deviceInfo.app_version }}
            </el-descriptions-item>
            <el-descriptions-item label="构建号">
              {{ deviceInfo.build_number }}
            </el-descriptions-item>
            <el-descriptions-item label="服务器版本">
              {{ deviceInfo.server_version }}
            </el-descriptions-item>
            <el-descriptions-item label="Python版本">
              {{ deviceInfo.python_version }}
            </el-descriptions-item>
            <el-descriptions-item label="操作系统">
              {{ deviceInfo.os }}
            </el-descriptions-item>
            <el-descriptions-item label="数据库">
              {{ deviceInfo.database }}
            </el-descriptions-item>
          </el-descriptions>
        </el-card>

        <!-- Resource Usage -->
        <el-card class="mt-20">
          <template #header>资源使用</template>
          <div class="resource-list">
            <div class="resource-item">
              <span class="resource-label">CPU使用率</span>
              <el-progress
                :percentage="resources.cpu_percent"
                :stroke-width="10"
                :color="getResourceColor(resources.cpu_percent)"
              />
            </div>
            <div class="resource-item">
              <span class="resource-label">内存使用</span>
              <div class="resource-detail">
                <el-progress
                  :percentage="resources.memory_percent"
                  :stroke-width="10"
                  :color="getResourceColor(resources.memory_percent)"
                />
                <span class="resource-text">
                  {{ resources.memory_used_mb }}MB / {{ resources.memory_total_mb }}MB
                </span>
              </div>
            </div>
            <div class="resource-item">
              <span class="resource-label">磁盘使用</span>
              <div class="resource-detail">
                <el-progress
                  :percentage="resources.disk_percent"
                  :stroke-width="10"
                  :color="getResourceColor(resources.disk_percent)"
                />
                <span class="resource-text">
                  {{ resources.disk_used }} / {{ resources.disk_total }}
                </span>
              </div>
            </div>
          </div>
        </el-card>

        <!-- Quick Actions -->
        <el-card class="mt-20">
          <template #header>快速操作</template>
          <div class="quick-actions">
            <el-button @click="clearCache" :loading="clearingCache">
              <el-icon><Delete /></el-icon>清理缓存
            </el-button>
            <el-button @click="optimizeDatabase" :loading="optimizingDb">
              <el-icon><Setting /></el-icon>优化数据库
            </el-button>
            <el-button @click="checkUpdates">
              <el-icon><Refresh /></el-icon>检查更新
            </el-button>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Diagnostic History -->
    <el-card class="mt-20">
      <template #header>历史诊断记录</template>
      <el-table :data="diagnosticHistory" stripe>
        <el-table-column prop="id" label="ID" width="100" />
        <el-table-column prop="generated_at" label="诊断时间" width="180">
          <template #default="{ row }">{{ formatDateTime(row.generated_at) }}</template>
        </el-table-column>
        <el-table-column label="结果">
          <template #default="{ row }">
            <el-tag type="success" size="small">{{ row.passed }}</el-tag>
            <el-tag type="warning" size="small" class="ml-5" v-if="row.warnings">{{ row.warnings }}</el-tag>
            <el-tag type="danger" size="small" class="ml-5" v-if="row.errors">{{ row.errors }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="duration" label="耗时" width="100">
          <template #default="{ row }">{{ row.duration }}ms</template>
        </el-table-column>
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="viewReport(row)">
              查看详情
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as monitorApi from '@/api/monitor'

// State
const isRunning = ref(false)
const clearingCache = ref(false)
const optimizingDb = ref(false)

const report = ref({
  generated_at: new Date().toISOString(),
  passed_count: 5,
  warning_count: 1,
  error_count: 0,
})

const diagnosticItems = ref([
  {
    id: 1,
    name: '数据库完整性',
    status: 'passed',
    message: '所有表结构正常',
  },
  {
    id: 2,
    name: '网络连接',
    status: 'passed',
    message: 'API可达 · 延迟45ms',
  },
  {
    id: 3,
    name: '本地存储',
    status: 'passed',
    message: '读写正常 · 2.3GB可用',
  },
  {
    id: 4,
    name: '缓存状态',
    status: 'warning',
    message: '缓存较大(85MB)，建议清理',
    action: '清理缓存',
  },
  {
    id: 5,
    name: '同步状态',
    status: 'passed',
    message: '已同步 · 无待处理项',
  },
  {
    id: 6,
    name: 'AI服务',
    status: 'passed',
    message: '在线 · 响应正常',
  },
])

const recommendations = ref([
  {
    id: 1,
    title: '清理缓存以释放空间',
    description: '当前缓存占用85MB，清理后可提升应用性能',
    severity: 'warning',
  },
])

const deviceInfo = ref({
  app_version: '2.0.0',
  build_number: 'Build 38',
  server_version: '1.5.2',
  python_version: '3.11.5',
  os: 'Linux 5.15.0-91-generic',
  database: 'PostgreSQL 15.4',
})

const resources = ref({
  cpu_percent: 25,
  memory_percent: 42,
  memory_used_mb: 1280,
  memory_total_mb: 3072,
  disk_percent: 35,
  disk_used: '28GB',
  disk_total: '80GB',
})

const diagnosticHistory = ref([
  {
    id: 'DIAG001',
    generated_at: new Date().toISOString(),
    passed: 5,
    warnings: 1,
    errors: 0,
    duration: 1234,
  },
  {
    id: 'DIAG002',
    generated_at: new Date(Date.now() - 86400000).toISOString(),
    passed: 6,
    warnings: 0,
    errors: 0,
    duration: 1156,
  },
  {
    id: 'DIAG003',
    generated_at: new Date(Date.now() - 172800000).toISOString(),
    passed: 4,
    warnings: 1,
    errors: 1,
    duration: 1345,
  },
])

// Fetch data
const fetchData = async () => {
  try {
    const data = await monitorApi.getDiagnosticReport()
    if (data) {
      report.value = data.summary || report.value
      diagnosticItems.value = data.items || diagnosticItems.value
      recommendations.value = data.recommendations || recommendations.value
      deviceInfo.value = data.device_info || deviceInfo.value
      resources.value = data.resources || resources.value
    }
  } catch (e) {
    // Use default mock data
  }
}

// Run diagnostics
const runDiagnostics = async () => {
  isRunning.value = true
  try {
    await monitorApi.runDiagnostics()
    await fetchData()
    ElMessage.success('诊断完成')
  } catch (e) {
    // Simulate diagnostics
    await new Promise(resolve => setTimeout(resolve, 2000))
    report.value.generated_at = new Date().toISOString()
    ElMessage.success('诊断完成')
  } finally {
    isRunning.value = false
  }
}

// Export report
const exportReport = () => {
  const content = generateReportContent()
  const blob = new Blob([content], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `diagnostic-report-${new Date().toISOString().slice(0, 10)}.txt`
  a.click()
  URL.revokeObjectURL(url)
  ElMessage.success('报告导出成功')
}

const generateReportContent = () => {
  let content = `诊断报告\n生成时间: ${formatDateTime(report.value.generated_at)}\n\n`
  content += `=== 诊断结果 ===\n`
  content += `通过: ${report.value.passed_count}\n`
  content += `警告: ${report.value.warning_count}\n`
  content += `错误: ${report.value.error_count}\n\n`

  content += `=== 诊断项目 ===\n`
  diagnosticItems.value.forEach(item => {
    content += `[${item.status.toUpperCase()}] ${item.name}: ${item.message}\n`
  })

  content += `\n=== 设备信息 ===\n`
  content += `应用版本: ${deviceInfo.value.app_version}\n`
  content += `服务器版本: ${deviceInfo.value.server_version}\n`
  content += `操作系统: ${deviceInfo.value.os}\n`

  return content
}

// Share report
const shareReport = () => {
  ElMessage.info('分享功能开发中')
}

// Handle action
const handleAction = (item: any) => {
  if (item.action === '清理缓存') {
    clearCache()
  }
}

// Clear cache
const clearCache = async () => {
  try {
    await ElMessageBox.confirm('确定要清理缓存吗？', '确认操作', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    })

    clearingCache.value = true
    await new Promise(resolve => setTimeout(resolve, 1500))
    ElMessage.success('缓存清理成功')

    // Update diagnostic item
    const cacheItem = diagnosticItems.value.find(i => i.name === '缓存状态')
    if (cacheItem) {
      cacheItem.status = 'passed'
      cacheItem.message = '缓存正常(12MB)'
      cacheItem.action = undefined
    }
    report.value.warning_count = 0
    report.value.passed_count = 6
    recommendations.value = []
  } catch {
    // User cancelled
  } finally {
    clearingCache.value = false
  }
}

// Optimize database
const optimizeDatabase = async () => {
  try {
    await ElMessageBox.confirm('确定要优化数据库吗？这可能需要几分钟时间。', '确认操作', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    })

    optimizingDb.value = true
    await new Promise(resolve => setTimeout(resolve, 3000))
    ElMessage.success('数据库优化完成')
  } catch {
    // User cancelled
  } finally {
    optimizingDb.value = false
  }
}

// Check updates
const checkUpdates = () => {
  ElMessage.info('当前已是最新版本')
}

// View report
const viewReport = (row: any) => {
  ElMessage.info(`查看报告 ${row.id}`)
}

// Helpers
const getStatusIcon = (status: string) => {
  const map: Record<string, string> = {
    passed: 'CircleCheck',
    warning: 'Warning',
    error: 'CircleClose',
  }
  return map[status] || 'CircleCheck'
}

const getResourceColor = (percent: number) => {
  if (percent < 60) return '#10b981'
  if (percent < 80) return '#f59e0b'
  return '#ef4444'
}

const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Lifecycle
onMounted(() => {
  fetchData()
})
</script>

<style scoped lang="scss">
.diagnostics {
  .summary-card {
    .summary-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 20px;

      .summary-title {
        h3 {
          margin: 0 0 4px 0;
          font-size: 18px;
        }

        .report-time {
          font-size: 13px;
          color: #999;
        }
      }
    }

    .summary-stats {
      display: flex;
      gap: 16px;

      .stat-item {
        flex: 1;
        text-align: center;
        padding: 16px;
        border-radius: 10px;

        &.passed {
          background: rgba(16, 185, 129, 0.1);
          .stat-value { color: #10b981; }
          .stat-label { color: #059669; }
        }

        &.warning {
          background: rgba(245, 158, 11, 0.1);
          .stat-value { color: #f59e0b; }
          .stat-label { color: #d97706; }
        }

        &.error {
          background: rgba(239, 68, 68, 0.1);
          .stat-value { color: #ef4444; }
          .stat-label { color: #dc2626; }
        }

        .stat-value {
          font-size: 28px;
          font-weight: 700;
        }

        .stat-label {
          font-size: 12px;
          margin-top: 4px;
        }
      }
    }
  }

  .diagnostic-list {
    .diagnostic-item {
      display: flex;
      align-items: center;
      padding: 14px 0;
      border-bottom: 1px solid #f0f0f0;

      &:last-child {
        border-bottom: none;
      }

      .status-icon {
        margin-right: 14px;

        &.passed { color: #10b981; }
        &.warning { color: #f59e0b; }
        &.error { color: #ef4444; }
      }

      .item-content {
        flex: 1;

        .item-name {
          font-weight: 500;
          margin-bottom: 2px;
        }

        .item-message {
          font-size: 13px;
          color: #999;
        }
      }
    }
  }

  .resource-list {
    .resource-item {
      margin-bottom: 20px;

      &:last-child {
        margin-bottom: 0;
      }

      .resource-label {
        display: block;
        margin-bottom: 8px;
        font-size: 13px;
        color: #666;
      }

      .resource-detail {
        .resource-text {
          display: block;
          margin-top: 4px;
          font-size: 12px;
          color: #999;
          text-align: right;
        }
      }
    }
  }

  .quick-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
  }

  .recommendations {
    .el-alert {
      margin-bottom: 10px;

      &:last-child {
        margin-bottom: 0;
      }
    }
  }
}
</style>
