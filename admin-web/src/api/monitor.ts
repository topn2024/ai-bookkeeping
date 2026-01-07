import { get, put, post, del } from './request'
import type { SystemHealth, SystemResources } from '@/types'

// Health check
export const getSystemHealth = (): Promise<SystemHealth> => {
  return get('/monitoring/health')
}

// Database status
export const getDatabaseStats = (): Promise<any> => {
  return get('/monitoring/database')
}

// Storage status
export const getStorageStats = (): Promise<any> => {
  return get('/monitoring/storage')
}

// System resources
export const getSystemResources = (): Promise<SystemResources> => {
  return get('/monitoring/resources')
}

// API metrics
export const getAPIMetrics = (hours: number = 24): Promise<any> => {
  return get('/monitoring/api-metrics', { params: { hours } })
}

// Error stats
export const getErrorStats = (hours: number = 24): Promise<any> => {
  return get('/monitoring/errors', { params: { hours } })
}

// Slow queries
export const getSlowQueries = (params: {
  hours?: number
  min_duration_ms?: number
  limit?: number
}): Promise<any> => {
  return get('/monitoring/slow-queries', { params })
}

// Alert rules
export const getAlertRules = (): Promise<any> => {
  return get('/monitoring/alerts/rules')
}

export const updateAlertRule = (ruleId: string, data: {
  threshold?: number
  enabled?: boolean
}): Promise<any> => {
  return put(`/monitoring/alerts/rules/${ruleId}`, data)
}

// Notification config
export const getNotificationConfig = (): Promise<any> => {
  return get('/monitoring/alerts/notifications')
}

export const updateNotificationConfig = (config: any): Promise<any> => {
  return put('/monitoring/alerts/notifications', config)
}

// Health events
export const getHealthEvents = (params?: { hours?: number; limit?: number }): Promise<any> => {
  return get('/monitoring/health/events', { params })
}

// Resource trends
export const getResourceTrends = (hours: number = 24): Promise<any> => {
  return get('/monitoring/resources/trends', { params: { hours } })
}

// Active alerts
export const getActiveAlerts = (params?: { severity?: string; limit?: number }): Promise<any> => {
  return get('/monitoring/alerts/active', { params })
}

export const acknowledgeAlert = (alertId: string): Promise<any> => {
  return put(`/monitoring/alerts/${alertId}/acknowledge`)
}

export const resolveAlert = (alertId: string): Promise<any> => {
  return put(`/monitoring/alerts/${alertId}/resolve`)
}

export const acknowledgeAllAlerts = (): Promise<any> => {
  return put('/monitoring/alerts/acknowledge-all')
}

// Alert rule management
export const createAlertRule = (data: any): Promise<any> => {
  return post('/monitoring/alerts/rules', data)
}

export const toggleAlertRule = (ruleId: string, enabled: boolean): Promise<any> => {
  return put(`/monitoring/alerts/rules/${ruleId}`, { enabled })
}

export const deleteAlertRule = (ruleId: string): Promise<any> => {
  return del(`/monitoring/alerts/rules/${ruleId}`)
}

// System logs
export const getSystemLogs = (params?: {
  page?: number
  page_size?: number
  level?: string
  keyword?: string
  source?: string
  start_time?: string
  end_time?: string
}): Promise<any> => {
  return get('/monitoring/logs', { params })
}

// AI service monitoring
export const getAIServiceStatus = (): Promise<any> => {
  return get('/monitoring/ai-service/status')
}

export const getAICalls = (params?: {
  type?: string
  limit?: number
}): Promise<any> => {
  return get('/monitoring/ai-service/calls', { params })
}

// Diagnostics
export const getDiagnosticReport = (): Promise<any> => {
  return get('/monitoring/diagnostics')
}

export const runDiagnostics = (): Promise<any> => {
  return post('/monitoring/diagnostics/run')
}
