<template>
  <div class="system-settings">
    <div class="page-header">
      <h2 class="page-title">系统设置</h2>
    </div>

    <el-tabs v-model="activeTab">
      <!-- Basic Settings -->
      <el-tab-pane label="基础设置" name="basic">
        <el-card>
          <el-form ref="basicFormRef" :model="basicSettings" label-width="150px">
            <el-form-item label="系统名称">
              <el-input v-model="basicSettings.system_name" style="width: 300px;" />
            </el-form-item>
            <el-form-item label="系统Logo">
              <el-upload
                class="logo-uploader"
                :show-file-list="false"
                :before-upload="handleLogoUpload"
              >
                <img v-if="basicSettings.logo_url" :src="basicSettings.logo_url" class="logo-preview" />
                <el-icon v-else class="logo-uploader-icon"><Plus /></el-icon>
              </el-upload>
            </el-form-item>
            <el-form-item label="版权信息">
              <el-input v-model="basicSettings.copyright" style="width: 400px;" />
            </el-form-item>
            <el-form-item label="ICP备案号">
              <el-input v-model="basicSettings.icp_number" style="width: 300px;" />
            </el-form-item>
            <el-form-item label="维护模式">
              <el-switch v-model="basicSettings.maintenance_mode" />
              <span class="ml-10 text-muted">开启后用户将无法访问系统</span>
            </el-form-item>
            <el-form-item label="维护提示">
              <el-input
                v-model="basicSettings.maintenance_message"
                type="textarea"
                rows="3"
                style="width: 400px;"
                :disabled="!basicSettings.maintenance_mode"
              />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveBasicSettings">保存设置</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-tab-pane>

      <!-- Email Settings -->
      <el-tab-pane label="邮件设置" name="email">
        <el-card>
          <el-form ref="emailFormRef" :model="emailSettings" :rules="emailRules" label-width="150px">
            <el-form-item label="SMTP服务器" prop="smtp_host">
              <el-input v-model="emailSettings.smtp_host" style="width: 300px;" placeholder="smtp.example.com" />
            </el-form-item>
            <el-form-item label="SMTP端口" prop="smtp_port">
              <el-input-number v-model="emailSettings.smtp_port" :min="1" :max="65535" />
            </el-form-item>
            <el-form-item label="加密方式">
              <el-radio-group v-model="emailSettings.smtp_encryption">
                <el-radio label="none">无</el-radio>
                <el-radio label="ssl">SSL</el-radio>
                <el-radio label="tls">TLS</el-radio>
              </el-radio-group>
            </el-form-item>
            <el-form-item label="SMTP用户名" prop="smtp_username">
              <el-input v-model="emailSettings.smtp_username" style="width: 300px;" />
            </el-form-item>
            <el-form-item label="SMTP密码" prop="smtp_password">
              <el-input v-model="emailSettings.smtp_password" type="password" style="width: 300px;" show-password />
            </el-form-item>
            <el-form-item label="发件人地址" prop="from_email">
              <el-input v-model="emailSettings.from_email" style="width: 300px;" placeholder="noreply@example.com" />
            </el-form-item>
            <el-form-item label="发件人名称">
              <el-input v-model="emailSettings.from_name" style="width: 300px;" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveEmailSettings">保存设置</el-button>
              <el-button @click="testEmail">发送测试邮件</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-tab-pane>

      <!-- Storage Settings -->
      <el-tab-pane label="存储设置" name="storage">
        <el-card>
          <el-form ref="storageFormRef" :model="storageSettings" label-width="150px">
            <el-form-item label="存储类型">
              <el-radio-group v-model="storageSettings.storage_type">
                <el-radio label="local">本地存储</el-radio>
                <el-radio label="oss">阿里云OSS</el-radio>
                <el-radio label="cos">腾讯云COS</el-radio>
                <el-radio label="s3">AWS S3</el-radio>
              </el-radio-group>
            </el-form-item>

            <!-- Local Storage -->
            <template v-if="storageSettings.storage_type === 'local'">
              <el-form-item label="存储路径">
                <el-input v-model="storageSettings.local_path" style="width: 400px;" />
              </el-form-item>
              <el-form-item label="访问URL">
                <el-input v-model="storageSettings.local_url" style="width: 400px;" />
              </el-form-item>
            </template>

            <!-- Cloud Storage -->
            <template v-else>
              <el-form-item label="Access Key">
                <el-input v-model="storageSettings.access_key" style="width: 300px;" />
              </el-form-item>
              <el-form-item label="Secret Key">
                <el-input v-model="storageSettings.secret_key" type="password" style="width: 300px;" show-password />
              </el-form-item>
              <el-form-item label="Bucket名称">
                <el-input v-model="storageSettings.bucket" style="width: 300px;" />
              </el-form-item>
              <el-form-item label="区域/Endpoint">
                <el-input v-model="storageSettings.region" style="width: 300px;" />
              </el-form-item>
              <el-form-item label="CDN域名">
                <el-input v-model="storageSettings.cdn_domain" style="width: 300px;" placeholder="https://cdn.example.com" />
              </el-form-item>
            </template>

            <el-form-item label="最大文件大小">
              <el-input-number v-model="storageSettings.max_file_size" :min="1" :max="100" />
              <span class="ml-10">MB</span>
            </el-form-item>
            <el-form-item label="允许的文件类型">
              <el-input v-model="storageSettings.allowed_types" style="width: 400px;" placeholder="jpg,png,gif,pdf,xlsx" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveStorageSettings">保存设置</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-tab-pane>

      <!-- Notification Settings -->
      <el-tab-pane label="通知设置" name="notification">
        <el-card>
          <el-form :model="notificationSettings" label-width="150px">
            <el-divider content-position="left">系统通知</el-divider>
            <el-form-item label="新用户注册">
              <el-checkbox-group v-model="notificationSettings.new_user">
                <el-checkbox label="email">邮件</el-checkbox>
                <el-checkbox label="sms">短信</el-checkbox>
                <el-checkbox label="webhook">Webhook</el-checkbox>
              </el-checkbox-group>
            </el-form-item>
            <el-form-item label="系统告警">
              <el-checkbox-group v-model="notificationSettings.system_alert">
                <el-checkbox label="email">邮件</el-checkbox>
                <el-checkbox label="sms">短信</el-checkbox>
                <el-checkbox label="webhook">Webhook</el-checkbox>
              </el-checkbox-group>
            </el-form-item>
            <el-form-item label="备份完成">
              <el-checkbox-group v-model="notificationSettings.backup_complete">
                <el-checkbox label="email">邮件</el-checkbox>
                <el-checkbox label="webhook">Webhook</el-checkbox>
              </el-checkbox-group>
            </el-form-item>

            <el-divider content-position="left">Webhook配置</el-divider>
            <el-form-item label="Webhook URL">
              <el-input v-model="notificationSettings.webhook_url" style="width: 400px;" placeholder="https://example.com/webhook" />
            </el-form-item>
            <el-form-item label="Webhook密钥">
              <el-input v-model="notificationSettings.webhook_secret" style="width: 300px;" />
            </el-form-item>

            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveNotificationSettings">保存设置</el-button>
              <el-button @click="testWebhook">测试Webhook</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, type FormInstance, type FormRules, type UploadRawFile } from 'element-plus'
import * as settingsApi from '@/api/settings'

// State
const activeTab = ref('basic')
const saving = ref(false)

// Basic settings
const basicFormRef = ref<FormInstance>()
const basicSettings = reactive({
  system_name: '',
  logo_url: '',
  copyright: '',
  icp_number: '',
  maintenance_mode: false,
  maintenance_message: '',
})

// Email settings
const emailFormRef = ref<FormInstance>()
const emailSettings = reactive({
  smtp_host: '',
  smtp_port: 587,
  smtp_encryption: 'tls',
  smtp_username: '',
  smtp_password: '',
  from_email: '',
  from_name: '',
})
const emailRules: FormRules = {
  smtp_host: [{ required: true, message: '请输入SMTP服务器', trigger: 'blur' }],
  smtp_port: [{ required: true, message: '请输入SMTP端口', trigger: 'blur' }],
  smtp_username: [{ required: true, message: '请输入SMTP用户名', trigger: 'blur' }],
  from_email: [{ required: true, type: 'email', message: '请输入有效的邮箱地址', trigger: 'blur' }],
}

// Storage settings
const storageFormRef = ref<FormInstance>()
const storageSettings = reactive({
  storage_type: 'local',
  local_path: '/uploads',
  local_url: '/uploads',
  access_key: '',
  secret_key: '',
  bucket: '',
  region: '',
  cdn_domain: '',
  max_file_size: 10,
  allowed_types: 'jpg,png,gif,pdf,xlsx',
})

// Notification settings
const notificationSettings = reactive({
  new_user: ['email'] as string[],
  system_alert: ['email', 'webhook'] as string[],
  backup_complete: ['email'] as string[],
  webhook_url: '',
  webhook_secret: '',
})

// Fetch settings
const fetchSettings = async () => {
  try {
    const data = await settingsApi.getSystemSettings()
    if (data.basic) Object.assign(basicSettings, data.basic)
    if (data.email) Object.assign(emailSettings, data.email)
    if (data.storage) Object.assign(storageSettings, data.storage)
    if (data.notification) Object.assign(notificationSettings, data.notification)
  } catch (e) {
    ElMessage.error('获取系统设置失败')
  }
}

// Handlers
const handleLogoUpload = async (file: UploadRawFile) => {
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
    const result = await settingsApi.uploadLogo(formData)
    basicSettings.logo_url = result.url
    ElMessage.success('Logo上传成功')
  } catch (e) {
    ElMessage.error('Logo上传失败')
  }
  return false
}

const saveBasicSettings = async () => {
  saving.value = true
  try {
    await settingsApi.updateSystemSettings({ basic: basicSettings })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const saveEmailSettings = async () => {
  if (!emailFormRef.value) return
  await emailFormRef.value.validate(async (valid) => {
    if (!valid) return

    saving.value = true
    try {
      await settingsApi.updateSystemSettings({ email: emailSettings })
      ElMessage.success('保存成功')
    } catch (e) {
      ElMessage.error('保存失败')
    } finally {
      saving.value = false
    }
  })
}

const testEmail = async () => {
  try {
    await settingsApi.testEmailSettings()
    ElMessage.success('测试邮件已发送')
  } catch (e) {
    ElMessage.error('发送测试邮件失败')
  }
}

const saveStorageSettings = async () => {
  saving.value = true
  try {
    await settingsApi.updateSystemSettings({ storage: storageSettings })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const saveNotificationSettings = async () => {
  saving.value = true
  try {
    await settingsApi.updateSystemSettings({ notification: notificationSettings })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const testWebhook = async () => {
  if (!notificationSettings.webhook_url) {
    ElMessage.warning('请先配置Webhook URL')
    return
  }
  try {
    await settingsApi.testWebhook(notificationSettings.webhook_url)
    ElMessage.success('Webhook测试成功')
  } catch (e) {
    ElMessage.error('Webhook测试失败')
  }
}

// Init
onMounted(() => {
  fetchSettings()
})
</script>

<style scoped lang="scss">
.system-settings {
  .logo-uploader {
    :deep(.el-upload) {
      border: 1px dashed #d9d9d9;
      border-radius: 6px;
      cursor: pointer;
      position: relative;
      overflow: hidden;
      transition: border-color 0.3s;

      &:hover {
        border-color: #6495ED;
      }
    }

    .logo-preview {
      width: 100px;
      height: 100px;
      object-fit: contain;
    }

    .logo-uploader-icon {
      font-size: 28px;
      color: #8c939d;
      width: 100px;
      height: 100px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }
}
</style>
