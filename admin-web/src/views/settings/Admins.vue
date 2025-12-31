<template>
  <div class="admin-list">
    <div class="page-header">
      <h2 class="page-title">管理员</h2>
      <el-button type="primary" @click="handleAdd">
        <el-icon><Plus /></el-icon>添加管理员
      </el-button>
    </div>

    <!-- Admin Table -->
    <div class="table-container">
      <el-table v-loading="loading" :data="admins" stripe>
        <el-table-column prop="username" label="用户名" width="150" />
        <el-table-column prop="display_name" label="显示名称" width="150" />
        <el-table-column prop="email" label="邮箱" min-width="200" />
        <el-table-column prop="role" label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="row.is_superadmin ? 'danger' : 'primary'" size="small">
              {{ row.is_superadmin ? '超级管理员' : row.role_name || '普通管理员' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 'active' ? 'success' : 'warning'" size="small">
              {{ row.status === 'active' ? '正常' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="mfa_enabled" label="MFA" width="80">
          <template #default="{ row }">
            <el-tag v-if="row.mfa_enabled" type="success" size="small">已启用</el-tag>
            <span v-else class="text-muted">未启用</span>
          </template>
        </el-table-column>
        <el-table-column prop="last_login_at" label="最后登录" width="160">
          <template #default="{ row }">
            {{ row.last_login_at ? formatDateTime(row.last_login_at) : '-' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="handleEdit(row)">编辑</el-button>
            <el-button type="warning" text size="small" @click="handleResetPassword(row)">重置密码</el-button>
            <el-button
              v-if="!row.is_superadmin"
              :type="row.status === 'active' ? 'warning' : 'success'"
              text
              size="small"
              @click="handleToggleStatus(row)"
            >
              {{ row.status === 'active' ? '禁用' : '启用' }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-container">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :total="pagination.total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Add/Edit Dialog -->
    <el-dialog v-model="dialogVisible" :title="editingAdmin ? '编辑管理员' : '添加管理员'" width="500px">
      <el-form ref="formRef" :model="form" :rules="formRules" label-width="100px">
        <el-form-item label="用户名" prop="username">
          <el-input v-model="form.username" :disabled="!!editingAdmin" />
        </el-form-item>
        <el-form-item v-if="!editingAdmin" label="密码" prop="password">
          <el-input v-model="form.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="显示名称" prop="display_name">
          <el-input v-model="form.display_name" />
        </el-form-item>
        <el-form-item label="邮箱" prop="email">
          <el-input v-model="form.email" />
        </el-form-item>
        <el-form-item label="角色" prop="role_id">
          <el-select v-model="form.role_id" placeholder="选择角色">
            <el-option v-for="role in roles" :key="role.id" :label="role.name" :value="role.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="权限" prop="permissions">
          <el-select v-model="form.permissions" multiple placeholder="选择权限" style="width: 100%;">
            <el-option-group v-for="group in permissionGroups" :key="group.name" :label="group.name">
              <el-option v-for="perm in group.permissions" :key="perm.code" :label="perm.name" :value="perm.code" />
            </el-option-group>
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitForm">保存</el-button>
      </template>
    </el-dialog>

    <!-- Reset Password Dialog -->
    <el-dialog v-model="resetPasswordVisible" title="重置密码" width="400px">
      <el-form ref="resetFormRef" :model="resetForm" :rules="resetRules" label-width="100px">
        <el-form-item label="新密码" prop="password">
          <el-input v-model="resetForm.password" type="password" show-password />
        </el-form-item>
        <el-form-item label="确认密码" prop="confirm_password">
          <el-input v-model="resetForm.confirm_password" type="password" show-password />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="resetPasswordVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitResetPassword">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules } from 'element-plus'
import * as settingsApi from '@/api/settings'
import type { AdminUser } from '@/types'

// State
const loading = ref(false)
const admins = ref<AdminUser[]>([])
const roles = ref<any[]>([])
const permissionGroups = ref<any[]>([])
const pagination = reactive({
  page: 1,
  pageSize: 10,
  total: 0,
})

// Dialog
const dialogVisible = ref(false)
const editingAdmin = ref<AdminUser | null>(null)
const saving = ref(false)
const formRef = ref<FormInstance>()
const form = reactive({
  username: '',
  password: '',
  display_name: '',
  email: '',
  role_id: '',
  permissions: [] as string[],
})
const formRules: FormRules = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 32, message: '用户名长度3-32个字符', trigger: 'blur' },
  ],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
  email: [{ type: 'email', message: '请输入有效的邮箱', trigger: 'blur' }],
}

// Reset password
const resetPasswordVisible = ref(false)
const resetFormRef = ref<FormInstance>()
const resetForm = reactive({
  admin_id: '',
  password: '',
  confirm_password: '',
})
const resetRules: FormRules = {
  password: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 8, message: '密码长度至少8个字符', trigger: 'blur' },
  ],
  confirm_password: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value !== resetForm.password) {
          callback(new Error('两次输入的密码不一致'))
        } else {
          callback()
        }
      },
      trigger: 'blur',
    },
  ],
}

// Fetch data
const fetchAdmins = async () => {
  loading.value = true
  try {
    const response = await settingsApi.getAdmins({
      page: pagination.page,
      page_size: pagination.pageSize,
    })
    admins.value = response.items
    pagination.total = response.total
  } catch (e) {
    ElMessage.error('获取管理员列表失败')
  } finally {
    loading.value = false
  }
}

const fetchRolesAndPermissions = async () => {
  try {
    const [rolesData, permsData] = await Promise.all([
      settingsApi.getRoles(),
      settingsApi.getPermissions(),
    ])
    roles.value = rolesData.items || []
    permissionGroups.value = permsData.groups || []
  } catch (e) {
    console.error('Failed to fetch roles and permissions:', e)
  }
}

// Handlers
const handlePageChange = (page: number) => {
  pagination.page = page
  fetchAdmins()
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  pagination.page = 1
  fetchAdmins()
}

const handleAdd = () => {
  editingAdmin.value = null
  Object.assign(form, {
    username: '',
    password: '',
    display_name: '',
    email: '',
    role_id: '',
    permissions: [],
  })
  dialogVisible.value = true
}

const handleEdit = (admin: AdminUser) => {
  editingAdmin.value = admin
  Object.assign(form, {
    username: admin.username,
    password: '',
    display_name: admin.display_name || '',
    email: admin.email || '',
    role_id: admin.role_id || '',
    permissions: admin.permissions || [],
  })
  dialogVisible.value = true
}

const submitForm = async () => {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return

    saving.value = true
    try {
      if (editingAdmin.value) {
        await settingsApi.updateAdmin(editingAdmin.value.id, {
          display_name: form.display_name,
          email: form.email,
          role_id: form.role_id,
          permissions: form.permissions,
        })
        ElMessage.success('更新成功')
      } else {
        await settingsApi.createAdmin(form)
        ElMessage.success('创建成功')
      }
      dialogVisible.value = false
      fetchAdmins()
    } catch (e) {
      ElMessage.error('操作失败')
    } finally {
      saving.value = false
    }
  })
}

const handleResetPassword = (admin: AdminUser) => {
  resetForm.admin_id = admin.id
  resetForm.password = ''
  resetForm.confirm_password = ''
  resetPasswordVisible.value = true
}

const submitResetPassword = async () => {
  if (!resetFormRef.value) return
  await resetFormRef.value.validate(async (valid) => {
    if (!valid) return

    saving.value = true
    try {
      await settingsApi.resetAdminPassword(resetForm.admin_id, resetForm.password)
      ElMessage.success('密码重置成功')
      resetPasswordVisible.value = false
    } catch (e) {
      ElMessage.error('密码重置失败')
    } finally {
      saving.value = false
    }
  })
}

const handleToggleStatus = async (admin: AdminUser) => {
  const action = admin.status === 'active' ? '禁用' : '启用'
  try {
    await ElMessageBox.confirm(`确定要${action}管理员 "${admin.username}" 吗？`, `确认${action}`, {
      type: 'warning',
    })
    await settingsApi.toggleAdminStatus(admin.id)
    ElMessage.success(`${action}成功`)
    fetchAdmins()
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error(`${action}失败`)
    }
  }
}

// Formatters
const formatDateTime = (date: string) => {
  return new Date(date).toLocaleString('zh-CN')
}

// Init
onMounted(() => {
  fetchAdmins()
  fetchRolesAndPermissions()
})
</script>
