import { get, post, put, del, download } from './request'
import type { PaginatedResponse, Transaction, TransactionStats } from '@/types'

// Transaction APIs
export const getTransactions = (params: {
  page?: number
  page_size?: number
  user_id?: string
  transaction_type?: number
  min_amount?: number
  max_amount?: number
  start_date?: string
  end_date?: string
  source?: number
  keyword?: string
  sort_by?: string
  sort_order?: string
}): Promise<PaginatedResponse<Transaction>> => {
  return get('/transactions', { params })
}

export const getTransactionDetail = (txId: string): Promise<Transaction> => {
  return get(`/transactions/${txId}`)
}

export const getTransactionStats = (params: {
  start_date?: string
  end_date?: string
  user_id?: string
}): Promise<TransactionStats> => {
  return get('/transactions/stats', { params })
}

export const getAbnormalTransactions = (days: number = 7): Promise<any> => {
  return get('/transactions/abnormal', { params: { days } })
}

export const exportTransactions = (params: {
  format?: string
  user_id?: string
  transaction_type?: number
  start_date?: string
  end_date?: string
  include_details?: boolean
}): Promise<Blob> => {
  return download('/transactions/export', params)
}

// Book APIs - 后端路由在 /data 下
export const getBooks = (params: {
  page?: number
  page_size?: number
  user_id?: string
  search?: string
}): Promise<PaginatedResponse<any>> => {
  return get('/data/books', { params })
}

export const getBookDetail = (bookId: string): Promise<any> => {
  return get(`/data/books/${bookId}`)
}

export const getBookStats = (): Promise<any> => {
  return get('/data/books/stats')
}

// Account APIs - 后端路由在 /data 下
export const getAccounts = (params: {
  page?: number
  page_size?: number
  user_id?: string
  account_type?: string
}): Promise<PaginatedResponse<any>> => {
  return get('/data/accounts', { params })
}

export const getAccountTypeStats = (): Promise<any> => {
  return get('/data/accounts/stats')
}

// Category APIs
export const getCategories = (params: {
  page?: number
  page_size?: number
  category_type?: number
  is_system?: boolean
}): Promise<PaginatedResponse<any>> => {
  return get('/categories', { params })
}

export const createCategory = (data: any): Promise<any> => {
  return post('/categories', data)
}

export const updateCategory = (categoryId: string, data: any): Promise<any> => {
  return put(`/categories/${categoryId}`, data)
}

export const deleteCategory = (categoryId: string): Promise<any> => {
  return del(`/categories/${categoryId}`)
}

export const getCategoryUsageStats = (): Promise<any> => {
  return get('/categories/stats/usage')
}

// Backup APIs
export const getBackups = (params: {
  page?: number
  page_size?: number
  user_id?: string
  backup_type?: number
  start_date?: string
  end_date?: string
}): Promise<PaginatedResponse<any> & { stats?: any }> => {
  return get('/backups', { params })
}

export const getBackupStorageStats = (): Promise<any> => {
  return get('/backups/storage/stats')
}

export const cleanupExpiredBackups = (days: number): Promise<any> => {
  return post('/backups/cleanup', { retention_days: days })
}

export const getBackupPolicy = (): Promise<any> => {
  return get('/backups/policy')
}

export const updateBackupPolicy = (data: any): Promise<any> => {
  return put('/backups/policy', data)
}

// Data integrity
export const checkDataIntegrity = (): Promise<any> => {
  return get('/data/integrity-check')
}

// Category detail
export const getCategoryDetail = (categoryId: string): Promise<any> => {
  return get(`/categories/${categoryId}`)
}

// Backup operations
export const createBackup = (data: { user_id?: string; description?: string }): Promise<any> => {
  return post('/backups', data)
}

export const downloadBackup = (backupId: string): Promise<Blob> => {
  return download(`/backups/${backupId}/download`, {})
}

export const restoreBackup = (backupId: string): Promise<any> => {
  return post(`/backups/${backupId}/restore`)
}

export const deleteBackup = (backupId: string): Promise<any> => {
  return del(`/backups/${backupId}`)
}
