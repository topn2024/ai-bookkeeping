import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import NProgress from 'nprogress'
import { useAuthStore } from '@/stores/auth'

// Layouts
const MainLayout = () => import('@/layouts/MainLayout.vue')

// Auth pages
const Login = () => import('@/views/auth/Login.vue')

// Dashboard
const Dashboard = () => import('@/views/dashboard/Index.vue')

// Users
const UserList = () => import('@/views/users/List.vue')
const UserDetail = () => import('@/views/users/Detail.vue')

// Data management
const TransactionList = () => import('@/views/data/Transactions.vue')
const BookList = () => import('@/views/data/Books.vue')
const CategoryList = () => import('@/views/data/Categories.vue')
const BackupList = () => import('@/views/data/Backups.vue')

// Statistics
const UserAnalysis = () => import('@/views/statistics/UserAnalysis.vue')
const TransactionAnalysis = () => import('@/views/statistics/TransactionAnalysis.vue')
const Reports = () => import('@/views/statistics/Reports.vue')

// Monitor
const SystemHealth = () => import('@/views/monitor/Health.vue')
const SystemResources = () => import('@/views/monitor/Resources.vue')
const AlertRules = () => import('@/views/monitor/Alerts.vue')

// Settings
const SystemSettings = () => import('@/views/settings/System.vue')
const SecuritySettings = () => import('@/views/settings/Security.vue')
const AdminList = () => import('@/views/settings/Admins.vue')
const AuditLogs = () => import('@/views/settings/Logs.vue')
const Profile = () => import('@/views/settings/Profile.vue')
const AppVersions = () => import('@/views/settings/AppVersions.vue')

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: Login,
    meta: { requiresAuth: false },
  },
  {
    path: '/',
    component: MainLayout,
    redirect: '/dashboard',
    meta: { requiresAuth: true },
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: Dashboard,
        meta: { title: '仪表盘', icon: 'Odometer' },
      },
      // Users
      {
        path: 'users',
        name: 'UserList',
        component: UserList,
        meta: { title: '用户管理', icon: 'User', permission: 'user:list' },
      },
      {
        path: 'users/:id',
        name: 'UserDetail',
        component: UserDetail,
        meta: { title: '用户详情', permission: 'user:detail', hidden: true },
      },
      // Data
      {
        path: 'data/transactions',
        name: 'TransactionList',
        component: TransactionList,
        meta: { title: '交易管理', icon: 'Tickets', permission: 'data:transaction:view' },
      },
      {
        path: 'data/books',
        name: 'BookList',
        component: BookList,
        meta: { title: '账本管理', icon: 'Notebook', permission: 'data:book:view' },
      },
      {
        path: 'data/categories',
        name: 'CategoryList',
        component: CategoryList,
        meta: { title: '分类管理', icon: 'Menu', permission: 'data:category:view' },
      },
      {
        path: 'data/backups',
        name: 'BackupList',
        component: BackupList,
        meta: { title: '备份管理', icon: 'FolderOpened', permission: 'data:backup:view' },
      },
      // Statistics
      {
        path: 'statistics/users',
        name: 'UserAnalysis',
        component: UserAnalysis,
        meta: { title: '用户分析', icon: 'TrendCharts', permission: 'stats:user' },
      },
      {
        path: 'statistics/transactions',
        name: 'TransactionAnalysis',
        component: TransactionAnalysis,
        meta: { title: '交易分析', icon: 'DataAnalysis', permission: 'stats:transaction' },
      },
      {
        path: 'statistics/reports',
        name: 'Reports',
        component: Reports,
        meta: { title: '报表中心', icon: 'Document', permission: 'stats:report' },
      },
      // Monitor
      {
        path: 'monitor/health',
        name: 'SystemHealth',
        component: SystemHealth,
        meta: { title: '系统健康', icon: 'Monitor', permission: 'monitor:view' },
      },
      {
        path: 'monitor/resources',
        name: 'SystemResources',
        component: SystemResources,
        meta: { title: '系统资源', icon: 'Cpu', permission: 'monitor:view' },
      },
      {
        path: 'monitor/alerts',
        name: 'AlertRules',
        component: AlertRules,
        meta: { title: '告警管理', icon: 'Bell', permission: 'monitor:alert' },
      },
      // Settings
      {
        path: 'settings/system',
        name: 'SystemSettings',
        component: SystemSettings,
        meta: { title: '系统设置', icon: 'Setting', permission: 'settings:view' },
      },
      {
        path: 'settings/security',
        name: 'SecuritySettings',
        component: SecuritySettings,
        meta: { title: '安全设置', icon: 'Lock', permission: 'settings:security' },
      },
      {
        path: 'settings/admins',
        name: 'AdminList',
        component: AdminList,
        meta: { title: '管理员', icon: 'UserFilled', permission: 'admin:list' },
      },
      {
        path: 'settings/logs',
        name: 'AuditLogs',
        component: AuditLogs,
        meta: { title: '审计日志', icon: 'Memo', permission: 'log:view' },
      },
      {
        path: 'settings/versions',
        name: 'AppVersions',
        component: AppVersions,
        meta: { title: '版本管理', icon: 'Upload', permission: 'settings:view' },
      },
      {
        path: 'profile',
        name: 'Profile',
        component: Profile,
        meta: { title: '个人设置', hidden: true },
      },
    ],
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/dashboard',
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// Navigation guards
router.beforeEach(async (to, from, next) => {
  NProgress.start()
  const authStore = useAuthStore()

  // Check if route requires auth
  const requiresAuth = to.meta.requiresAuth !== false

  if (requiresAuth) {
    if (!authStore.isLoggedIn) {
      next({ path: '/login', query: { redirect: to.fullPath } })
      return
    }

    // Fetch admin info if not loaded
    if (!authStore.admin) {
      await authStore.fetchCurrentAdmin()
      if (!authStore.admin) {
        next({ path: '/login', query: { redirect: to.fullPath } })
        return
      }
    }

    // Check permission
    const permission = to.meta.permission as string | undefined
    if (permission && !authStore.hasPermission(permission)) {
      next({ path: '/dashboard' })
      return
    }
  } else {
    // Redirect to dashboard if already logged in
    if (authStore.isLoggedIn && to.path === '/login') {
      next({ path: '/dashboard' })
      return
    }
  }

  next()
})

router.afterEach(() => {
  NProgress.done()
})

export default router
