import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '@/stores/auth'
import * as authApi from '@/api/auth'

vi.mock('@/api/auth')

describe('Auth Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    localStorage.clear()
  })

  describe('initial state', () => {
    it('should have null token when not logged in', () => {
      const store = useAuthStore()
      expect(store.token).toBeNull()
      expect(store.admin).toBeNull()
      expect(store.isLoggedIn).toBe(false)
    })

    it('should load token from localStorage', () => {
      vi.mocked(localStorage.getItem).mockReturnValue('test-token')
      const store = useAuthStore()
      expect(store.token).toBe('test-token')
      expect(store.isLoggedIn).toBe(true)
    })
  })

  describe('login', () => {
    it('should login successfully', async () => {
      const mockResponse = {
        access_token: 'new-token',
        admin: {
          id: '1',
          username: 'admin',
          permissions: ['user:list', 'user:detail'],
        },
      }
      vi.mocked(authApi.login).mockResolvedValue(mockResponse)

      const store = useAuthStore()
      await store.login('admin', 'password')

      expect(store.token).toBe('new-token')
      expect(store.admin).toEqual(mockResponse.admin)
      expect(store.isLoggedIn).toBe(true)
      expect(localStorage.setItem).toHaveBeenCalledWith('admin_token', 'new-token')
    })

    it('should handle login failure', async () => {
      vi.mocked(authApi.login).mockRejectedValue(new Error('Invalid credentials'))

      const store = useAuthStore()
      await expect(store.login('admin', 'wrong')).rejects.toThrow()
      expect(store.token).toBeNull()
    })
  })

  describe('logout', () => {
    it('should clear state on logout', async () => {
      const store = useAuthStore()
      store.setToken('test-token')
      store.setAdmin({ id: '1', username: 'admin' } as any)

      await store.logout()

      expect(store.token).toBeNull()
      expect(store.admin).toBeNull()
      expect(localStorage.removeItem).toHaveBeenCalledWith('admin_token')
    })
  })

  describe('permissions', () => {
    it('should check permissions correctly', () => {
      const store = useAuthStore()
      store.setAdmin({
        id: '1',
        username: 'admin',
        permissions: ['user:list', 'user:detail'],
        is_superadmin: false,
      } as any)

      expect(store.hasPermission('user:list')).toBe(true)
      expect(store.hasPermission('admin:list')).toBe(false)
    })

    it('should allow all permissions for superadmin', () => {
      const store = useAuthStore()
      store.setAdmin({
        id: '1',
        username: 'superadmin',
        permissions: [],
        is_superadmin: true,
      } as any)

      expect(store.hasPermission('any:permission')).toBe(true)
    })

    it('should check any permission correctly', () => {
      const store = useAuthStore()
      store.setAdmin({
        id: '1',
        username: 'admin',
        permissions: ['user:list'],
        is_superadmin: false,
      } as any)

      expect(store.hasAnyPermission(['user:list', 'admin:list'])).toBe(true)
      expect(store.hasAnyPermission(['admin:list', 'settings:view'])).toBe(false)
    })
  })
})
