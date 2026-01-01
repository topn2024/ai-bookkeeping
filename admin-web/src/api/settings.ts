import { get, put, post, del } from './request'
import type { PaginatedResponse, AdminUser } from '@/types'

// System settings
export const getSystemInfo = (): Promise<any> => {
  return get('/settings/system-info')
}

export const updateSystemInfo = (data: any): Promise<any> => {
  return put('/settings/system-info', data)
}

// Registration settings
export const getRegistrationConfig = (): Promise<any> => {
  return get('/settings/registration')
}

export const updateRegistrationConfig = (data: any): Promise<any> => {
  return put('/settings/registration', data)
}

// Email settings
export const getEmailConfig = (): Promise<any> => {
  return get('/settings/email-service')
}

export const updateEmailConfig = (data: any): Promise<any> => {
  return put('/settings/email-service', data)
}

export const testEmailConfig = (): Promise<any> => {
  return post('/settings/email-service/test')
}

// SMS settings
export const getSMSConfig = (): Promise<any> => {
  return get('/settings/sms-service')
}

export const updateSMSConfig = (data: any): Promise<any> => {
  return put('/settings/sms-service', data)
}

// AI settings
export const getAIConfig = (): Promise<any> => {
  return get('/settings/ai-service')
}

export const updateAIConfig = (data: any): Promise<any> => {
  return put('/settings/ai-service', data)
}

// Quota settings
export const getQuotaConfig = (): Promise<any> => {
  return get('/settings/ai-quota')
}

export const updateQuotaConfig = (data: any): Promise<any> => {
  return put('/settings/ai-quota', data)
}

// Security settings
export const getLoginSecurityConfig = (): Promise<any> => {
  return get('/settings/login-security')
}

export const updateLoginSecurityConfig = (data: any): Promise<any> => {
  return put('/settings/login-security', data)
}

export const getIPWhitelist = (): Promise<any> => {
  return get('/settings/ip-whitelist')
}

export const updateIPWhitelist = (data: any): Promise<any> => {
  return put('/settings/ip-whitelist', data)
}

export const getOperationConfirmConfig = (): Promise<any> => {
  return get('/settings/operation-confirm')
}

export const updateOperationConfirmConfig = (data: any): Promise<any> => {
  return put('/settings/operation-confirm', data)
}

// Admin management
export const getAdmins = (params: {
  page?: number
  page_size?: number
}): Promise<PaginatedResponse<AdminUser>> => {
  return get('/admins', { params })
}

export const createAdmin = (data: {
  username: string
  email: string
  password: string
  display_name?: string
  phone?: string
  role_id: string
}): Promise<AdminUser> => {
  return post('/admins', data)
}

export const getAdminDetail = (adminId: string): Promise<AdminUser> => {
  return get(`/admins/${adminId}`)
}

export const updateAdmin = (adminId: string, data: any): Promise<AdminUser> => {
  return put(`/admins/${adminId}`, data)
}

export const deleteAdmin = (adminId: string): Promise<any> => {
  return del(`/admins/${adminId}`)
}

// Roles
export const getRoles = (): Promise<any> => {
  return get('/admins/roles/list')
}

export const getPermissions = (): Promise<any> => {
  return get('/admins/permissions/list')
}

export const initAdminData = (): Promise<any> => {
  return post('/admins/init-data')
}

// System settings (aggregate)
export const getSystemSettings = (): Promise<any> => {
  return get('/settings/all')
}

export const updateSystemSettings = (section: string, data: any): Promise<any> => {
  return put(`/settings/${section}`, data)
}

// Logo upload
export const uploadLogo = (file: File): Promise<any> => {
  const formData = new FormData()
  formData.append('file', file)
  return post('/settings/logo', formData)
}

// Email test
export const testEmailSettings = (email?: string): Promise<any> => {
  return post('/settings/email-service/test', { email })
}

// Webhook test
export const testWebhook = (url: string): Promise<any> => {
  return post('/settings/webhook/test', { url })
}

// Security settings (aggregate)
export const getSecuritySettings = (): Promise<any> => {
  return get('/settings/security')
}

export const updateSecuritySettings = (data: any): Promise<any> => {
  return put('/settings/security', data)
}

// Admin password reset
export const resetAdminPassword = (adminId: string): Promise<any> => {
  return post(`/admins/${adminId}/reset-password`)
}

// Admin status toggle
export const toggleAdminStatus = (adminId: string, isActive: boolean): Promise<any> => {
  return put(`/admins/${adminId}/status`, { is_active: isActive })
}
