import { post, get, put, del } from './request'
import type { LoginForm, LoginResponse, AdminUser } from '@/types'

// Auth APIs
export const login = (data: LoginForm): Promise<LoginResponse> => {
  return post('/auth/login', data)
}

export const logout = (): Promise<void> => {
  return post('/auth/logout')
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
