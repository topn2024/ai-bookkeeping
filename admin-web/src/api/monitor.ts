import { get, put } from './request'
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
