import { get, post } from './request'
import type { RetentionData, ChurnRiskUser } from '@/types'

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
