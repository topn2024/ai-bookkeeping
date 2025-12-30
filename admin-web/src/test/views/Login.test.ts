import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'
import Login from '@/views/auth/Login.vue'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createMemoryHistory(),
  routes: [
    { path: '/login', component: Login },
    { path: '/dashboard', component: { template: '<div>Dashboard</div>' } },
  ],
})

describe('Login Page', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  const mountLogin = () => {
    return mount(Login, {
      global: {
        plugins: [router],
      },
    })
  }

  describe('rendering', () => {
    it('should render login form', () => {
      const wrapper = mountLogin()

      expect(wrapper.find('.login-container').exists()).toBe(true)
      expect(wrapper.find('input[placeholder="用户名"]').exists()).toBe(true)
      expect(wrapper.find('input[placeholder="密码"]').exists()).toBe(true)
      expect(wrapper.find('button').text()).toContain('登录')
    })

    it('should not show MFA field initially', () => {
      const wrapper = mountLogin()
      expect(wrapper.find('input[placeholder="MFA验证码"]').exists()).toBe(false)
    })
  })

  describe('form validation', () => {
    it('should validate required username', async () => {
      const wrapper = mountLogin()

      // Try to submit without username
      await wrapper.find('button').trigger('click')
      await flushPromises()

      // Check for validation message (Element Plus shows validation)
      expect(wrapper.text()).toContain('请输入用户名')
    })

    it('should validate required password', async () => {
      const wrapper = mountLogin()

      await wrapper.find('input[placeholder="用户名"]').setValue('admin')
      await wrapper.find('button').trigger('click')
      await flushPromises()

      expect(wrapper.text()).toContain('请输入密码')
    })
  })

  describe('login flow', () => {
    it('should call login on valid submission', async () => {
      const wrapper = mountLogin()
      const authStore = useAuthStore()
      const loginSpy = vi.spyOn(authStore, 'login').mockResolvedValue({} as any)

      await wrapper.find('input[placeholder="用户名"]').setValue('admin')
      await wrapper.find('input[placeholder="密码"]').setValue('password123')
      await wrapper.find('button').trigger('click')
      await flushPromises()

      expect(loginSpy).toHaveBeenCalledWith('admin', 'password123', undefined)
    })

    it('should show MFA field when required', async () => {
      const wrapper = mountLogin()
      const authStore = useAuthStore()

      vi.spyOn(authStore, 'login').mockRejectedValue({
        response: { data: { detail: 'MFA required' } },
      })

      await wrapper.find('input[placeholder="用户名"]').setValue('admin')
      await wrapper.find('input[placeholder="密码"]').setValue('password123')
      await wrapper.find('button').trigger('click')
      await flushPromises()

      // MFA field should now be visible
      expect(wrapper.vm.showMFA).toBe(true)
    })
  })
})
