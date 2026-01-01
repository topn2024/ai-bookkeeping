import { post, get, put, del } from './request'
import type { LoginForm, LoginResponse, AdminUser } from '@/types'

// Auth APIs
export const login = (data: LoginForm): Promise<LoginResponse> => {
  return post('/auth/login', data)
}

export const logout = (): Promise<void> => {
  return post('/auth/logout')
}

export const refreshToken = (refresh_token: string): Promise<{ access_token: string; token_type: string; expires_in: number }> => {
  return post('/auth/refresh', { refresh_token })
}

export const getCurrentAdmin = (): Promise<AdminUser> => {
  return get('/admins/me')
}

export const updateProfile = (data: Partial<AdminUser>): Promise<any> => {
  return put('/admins/me', data)
}

export const changePassword = (data: { current_password: string; new_password: string }): Promise<any> => {
  return post('/admins/me/change-password', data)
}

// MFA APIs
export const setupMFA = (): Promise<{ secret: string; qr_code_url: string; backup_codes: string[] }> => {
  return post('/admins/me/mfa/setup')
}

export const verifyMFA = (code: string): Promise<any> => {
  return post('/admins/me/mfa/verify', { code })
}

export const disableMFA = (password: string): Promise<any> => {
  return del(`/admins/me/mfa?password=${encodeURIComponent(password)}`)
}

export const getMFAStatus = (): Promise<{ mfa_enabled: boolean; backup_codes_remaining: number }> => {
  return get('/admins/me/mfa/status')
}

// Notification preferences
export const getNotificationPrefs = (): Promise<any> => {
  return get('/admins/me/notifications')
}

export const updateNotificationPrefs = (data: any): Promise<any> => {
  return put('/admins/me/notifications', data)
}

// Profile management
export const getProfile = (): Promise<AdminUser> => {
  return get('/admins/me')
}

export const getLoginHistory = (params?: { page?: number; page_size?: number }): Promise<any> => {
  return get('/admins/me/login-history', { params })
}

export const uploadAvatar = (file: File): Promise<{ avatar_url: string }> => {
  const formData = new FormData()
  formData.append('file', file)
  return post('/admins/me/avatar', formData)
}
