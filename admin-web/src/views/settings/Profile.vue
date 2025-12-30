<template>
  <div class="profile-settings">
    <div class="page-header">
      <h2 class="page-title">个人设置</h2>
    </div>

    <el-row :gutter="20">
      <el-col :span="8">
        <!-- Profile Card -->
        <el-card>
          <div class="profile-card">
            <el-upload
              class="avatar-uploader"
              :show-file-list="false"
              :before-upload="handleAvatarUpload"
            >
              <el-avatar :size="100" :src="profile.avatar_url">
                {{ profile.display_name?.charAt(0) || profile.username?.charAt(0) }}
              </el-avatar>
              <div class="avatar-overlay">
                <el-icon><Camera /></el-icon>
              </div>
            </el-upload>
            <h3>{{ profile.display_name || profile.username }}</h3>
            <p class="text-muted">{{ profile.email }}</p>
            <el-tag :type="profile.is_superadmin ? 'danger' : 'primary'">
              {{ profile.is_superadmin ? '超级管理员' : profile.role_name || '管理员' }}
            </el-tag>
          </div>

          <el-divider />

          <el-descriptions :column="1" size="small">
            <el-descriptions-item label="用户名">{{ profile.username }}</el-descriptions-item>
            <el-descriptions-item label="最后登录">{{ formatDateTime(profile.last_login_at) }}</el-descriptions-item>
            <el-descriptions-item label="登录IP">{{ profile.last_login_ip || '-' }}</el-descriptions-item>
            <el-descriptions-item label="MFA状态">
              <el-tag v-if="profile.mfa_enabled" type="success" size="small">已启用</el-tag>
              <el-tag v-else type="warning" size="small">未启用</el-tag>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>

      <el-col :span="16">
        <el-tabs v-model="activeTab">
          <!-- Basic Info -->
          <el-tab-pane label="基本信息" name="info">
            <el-card>
              <el-form ref="infoFormRef" :model="infoForm" :rules="infoRules" label-width="100px">
                <el-form-item label="显示名称" prop="display_name">
                  <el-input v-model="infoForm.display_name" style="width: 300px;" />
                </el-form-item>
                <el-form-item label="邮箱" prop="email">
                  <el-input v-model="infoForm.email" style="width: 300px;" />
                </el-form-item>
                <el-form-item label="手机号" prop="phone">
                  <el-input v-model="infoForm.phone" style="width: 300px;" />
                </el-form-item>
                <el-form-item>
                  <el-button type="primary" :loading="saving" @click="saveInfo">保存</el-button>
                </el-form-item>
              </el-form>
            </el-card>
          </el-tab-pane>

          <!-- Change Password -->
          <el-tab-pane label="修改密码" name="password">
            <el-card>
              <el-form ref="passwordFormRef" :model="passwordForm" :rules="passwordRules" label-width="100px">
                <el-form-item label="当前密码" prop="current_password">
                  <el-input v-model="passwordForm.current_password" type="password" show-password style="width: 300px;" />
                </el-form-item>
                <el-form-item label="新密码" prop="new_password">
                  <el-input v-model="passwordForm.new_password" type="password" show-password style="width: 300px;" />
                </el-form-item>
                <el-form-item label="确认密码" prop="confirm_password">
                  <el-input v-model="passwordForm.confirm_password" type="password" show-password style="width: 300px;" />
                </el-form-item>
                <el-form-item>
                  <el-button type="primary" :loading="saving" @click="changePassword">修改密码</el-button>
                </el-form-item>
              </el-form>
            </el-card>
          </el-tab-pane>

          <!-- MFA Settings -->
          <el-tab-pane label="多因素认证" name="mfa">
            <el-card>
              <template v-if="!profile.mfa_enabled">
                <el-alert type="warning" :closable="false" class="mb-20">
                  您尚未启用多因素认证，建议开启以提高账号安全性
                </el-alert>
                <el-button type="primary" @click="setupMFA">启用MFA</el-button>
              </template>

              <template v-else>
                <el-alert type="success" :closable="false" class="mb-20">
                  多因素认证已启用
                </el-alert>
                <el-descriptions :column="1" border>
                  <el-descriptions-item label="启用方式">{{ profile.mfa_type === 'totp' ? 'TOTP验证器' : '邮箱验证' }}</el-descriptions-item>
                  <el-descriptions-item label="启用时间">{{ formatDateTime(profile.mfa_enabled_at) }}</el-descriptions-item>
                </el-descriptions>
                <div class="mt-20">
                  <el-button type="danger" @click="disableMFA">禁用MFA</el-button>
                </div>
              </template>
            </el-card>
          </el-tab-pane>

          <!-- Login History -->
          <el-tab-pane label="登录历史" name="history">
            <el-card>
              <el-table :data="loginHistory" size="small" stripe>
                <el-table-column prop="login_time" label="登录时间">
                  <template #default="{ row }">
                    {{ formatDateTime(row.login_time) }}
                  </template>
                </el-table-column>
                <el-table-column prop="ip_address" label="IP地址" />
                <el-table-column prop="location" label="位置">
                  <template #default="{ row }">
                    {{ row.location || '-' }}
                  </template>
                </el-table-column>
                <el-table-column prop="device" label="设备" />
                <el-table-column prop="status" label="状态">
                  <template #default="{ row }">
                    <el-tag :type="row.status === 'success' ? 'success' : 'danger'" size="small">
                      {{ row.status === 'success' ? '成功' : '失败' }}
                    </el-tag>
                  </template>
                </el-table-column>
              </el-table>
            </el-card>
          </el-tab-pane>
        </el-tabs>
      </el-col>
    </el-row>

    <!-- MFA Setup Dialog -->
    <el-dialog v-model="mfaDialogVisible" title="设置多因素认证" width="500px" :close-on-click-modal="false">
      <div v-if="mfaSetup.step === 1" class="mfa-setup">
        <p class="mb-20">请使用Google Authenticator或其他TOTP应用扫描下方二维码：</p>
        <div class="qr-code">
          <img v-if="mfaSetup.qr_code" :src="mfaSetup.qr_code" alt="QR Code" />
        </div>
        <p class="text-muted mt-10">无法扫描？手动输入密钥：{{ mfaSetup.secret }}</p>
        <el-form class="mt-20" @submit.prevent="verifyMFA">
          <el-form-item label="验证码">
            <el-input v-model="mfaSetup.code" placeholder="输入6位验证码" maxlength="6" />
          </el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button @click="mfaDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="verifyMFA">验证并启用</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox, type FormInstance, type FormRules, type UploadRawFile } from 'element-plus'
import * as authApi from '@/api/auth'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

// State
const activeTab = ref('info')
const saving = ref(false)
const profile = reactive({
  username: '',
  display_name: '',
  email: '',
  phone: '',
  avatar_url: '',
  is_superadmin: false,
  role_name: '',
  mfa_enabled: false,
  mfa_type: '',
  mfa_enabled_at: '',
  last_login_at: '',
  last_login_ip: '',
})
const loginHistory = ref<any[]>([])

// Info form
const infoFormRef = ref<FormInstance>()
const infoForm = reactive({
  display_name: '',
  email: '',
  phone: '',
})
const infoRules: FormRules = {
  email: [{ type: 'email', message: '请输入有效的邮箱', trigger: 'blur' }],
}

// Password form
const passwordFormRef = ref<FormInstance>()
const passwordForm = reactive({
  current_password: '',
  new_password: '',
  confirm_password: '',
})
const passwordRules: FormRules = {
  current_password: [{ required: true, message: '请输入当前密码', trigger: 'blur' }],
  new_password: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 8, message: '密码长度至少8个字符', trigger: 'blur' },
  ],
  confirm_password: [
    { required: true, message: '请确认新密码', trigger: 'blur' },
    {
      validator: (rule, value, callback) => {
        if (value !== passwordForm.new_password) {
          callback(new Error('两次输入的密码不一致'))
        } else {
          callback()
        }
      },
      trigger: 'blur',
    },
  ],
}

// MFA setup
const mfaDialogVisible = ref(false)
const mfaSetup = reactive({
  step: 1,
  qr_code: '',
  secret: '',
  code: '',
})

// Fetch data
const fetchProfile = async () => {
  try {
    const data = await authApi.getProfile()
    Object.assign(profile, data)
    Object.assign(infoForm, {
      display_name: data.display_name || '',
      email: data.email || '',
      phone: data.phone || '',
    })
  } catch (e) {
    ElMessage.error('获取个人信息失败')
  }
}

const fetchLoginHistory = async () => {
  try {
    const data = await authApi.getLoginHistory()
    loginHistory.value = data.items || []
  } catch (e) {
    console.error('Failed to fetch login history:', e)
  }
}

// Handlers
const handleAvatarUpload = async (file: UploadRawFile) => {
  if (!file.type.startsWith('image/')) {
    ElMessage.error('请上传图片文件')
    return false
  }
  if (file.size > 2 * 1024 * 1024) {
    ElMessage.error('图片大小不能超过2MB')
    return false
  }

  try {
    const formData = new FormData()
    formData.append('file', file)
    const result = await authApi.uploadAvatar(formData)
    profile.avatar_url = result.url
    ElMessage.success('头像上传成功')
  } catch (e) {
    ElMessage.error('头像上传失败')
  }
  return false
}

const saveInfo = async () => {
  if (!infoFormRef.value) return
  await infoFormRef.value.validate(async (valid) => {
    if (!valid) return

    saving.value = true
    try {
      await authApi.updateProfile(infoForm)
      Object.assign(profile, infoForm)
      authStore.setAdmin({ ...authStore.admin!, ...infoForm } as any)
      ElMessage.success('保存成功')
    } catch (e) {
      ElMessage.error('保存失败')
    } finally {
      saving.value = false
    }
  })
}

const changePassword = async () => {
  if (!passwordFormRef.value) return
  await passwordFormRef.value.validate(async (valid) => {
    if (!valid) return

    saving.value = true
    try {
      await authApi.changePassword({
        current_password: passwordForm.current_password,
        new_password: passwordForm.new_password,
      })
      ElMessage.success('密码修改成功')
      passwordForm.current_password = ''
      passwordForm.new_password = ''
      passwordForm.confirm_password = ''
    } catch (e) {
      ElMessage.error('密码修改失败，请检查当前密码是否正确')
    } finally {
      saving.value = false
    }
  })
}

const setupMFA = async () => {
  try {
    const data = await authApi.setupMFA()
    mfaSetup.qr_code = data.qr_code
    mfaSetup.secret = data.secret
    mfaSetup.code = ''
    mfaSetup.step = 1
    mfaDialogVisible.value = true
  } catch (e) {
    ElMessage.error('获取MFA设置失败')
  }
}

const verifyMFA = async () => {
  if (!mfaSetup.code || mfaSetup.code.length !== 6) {
    ElMessage.warning('请输入6位验证码')
    return
  }

  saving.value = true
  try {
    await authApi.verifyMFA(mfaSetup.code)
    profile.mfa_enabled = true
    profile.mfa_type = 'totp'
    mfaDialogVisible.value = false
    ElMessage.success('MFA启用成功')
  } catch (e) {
    ElMessage.error('验证码错误，请重试')
  } finally {
    saving.value = false
  }
}

const disableMFA = async () => {
  try {
    await ElMessageBox.confirm('确定要禁用多因素认证吗？这将降低账号安全性', '确认禁用', {
      type: 'warning',
    })
    await authApi.disableMFA()
    profile.mfa_enabled = false
    ElMessage.success('MFA已禁用')
  } catch (e: any) {
    if (e !== 'cancel') {
      ElMessage.error('禁用MFA失败')
    }
  }
}

// Formatters
const formatDateTime = (date: string | undefined) => {
  if (!date) return '-'
  return new Date(date).toLocaleString('zh-CN')
}

// Init
onMounted(() => {
  fetchProfile()
  fetchLoginHistory()
})
</script>

<style scoped lang="scss">
.profile-settings {
  .profile-card {
    text-align: center;
    padding: 20px;

    .avatar-uploader {
      position: relative;
      display: inline-block;
      cursor: pointer;

      .avatar-overlay {
        position: absolute;
        top: 0;
        left: 0;
        width: 100px;
        height: 100px;
        border-radius: 50%;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        opacity: 0;
        transition: opacity 0.3s;

        .el-icon {
          color: #fff;
          font-size: 24px;
        }
      }

      &:hover .avatar-overlay {
        opacity: 1;
      }
    }

    h3 {
      margin: 16px 0 8px;
      font-size: 18px;
    }

    p {
      margin: 0 0 12px;
    }
  }

  .mfa-setup {
    text-align: center;

    .qr-code {
      display: flex;
      justify-content: center;

      img {
        width: 200px;
        height: 200px;
      }
    }
  }
}
</style>
