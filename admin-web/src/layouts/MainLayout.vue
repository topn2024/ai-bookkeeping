<template>
  <el-container class="main-layout">
    <!-- Sidebar -->
    <el-aside :width="isCollapsed ? '64px' : '220px'" class="sidebar">
      <div class="logo">
        <img src="@/assets/logo.svg" alt="Logo" class="logo-img" />
        <span v-if="!isCollapsed" class="logo-text">AI记账管理</span>
      </div>
      <el-menu
        :default-active="activeMenu"
        :collapse="isCollapsed"
        :router="true"
        class="sidebar-menu"
        background-color="#001529"
        text-color="#ffffffa6"
        active-text-color="#ffffff"
      >
        <template v-for="item in menuItems" :key="item.path">
          <el-sub-menu v-if="item.children && item.children.length" :index="item.path">
            <template #title>
              <el-icon><component :is="item.icon" /></el-icon>
              <span>{{ item.title }}</span>
            </template>
            <el-menu-item
              v-for="child in item.children"
              :key="child.path"
              :index="child.path"
            >
              {{ child.title }}
            </el-menu-item>
          </el-sub-menu>
          <el-menu-item v-else :index="item.path">
            <el-icon><component :is="item.icon" /></el-icon>
            <template #title>{{ item.title }}</template>
          </el-menu-item>
        </template>
      </el-menu>
    </el-aside>

    <!-- Main content -->
    <el-container>
      <!-- Header -->
      <el-header class="header">
        <div class="header-left">
          <el-icon class="collapse-btn" @click="toggleCollapse">
            <Fold v-if="!isCollapsed" />
            <Expand v-else />
          </el-icon>
          <el-breadcrumb separator="/">
            <el-breadcrumb-item v-for="item in breadcrumbs" :key="item.path" :to="item.path">
              {{ item.title }}
            </el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        <div class="header-right">
          <el-dropdown @command="handleCommand">
            <span class="user-info">
              <el-avatar :size="32" :src="authStore.admin?.avatar_url || undefined">
                {{ authStore.admin?.display_name?.charAt(0) || authStore.admin?.username?.charAt(0) }}
              </el-avatar>
              <span class="username">{{ authStore.admin?.display_name || authStore.admin?.username }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile">
                  <el-icon><User /></el-icon>个人设置
                </el-dropdown-item>
                <el-dropdown-item divided command="logout">
                  <el-icon><SwitchButton /></el-icon>退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <!-- Main content area -->
      <el-main class="main-content">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessageBox } from 'element-plus'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const isCollapsed = ref(false)

const menuItems = computed(() => {
  const items = [
    { path: '/dashboard', title: '仪表盘', icon: 'Odometer' },
    { path: '/users', title: '用户管理', icon: 'User', permission: 'user:list' },
    {
      path: '/data',
      title: '数据管理',
      icon: 'Folder',
      children: [
        { path: '/data/transactions', title: '交易管理', permission: 'data:transaction:view' },
        { path: '/data/books', title: '账本管理', permission: 'data:book:view' },
        { path: '/data/categories', title: '分类管理', permission: 'data:category:view' },
        { path: '/data/backups', title: '备份管理', permission: 'data:backup:view' },
      ],
    },
    {
      path: '/statistics',
      title: '统计分析',
      icon: 'TrendCharts',
      children: [
        { path: '/statistics/users', title: '用户分析', permission: 'stats:user' },
        { path: '/statistics/transactions', title: '交易分析', permission: 'stats:transaction' },
        { path: '/statistics/reports', title: '报表中心', permission: 'stats:report' },
      ],
    },
    {
      path: '/monitor',
      title: '系统监控',
      icon: 'Monitor',
      children: [
        { path: '/monitor/health', title: '系统健康', permission: 'monitor:view' },
        { path: '/monitor/resources', title: '系统资源', permission: 'monitor:view' },
        { path: '/monitor/logs', title: '系统日志', permission: 'monitor:view' },
        { path: '/monitor/alerts', title: '告警管理', permission: 'monitor:alert' },
        { path: '/monitor/ai-service', title: 'AI服务监控', permission: 'monitor:view' },
        { path: '/monitor/diagnostics', title: '诊断报告', permission: 'monitor:view' },
        { path: '/monitor/data-quality', title: '数据质量', permission: 'monitor:data_quality:view' },
      ],
    },
    {
      path: '/settings',
      title: '系统设置',
      icon: 'Setting',
      children: [
        { path: '/settings/system', title: '系统设置', permission: 'settings:view' },
        { path: '/settings/security', title: '安全设置', permission: 'settings:security' },
        { path: '/settings/admins', title: '管理员', permission: 'admin:list' },
        { path: '/settings/logs', title: '审计日志', permission: 'log:view' },
        { path: '/settings/versions', title: '版本管理', permission: 'settings:view' },
      ],
    },
  ]

  // Filter by permissions
  const filterByPermission = (items: any[]): any[] => {
    return items
      .filter(item => {
        if (item.permission && !authStore.hasPermission(item.permission)) {
          return false
        }
        return true
      })
      .map(item => {
        if (item.children) {
          return { ...item, children: filterByPermission(item.children) }
        }
        return item
      })
      .filter(item => !item.children || item.children.length > 0)
  }

  return filterByPermission(items)
})

const activeMenu = computed(() => route.path)

const breadcrumbs = computed(() => {
  const matched = route.matched.filter(item => item.meta?.title)
  return matched.map(item => ({
    path: item.path,
    title: item.meta?.title as string,
  }))
})

const toggleCollapse = () => {
  isCollapsed.value = !isCollapsed.value
}

const handleCommand = async (command: string) => {
  if (command === 'profile') {
    router.push('/profile')
  } else if (command === 'logout') {
    try {
      await ElMessageBox.confirm('确定要退出登录吗？', '提示', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      })
      await authStore.logout()
      router.push('/login')
    } catch {
      // Cancelled
    }
  }
}
</script>

<style scoped lang="scss">
.main-layout {
  height: 100vh;
}

.sidebar {
  background-color: #001529;
  transition: width 0.3s;
  overflow: hidden;
  display: flex;
  flex-direction: column;

  .logo {
    height: 64px;
    min-height: 64px;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 16px;

    .logo-img {
      width: 32px;
      height: 32px;
    }

    .logo-text {
      margin-left: 12px;
      color: #fff;
      font-size: 18px;
      font-weight: 600;
      white-space: nowrap;
    }
  }

  .sidebar-menu {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    border-right: none;

    // 自定义滚动条样式
    &::-webkit-scrollbar {
      width: 6px;
    }

    &::-webkit-scrollbar-track {
      background: #001529;
    }

    &::-webkit-scrollbar-thumb {
      background: #1890ff;
      border-radius: 3px;
    }

    &::-webkit-scrollbar-thumb:hover {
      background: #40a9ff;
    }

    :deep(.el-menu-item.is-active) {
      background-color: #1890ff !important;
    }
  }
}

.header {
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);

  .header-left {
    display: flex;
    align-items: center;

    .collapse-btn {
      font-size: 20px;
      cursor: pointer;
      margin-right: 20px;

      &:hover {
        color: #1890ff;
      }
    }
  }

  .header-right {
    .user-info {
      display: flex;
      align-items: center;
      cursor: pointer;

      .username {
        margin: 0 8px;
      }
    }
  }
}

.main-content {
  background: #f0f2f5;
  padding: 20px;
  overflow-x: hidden; // 防止水平滚动条
  overflow-y: auto;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
