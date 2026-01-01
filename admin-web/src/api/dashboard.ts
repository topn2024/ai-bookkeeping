import { get } from './request'
import type { DashboardStats, HeatmapData } from '@/types'

// Dashboard APIs
export const getStats = (): Promise<DashboardStats> => {
  return get('/dashboard/stats')
}

// Alias for component compatibility
export const getDashboardStats = getStats

// 用户增长趋势 - 使用 period 参数 (7d, 30d, 90d)
export const getUserTrend = (period: string = '7d'): Promise<any> => {
  return get('/dashboard/trend/users', { params: { period } })
}

// 交易趋势 - 使用 period 参数
export const getTransactionTrend = (period: string = '7d'): Promise<any> => {
  return get('/dashboard/trend/transactions', { params: { period } })
}

// 交易类型分布
export const getTypeDistribution = (period: string = '30d'): Promise<any> => {
  return get('/dashboard/distribution/transaction-type', { params: { period } })
}

// 活跃热力图
export const getActivityHeatmap = (days: number = 30): Promise<HeatmapData> => {
  return get('/dashboard/heatmap/activity', { params: { days } })
}

// TOP活跃用户
export const getTopActiveUsers = (period: string = '30d', limit: number = 10): Promise<any> => {
  return get('/dashboard/top-users', { params: { period, limit } })
}

// 最近交易
export const getRecentTransactions = (limit: number = 10): Promise<any> => {
  return get('/dashboard/recent-transactions', { params: { limit } })
}

// 快速统计 - 使用 stats 端点
export const getQuickStats = (): Promise<any> => {
  return get('/dashboard/stats')
}

// 获取最近注册用户
export const getRecentUsers = (limit: number = 10): Promise<any> => {
  return get('/dashboard/recent-users', { params: { limit } })
}

// 获取最近活动 - 组合最近用户和交易数据
export const getRecentActivity = async (): Promise<{
  recent_users: any[]
  recent_transactions: any[]
}> => {
  const [usersRes, transactionsRes] = await Promise.all([
    get('/dashboard/recent-users', { params: { limit: 10 } }),
    get('/dashboard/recent-transactions', { params: { limit: 10 } })
  ])
  return {
    recent_users: usersRes.items || [],
    recent_transactions: transactionsRes.items || []
  }
}
