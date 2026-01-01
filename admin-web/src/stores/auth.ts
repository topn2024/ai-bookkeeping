import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { AdminUser } from '@/types'
import * as authApi from '@/api/auth'

export const useAuthStore = defineStore('auth', () => {
  // State
  const token = ref<string | null>(localStorage.getItem('admin_token'))
  const refreshToken = ref<string | null>(localStorage.getItem('admin_refresh_token'))
  const admin = ref<AdminUser | null>(null)

  // Getters
  const isLoggedIn = computed(() => !!token.value)
  const permissions = computed(() => admin.value?.permissions || [])
  const isSuperAdmin = computed(() => admin.value?.is_superadmin || false)

  // Actions
  const setToken = (newToken: string) => {
    token.value = newToken
    localStorage.setItem('admin_token', newToken)
  }

  const setRefreshToken = (newRefreshToken: string) => {
    refreshToken.value = newRefreshToken
    localStorage.setItem('admin_refresh_token', newRefreshToken)
  }

  const refreshAccessToken = async (): Promise<boolean> => {
    if (!refreshToken.value) return false
    try {
      const response = await authApi.refreshToken(refreshToken.value)
      setToken(response.access_token)
      return true
    } catch (e) {
      // Refresh failed, clear tokens
      return false
    }
  }

  const setAdmin = (newAdmin: AdminUser) => {
    admin.value = newAdmin
  }

  const login = async (username: string, password: string, mfaCode?: string) => {
    const response = await authApi.login({ username, password, mfa_code: mfaCode })
    setToken(response.access_token)
    if (response.refresh_token) {
      setRefreshToken(response.refresh_token)
    }
    setAdmin(response.admin)
    return response
  }

  const logout = async () => {
    try {
      await authApi.logout()
    } catch (e) {
      // Ignore logout errors
    }
    token.value = null
    refreshToken.value = null
    admin.value = null
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_refresh_token')
  }

  const fetchCurrentAdmin = async () => {
    if (!token.value) return null
    try {
      const adminData = await authApi.getCurrentAdmin()
      admin.value = adminData as AdminUser
      return adminData
    } catch (e) {
      logout()
      return null
    }
  }

  const hasPermission = (permission: string): boolean => {
    if (isSuperAdmin.value) return true
    return permissions.value.includes(permission)
  }

  const hasAnyPermission = (perms: string[]): boolean => {
    if (isSuperAdmin.value) return true
    return perms.some(p => permissions.value.includes(p))
  }

  return {
    token,
    refreshToken,
    admin,
    isLoggedIn,
    permissions,
    isSuperAdmin,
    setToken,
    setRefreshToken,
    setAdmin,
    login,
    logout,
    fetchCurrentAdmin,
    refreshAccessToken,
    hasPermission,
    hasAnyPermission,
  }
})
