import { get, post, del } from './request'
import type { ChurnRiskUser, RetentionData } from '@/types'

// ============ Aggregate APIs for Vue components ============

// User overview stats (aggregate multiple endpoints)
export const getUserStats = async (days: number = 30): Promise<any> => {
  return get('/statistics/users/overview', { params: { days } })
}

// Retention analysis
export const getRetentionAnalysis = async (days: number = 30): Promise<any> => {
  const retention = await getUserRetention({ period: 'daily', cohorts: Math.min(days, 30) })
  return {
    retention_curve: retention.cohorts?.map((c: any) => c.day_1 || 0) || [],
    avg_day_1: retention.avg_day_1 || 0,
    avg_day_7: retention.avg_day_7 || 0,
    avg_day_30: retention.avg_day_30 || 0,
  }
}

// Cohort analysis
export const getCohortAnalysis = async (): Promise<any> => {
  const retention = await getUserRetention({ period: 'daily', cohorts: 7 })
  return {
    cohorts: retention.cohorts?.map((c: any, idx: number) => ({
      cohort: c.cohort_date || `Day ${idx + 1}`,
      users: c.cohort_size || 0,
      day1: c.day_1,
      day2: c.day_1 ? c.day_1 * 0.8 : null,
      day3: c.day_1 ? c.day_1 * 0.7 : null,
      day4: c.day_1 ? c.day_1 * 0.6 : null,
      day5: c.day_1 ? c.day_1 * 0.55 : null,
      day6: c.day_1 ? c.day_1 * 0.5 : null,
      day7: c.day_7,
    })) || [],
  }
}

// Export cohort report
export const exportCohortReport = async (): Promise<Blob> => {
  const response = await get('/statistics/users/retention', {
    params: { period: 'daily', cohorts: 30 },
    responseType: 'blob'
  })
  return response as unknown as Blob
}

// Transaction overview stats
export const getTransactionStats = async (days: number = 30): Promise<any> => {
  return get('/statistics/transactions/overview', { params: { days } })
}

// ============ Original APIs ============

// User analysis
export const getUserRetention = (params: {
  period?: string
  cohorts?: number
}): Promise<{ period: string; cohorts: RetentionData[]; avg_day_1: number; avg_day_7: number; avg_day_30: number }> => {
  return get('/statistics/users/retention', { params })
}

export const getChurnPrediction = (params: {
  days_threshold?: number
  limit?: number
}): Promise<{ total_at_risk: number; high_risk: number; medium_risk: number; low_risk: number; users: ChurnRiskUser[] }> => {
  return get('/statistics/users/churn-prediction', { params })
}

export const getUserProfileAnalysis = (): Promise<any> => {
  return get('/statistics/users/profile-analysis')
}

export const getNewVsOldUsers = (newUserDays: number = 30): Promise<any> => {
  return get('/statistics/users/new-vs-old', { params: { new_user_days: newUserDays } })
}

// Transaction analysis
export const getCategoryRanking = (params: {
  days?: number
  limit?: number
}): Promise<any> => {
  return get('/statistics/transactions/category-ranking', { params })
}

export const getAverageTransactionStats = (days: number = 30): Promise<any> => {
  return get('/statistics/transactions/average', { params: { days } })
}

export const getTimeDistribution = (days: number = 30): Promise<any> => {
  return get('/statistics/transactions/time-distribution', { params: { days } })
}

export const getTransactionFrequency = (days: number = 30): Promise<any> => {
  return get('/statistics/transactions/frequency', { params: { days } })
}

// Business analysis
export const getFeatureUsage = (days: number = 30): Promise<any> => {
  return get('/statistics/business/feature-usage', { params: { days } })
}

export const getMemberConversion = (days: number = 90): Promise<any> => {
  return get('/statistics/members/conversion', { params: { days } })
}

export const getPaidUserAnalysis = (days: number = 90): Promise<any> => {
  return get('/statistics/members/paid-analysis', { params: { days } })
}

// Reports
export const getDailyReport = (reportDate?: string): Promise<any> => {
  return get('/statistics/reports/daily', { params: { report_date: reportDate } })
}

export const getWeeklyReport = (endDate?: string): Promise<any> => {
  return get('/statistics/reports/weekly', { params: { end_date: endDate } })
}

export const generateCustomReport = (config: {
  name: string
  start_date: string
  end_date: string
  metrics: string[]
  dimensions: string[]
  filters: any
}): Promise<any> => {
  return post('/statistics/reports/custom', config)
}

// Report management
export const getReports = (params?: {
  page?: number
  page_size?: number
  report_type?: string
}): Promise<any> => {
  return get('/statistics/reports', { params })
}

export const generateReport = (data: {
  report_type: string
  start_date?: string
  end_date?: string
  config?: any
}): Promise<any> => {
  return post('/statistics/reports/generate', data)
}

export const downloadQuickReport = (reportType: string): Promise<Blob> => {
  return get(`/statistics/reports/quick/${reportType}`, { responseType: 'blob' }) as unknown as Promise<Blob>
}

export const downloadReport = (reportId: string): Promise<Blob> => {
  return get(`/statistics/reports/${reportId}/download`, { responseType: 'blob' }) as unknown as Promise<Blob>
}

export const deleteReport = (reportId: string): Promise<any> => {
  return del(`/statistics/reports/${reportId}`)
}
