import axios, { type AxiosInstance, type AxiosRequestConfig, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import NProgress from 'nprogress'
import { useAuthStore } from '@/stores/auth'
import router from '@/router'

// 防止重复弹出登录过期提示
let isShowingLogoutDialog = false

// 是否正在刷新 token
let isRefreshing = false
// 刷新 token 是否失败（用于静默处理后续请求）
let refreshFailed = false
// 等待刷新 token 的请求队列
let pendingRequests: Array<{
  resolve: (token: string) => void
  reject: (error: any) => void
}> = []

// Create axios instance
const service: AxiosInstance = axios.create({
  baseURL: '/admin',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor
service.interceptors.request.use(
  (config) => {
    NProgress.start()
    const authStore = useAuthStore()
    if (authStore.token) {
      config.headers.Authorization = `Bearer ${authStore.token}`
    }
    return config
  },
  (error) => {
    NProgress.done()
    return Promise.reject(error)
  }
)

// Response interceptor
service.interceptors.response.use(
  (response: AxiosResponse) => {
    NProgress.done()
    return response.data
  },
  async (error) => {
    NProgress.done()
    const { response, config } = error
    const originalRequest = config as InternalAxiosRequestConfig & { _retry?: boolean }

    if (response) {
      const { status, data } = response

      // 处理 401 错误 - 尝试刷新 token
      if (status === 401 && !originalRequest._retry) {
        // 如果是刷新 token 的请求失败，直接跳转登录
        if (originalRequest.url?.includes('/auth/refresh')) {
          refreshFailed = true
          showLogoutDialog()
          return Promise.reject(error)
        }

        // 如果刷新已经失败，静默拒绝后续请求
        if (refreshFailed) {
          return Promise.reject(error)
        }

        originalRequest._retry = true

        // 如果正在刷新 token，将请求加入队列
        if (isRefreshing) {
          return new Promise((resolve, reject) => {
            pendingRequests.push({
              resolve: (token: string) => {
                originalRequest.headers.Authorization = `Bearer ${token}`
                resolve(service(originalRequest))
              },
              reject: (err: any) => {
                reject(err)
              }
            })
          })
        }

        isRefreshing = true
        refreshFailed = false

        try {
          const authStore = useAuthStore()
          const success = await authStore.refreshAccessToken()

          if (success) {
            // 刷新成功，重试原请求
            const newToken = authStore.token
            originalRequest.headers.Authorization = `Bearer ${newToken}`

            // 执行队列中的请求
            pendingRequests.forEach(({ resolve }) => resolve(newToken!))
            pendingRequests = []

            return service(originalRequest)
          } else {
            // 刷新失败，拒绝队列中的所有请求
            refreshFailed = true
            pendingRequests.forEach(({ reject }) => reject(error))
            pendingRequests = []
            showLogoutDialog()
            return Promise.reject(error)
          }
        } catch (refreshError) {
          // 刷新失败，拒绝队列中的所有请求
          refreshFailed = true
          pendingRequests.forEach(({ reject }) => reject(refreshError))
          pendingRequests = []
          showLogoutDialog()
          return Promise.reject(refreshError)
        } finally {
          isRefreshing = false
        }
      }

      // 如果刷新已失败，静默处理 401（不重复弹出错误提示）
      if (status === 401 && refreshFailed) {
        return Promise.reject(error)
      }

      switch (status) {
        case 401:
          // 检查是否需要 MFA 验证
          if (response.headers?.['x-mfa-required'] === 'true') {
            // 不弹出登出对话框，让登录页面处理 MFA 输入
            break
          }
          // 已经重试过但仍然失败
          showLogoutDialog()
          break
        case 403:
          // 如果刷新失败导致的 403，静默处理
          if (!refreshFailed) {
            ElMessage.error('没有权限执行此操作')
          }
          break
        case 404:
          ElMessage.error('请求的资源不存在')
          break
        case 422:
          ElMessage.error(data.detail || '请求参数错误')
          break
        case 429:
          ElMessage.error('操作过于频繁，请稍后再试')
          break
        case 500:
          ElMessage.error('服务器内部错误')
          break
        default:
          ElMessage.error(data.detail || data.message || '请求失败')
      }
    } else {
      ElMessage.error('网络连接失败，请检查网络')
    }

    return Promise.reject(error)
  }
)

// 显示登录过期对话框
function showLogoutDialog() {
  if (!isShowingLogoutDialog) {
    isShowingLogoutDialog = true
    ElMessageBox.confirm('登录已过期，请重新登录', '提示', {
      confirmButtonText: '重新登录',
      cancelButtonText: '取消',
      type: 'warning',
    }).then(() => {
      const authStore = useAuthStore()
      authStore.logout()
      router.push('/login')
    }).finally(() => {
      isShowingLogoutDialog = false
      refreshFailed = false  // 重置刷新失败标志
    })
  }
}

// Export request methods
export const get = <T = any>(url: string, config?: AxiosRequestConfig): Promise<T> => {
  return service.get(url, config)
}

export const post = <T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> => {
  return service.post(url, data, config)
}

export const put = <T = any>(url: string, data?: any, config?: AxiosRequestConfig): Promise<T> => {
  return service.put(url, data, config)
}

export const del = <T = any>(url: string, config?: AxiosRequestConfig): Promise<T> => {
  return service.delete(url, config)
}

export const download = (url: string, params?: any): Promise<Blob> => {
  return service.get(url, {
    params,
    responseType: 'blob',
  })
}

export const upload = <T = any>(url: string, data: FormData, config?: AxiosRequestConfig): Promise<T> => {
  return service.post(url, data, {
    ...config,
    headers: {
      'Content-Type': 'multipart/form-data',
      ...config?.headers,
    },
  })
}

export default service
