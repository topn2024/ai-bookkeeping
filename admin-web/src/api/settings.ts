import { get, put, post, del } from './request'
import type { PaginatedResponse, AdminUser } from '@/types'

// System settings
export const getSystemInfo = (): Promise<any> => {
  return get('/settings/system')
}

export const updateSystemInfo = (data: any): Promise<any> => {
  return put('/settings/system', data)
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
  return get('/settings/email')
}

export const updateEmailConfig = (data: any): Promise<any> => {
  return put('/settings/email', data)
}

export const testEmailConfig = (): Promise<any> => {
  return post('/settings/email/test')
}

// SMS settings
export const getSMSConfig = (): Promise<any> => {
  return get('/settings/sms')
}

export const updateSMSConfig = (data: any): Promise<any> => {
  return put('/settings/sms', data)
}

// AI settings
export const getAIConfig = (): Promise<any> => {
  return get('/settings/ai')
}

export const updateAIConfig = (data: any): Promise<any> => {
  return put('/settings/ai', data)
}

// Quota settings
export const getQuotaConfig = (): Promise<any> => {
  return get('/settings/quota')
}

export const updateQuotaConfig = (data: any): Promise<any> => {
  return put('/settings/quota', data)
}

// Security settings
export const getLoginSecurityConfig = (): Promise<any> => {
  return get('/settings/security/login')
}

export const updateLoginSecurityConfig = (data: any): Promise<any> => {
  return put('/settings/security/login', data)
}

export const getIPWhitelist = (): Promise<any> => {
  return get('/settings/security/ip-whitelist')
}

export const updateIPWhitelist = (data: any): Promise<any> => {
  return put('/settings/security/ip-whitelist', data)
}

export const getOperationConfirmConfig = (): Promise<any> => {
  return get('/settings/security/operation-confirm')
}

export const updateOperationConfirmConfig = (data: any): Promise<any> => {
  return put('/settings/security/operation-confirm', data)
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
