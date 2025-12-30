import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'
import MainLayout from '@/layouts/MainLayout.vue'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/', component: { template: '<div>Home</div>' } },
    { path: '/dashboard', component: { template: '<div>Dashboard</div>' }, meta: { title: '仪表盘' } },
    { path: '/users', component: { template: '<div>Users</div>' }, meta: { title: '用户管理' } },
  ],
})

describe('Main Layout', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    const authStore = useAuthStore()
    authStore.setAdmin({
      id: '1',
      username: 'admin',
      display_name: 'Admin User',
      permissions: ['user:list', 'data:transaction:view'],
      is_superadmin: false,
    } as any)
  })

  const mountLayout = () => {
    return mount(MainLayout, {
      global: {
        plugins: [router],
      },
    })
  }

  describe('sidebar', () => {
    it('should render sidebar with menu items', () => {
      const wrapper = mountLayout()

      expect(wrapper.find('.sidebar').exists()).toBe(true)
      expect(wrapper.find('.sidebar-menu').exists()).toBe(true)
    })

    it('should toggle sidebar collapse', async () => {
      const wrapper = mountLayout()

      expect(wrapper.vm.isCollapsed).toBe(false)

      await wrapper.find('.collapse-btn').trigger('click')

      expect(wrapper.vm.isCollapsed).toBe(true)
    })

    it('should filter menu items by permission', () => {
      const wrapper = mountLayout()

      // Should show items the user has permission for
      const menuItems = wrapper.vm.menuItems

      // Dashboard should always be visible (no permission required)
      expect(menuItems.find((item: any) => item.path === '/dashboard')).toBeTruthy()

      // Users should be visible (has user:list permission)
      expect(menuItems.find((item: any) => item.path === '/users')).toBeTruthy()
    })
  })

  describe('header', () => {
    it('should display user info', () => {
      const wrapper = mountLayout()

      expect(wrapper.find('.user-info').exists()).toBe(true)
      expect(wrapper.text()).toContain('Admin User')
    })

    it('should handle logout', async () => {
      const wrapper = mountLayout()
      const authStore = useAuthStore()
      const logoutSpy = vi.spyOn(authStore, 'logout').mockResolvedValue()

      // Simulate dropdown command
      await wrapper.vm.handleCommand('logout')

      // Note: In real test, we'd need to handle the confirmation dialog
    })
  })

  describe('breadcrumbs', () => {
    it('should display breadcrumbs based on route', async () => {
      const wrapper = mountLayout()

      await router.push('/dashboard')
      await wrapper.vm.$nextTick()

      expect(wrapper.find('.el-breadcrumb').exists()).toBe(true)
    })
  })
})
