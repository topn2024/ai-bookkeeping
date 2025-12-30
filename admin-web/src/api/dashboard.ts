import { get } from './request'
import type { DashboardStats, TrendData, HeatmapData, PaginatedResponse, Transaction } from '@/types'

// Dashboard APIs
export const getStats = (): Promise<DashboardStats> => {
  return get('/dashboard/stats')
}

// Alias for component compatibility
export const getDashboardStats = getStats

export const getUserTrend = (days: number = 7): Promise<{ days: number; trend: TrendData[] }> => {
  return get('/dashboard/trends/users', { params: { days } })
}

export const getTransactionTrend = (days: number = 7): Promise<any> => {
  return get('/dashboard/trends/transactions', { params: { days } })
}

export const getTypeDistribution = (days: number = 30): Promise<any> => {
  return get('/dashboard/distribution/types', { params: { days } })
}

export const getActivityHeatmap = (days: number = 30): Promise<HeatmapData> => {
  return get('/dashboard/heatmap/activity', { params: { days } })
}

export const getTopActiveUsers = (days: number = 7, limit: number = 10): Promise<any> => {
  return get('/dashboard/rankings/active-users', { params: { days, limit } })
}

export const getRecentTransactions = (limit: number = 10): Promise<PaginatedResponse<Transaction>> => {
  return get('/dashboard/recent/transactions', { params: { limit } })
}

export const getQuickStats = (): Promise<any> => {
  return get('/dashboard/quick-stats')
}

// Get recent activity (users and transactions)
export const getRecentActivity = (): Promise<{
  recent_users: any[]
  recent_transactions: any[]
}> => {
  return get('/dashboard/recent-activity')
}
