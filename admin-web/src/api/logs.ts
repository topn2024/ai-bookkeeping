import { get, download } from './request'
import type { PaginatedResponse, AuditLog } from '@/types'

// Audit logs
export const getLogs = (params: {
  page?: number
  page_size?: number
  admin_id?: string
  action?: string
  module?: string
  start_date?: string
  end_date?: string
}): Promise<PaginatedResponse<AuditLog>> => {
  return get('/logs', { params })
}

export const getLogDetail = (logId: string): Promise<AuditLog> => {
  return get(`/logs/${logId}`)
}

export const getLogActions = (): Promise<{ actions: Record<string, string> }> => {
  return get('/logs/actions')
}

export const getLogModules = (): Promise<{ modules: string[] }> => {
  return get('/logs/modules')
}

export const getLogStats = (days: number = 7): Promise<any> => {
  return get('/logs/stats', { params: { days } })
}

export const exportLogs = (params: {
  format?: string
  admin_id?: string
  action?: string
  module?: string
  start_date?: string
  end_date?: string
}): Promise<Blob> => {
  return download('/logs/export', params)
}
