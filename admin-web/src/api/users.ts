import { get, post, put, del, download } from './request'
import type { PaginatedResponse, AppUser, UserDetail, UserBehaviorAnalysis } from '@/types'

// User list APIs
export const getUsers = (params: {
  page?: number
  page_size?: number
  search?: string
  is_active?: boolean
  sort_by?: string
  sort_order?: string
}): Promise<PaginatedResponse<AppUser>> => {
  return get('/users', { params })
}

export const getUserDetail = (userId: string): Promise<UserDetail> => {
  return get(`/users/${userId}`)
}

export const getUserTransactions = (userId: string, params: {
  page?: number
  page_size?: number
}): Promise<PaginatedResponse<any>> => {
  return get(`/users/${userId}/transactions`, { params })
}

export const getUserLoginHistory = (userId: string, params: {
  page?: number
  page_size?: number
}): Promise<PaginatedResponse<any>> => {
  return get(`/users/${userId}/login-history`, { params })
}

export const getUserBehaviorAnalysis = (userId: string, days: number = 30): Promise<UserBehaviorAnalysis> => {
  return get(`/users/${userId}/behavior-analysis`, { params: { days } })
}

// User operations
export const updateUserStatus = (userId: string, data: { is_active: boolean; reason?: string }): Promise<any> => {
  return put(`/users/${userId}/status`, data)
}

// Convenience functions for disable/enable
export const disableUser = (userId: string, reason?: string): Promise<any> => {
  return updateUserStatus(userId, { is_active: false, reason })
}

export const enableUser = (userId: string): Promise<any> => {
  return updateUserStatus(userId, { is_active: true })
}

export const resetUserPassword = (userId: string): Promise<any> => {
  return post(`/users/${userId}/reset-password`)
}

export const clearUserSessions = (userId: string): Promise<any> => {
  return post(`/users/${userId}/clear-sessions`)
}

export const deleteUser = (userId: string, hardDelete: boolean = false): Promise<any> => {
  return del(`/users/${userId}`, { params: { hard_delete: hardDelete } })
}

// Batch operations
export const batchOperation = (data: { user_ids: string[]; operation: string }): Promise<any> => {
  return post('/users/batch-operation', data)
}

// Export
export const exportUsers = (params: {
  format?: string
  include_stats?: boolean
  is_active?: boolean
}): Promise<Blob> => {
  return download('/users/export', params)
}
