<template>
  <div class="security-settings">
    <div class="page-header">
      <h2 class="page-title">安全设置</h2>
    </div>

    <el-row :gutter="20">
      <el-col :span="12">
        <!-- Password Policy -->
        <el-card class="mb-20">
          <template #header>密码策略</template>
          <el-form :model="passwordPolicy" label-width="150px">
            <el-form-item label="最小长度">
              <el-input-number v-model="passwordPolicy.min_length" :min="6" :max="32" />
            </el-form-item>
            <el-form-item label="要求大写字母">
              <el-switch v-model="passwordPolicy.require_uppercase" />
            </el-form-item>
            <el-form-item label="要求小写字母">
              <el-switch v-model="passwordPolicy.require_lowercase" />
            </el-form-item>
            <el-form-item label="要求数字">
              <el-switch v-model="passwordPolicy.require_number" />
            </el-form-item>
            <el-form-item label="要求特殊字符">
              <el-switch v-model="passwordPolicy.require_special" />
            </el-form-item>
            <el-form-item label="密码有效期">
              <el-input-number v-model="passwordPolicy.expires_days" :min="0" :max="365" />
              <span class="ml-10">天 (0表示永不过期)</span>
            </el-form-item>
            <el-form-item label="历史密码检查">
              <el-input-number v-model="passwordPolicy.history_count" :min="0" :max="24" />
              <span class="ml-10">次 (不能使用最近N次密码)</span>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="savePasswordPolicy">保存</el-button>
            </el-form-item>
          </el-form>
        </el-card>

        <!-- Login Security -->
        <el-card class="mb-20">
          <template #header>登录安全</template>
          <el-form :model="loginSecurity" label-width="150px">
            <el-form-item label="登录失败锁定">
              <el-switch v-model="loginSecurity.enable_lockout" />
            </el-form-item>
            <el-form-item label="失败次数上限">
              <el-input-number v-model="loginSecurity.max_attempts" :min="3" :max="10" :disabled="!loginSecurity.enable_lockout" />
            </el-form-item>
            <el-form-item label="锁定时间">
              <el-input-number v-model="loginSecurity.lockout_minutes" :min="5" :max="1440" :disabled="!loginSecurity.enable_lockout" />
              <span class="ml-10">分钟</span>
            </el-form-item>
            <el-form-item label="登录验证码">
              <el-switch v-model="loginSecurity.enable_captcha" />
            </el-form-item>
            <el-form-item label="验证码触发次数">
              <el-input-number v-model="loginSecurity.captcha_threshold" :min="1" :max="5" :disabled="!loginSecurity.enable_captcha" />
              <span class="ml-10">次失败后显示验证码</span>
            </el-form-item>
            <el-form-item label="单点登录">
              <el-switch v-model="loginSecurity.single_session" />
              <span class="ml-10 text-muted">开启后同一账号只能在一处登录</span>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveLoginSecurity">保存</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>

      <el-col :span="12">
        <!-- Session Settings -->
        <el-card class="mb-20">
          <template #header>会话设置</template>
          <el-form :model="sessionSettings" label-width="150px">
            <el-form-item label="会话超时">
              <el-input-number v-model="sessionSettings.timeout_minutes" :min="5" :max="1440" />
              <span class="ml-10">分钟</span>
            </el-form-item>
            <el-form-item label="记住登录">
              <el-switch v-model="sessionSettings.enable_remember" />
            </el-form-item>
            <el-form-item label="记住时间">
              <el-input-number v-model="sessionSettings.remember_days" :min="1" :max="30" :disabled="!sessionSettings.enable_remember" />
              <span class="ml-10">天</span>
            </el-form-item>
            <el-form-item label="Token刷新">
              <el-switch v-model="sessionSettings.auto_refresh" />
              <span class="ml-10 text-muted">自动刷新快过期的Token</span>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveSessionSettings">保存</el-button>
            </el-form-item>
          </el-form>
        </el-card>

        <!-- MFA Settings -->
        <el-card class="mb-20">
          <template #header>多因素认证</template>
          <el-form :model="mfaSettings" label-width="150px">
            <el-form-item label="启用MFA">
              <el-switch v-model="mfaSettings.enable_mfa" />
            </el-form-item>
            <el-form-item label="强制MFA">
              <el-switch v-model="mfaSettings.require_mfa" :disabled="!mfaSettings.enable_mfa" />
              <span class="ml-10 text-muted">要求所有管理员启用MFA</span>
            </el-form-item>
            <el-form-item label="MFA方式">
              <el-checkbox-group v-model="mfaSettings.mfa_methods" :disabled="!mfaSettings.enable_mfa">
                <el-checkbox label="totp">TOTP验证器</el-checkbox>
                <el-checkbox label="email">邮箱验证</el-checkbox>
                <el-checkbox label="sms">短信验证</el-checkbox>
              </el-checkbox-group>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" :loading="saving" @click="saveMfaSettings">保存</el-button>
            </el-form-item>
          </el-form>
        </el-card>

        <!-- IP Whitelist -->
        <el-card>
          <template #header>
            <div class="card-header">
              <span>IP白名单</span>
              <el-switch v-model="ipWhitelist.enabled" @change="saveIpWhitelist" />
            </div>
          </template>
          <el-alert v-if="ipWhitelist.enabled" type="warning" :closable="false" class="mb-20">
            启用IP白名单后，只有白名单中的IP地址可以访问管理后台
          </el-alert>
          <el-form-item label="白名单IP">
            <el-input
              v-model="ipWhitelist.ips"
              type="textarea"
              rows="6"
              placeholder="每行一个IP地址或CIDR&#10;例如:&#10;192.168.1.100&#10;10.0.0.0/24"
              :disabled="!ipWhitelist.enabled"
            />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" :loading="saving" :disabled="!ipWhitelist.enabled" @click="saveIpWhitelist">
              保存
            </el-button>
          </el-form-item>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import * as settingsApi from '@/api/settings'

// State
const saving = ref(false)

const passwordPolicy = reactive({
  min_length: 8,
  require_uppercase: true,
  require_lowercase: true,
  require_number: true,
  require_special: false,
  expires_days: 90,
  history_count: 5,
})

const loginSecurity = reactive({
  enable_lockout: true,
  max_attempts: 5,
  lockout_minutes: 30,
  enable_captcha: true,
  captcha_threshold: 3,
  single_session: false,
})

const sessionSettings = reactive({
  timeout_minutes: 60,
  enable_remember: true,
  remember_days: 7,
  auto_refresh: true,
})

const mfaSettings = reactive({
  enable_mfa: true,
  require_mfa: false,
  mfa_methods: ['totp'] as string[],
})

const ipWhitelist = reactive({
  enabled: false,
  ips: '',
})

// Fetch settings
const fetchSettings = async () => {
  try {
    const data = await settingsApi.getSecuritySettings()
    if (data.password_policy) Object.assign(passwordPolicy, data.password_policy)
    if (data.login_security) Object.assign(loginSecurity, data.login_security)
    if (data.session) Object.assign(sessionSettings, data.session)
    if (data.mfa) Object.assign(mfaSettings, data.mfa)
    if (data.ip_whitelist) Object.assign(ipWhitelist, data.ip_whitelist)
  } catch (e) {
    ElMessage.error('获取安全设置失败')
  }
}

// Save handlers
const savePasswordPolicy = async () => {
  saving.value = true
  try {
    await settingsApi.updateSecuritySettings({ password_policy: passwordPolicy })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const saveLoginSecurity = async () => {
  saving.value = true
  try {
    await settingsApi.updateSecuritySettings({ login_security: loginSecurity })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const saveSessionSettings = async () => {
  saving.value = true
  try {
    await settingsApi.updateSecuritySettings({ session: sessionSettings })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const saveMfaSettings = async () => {
  saving.value = true
  try {
    await settingsApi.updateSecuritySettings({ mfa: mfaSettings })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

const saveIpWhitelist = async () => {
  saving.value = true
  try {
    await settingsApi.updateSecuritySettings({ ip_whitelist: ipWhitelist })
    ElMessage.success('保存成功')
  } catch (e) {
    ElMessage.error('保存失败')
  } finally {
    saving.value = false
  }
}

// Init
onMounted(() => {
  fetchSettings()
})
</script>

<style scoped lang="scss">
.security-settings {
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
}
</style>
