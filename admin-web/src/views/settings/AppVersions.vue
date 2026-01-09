<template>
  <div class="app-versions-page">
    <div class="page-header">
      <h2 class="page-title">APP版本管理</h2>
      <el-button type="primary" @click="showCreateDialog">
        <el-icon><Plus /></el-icon>新增版本
      </el-button>
    </div>

    <!-- Filter Form -->
    <div class="filter-form">
      <el-form :model="filters" inline>
        <el-form-item label="平台">
          <el-select v-model="filters.platform">
            <el-option label="Android" value="android" />
            <el-option label="iOS" value="ios" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filters.status" placeholder="全部" clearable>
            <el-option label="草稿" :value="0" />
            <el-option label="已发布" :value="1" />
            <el-option label="已废弃" :value="2" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="fetchVersions">
            <el-icon><Search /></el-icon>搜索
          </el-button>
        </el-form-item>
      </el-form>
    </div>

    <!-- Version Table -->
    <div class="table-container">
      <el-table v-loading="loading" :data="versions" stripe>
        <el-table-column prop="version_name" label="版本号" width="120">
          <template #default="{ row }">
            {{ row.version_name }}+{{ row.version_code }}
          </template>
        </el-table-column>
        <el-table-column prop="platform" label="平台" width="100">
          <template #default="{ row }">
            <el-tag size="small">{{ row.platform === 'android' ? 'Android' : 'iOS' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status_text" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="getStatusType(row.status)" size="small">{{ row.status_text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="is_force_update" label="强制更新" width="90">
          <template #default="{ row }">
            <el-tag :type="row.is_force_update ? 'danger' : 'info'" size="small">
              {{ row.is_force_update ? '是' : '否' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="rollout_percentage" label="灰度比例" width="100">
          <template #default="{ row }">
            <el-tag :type="row.rollout_percentage < 100 ? 'warning' : 'success'" size="small">
              {{ row.rollout_percentage }}%
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="min_supported_version" label="最低版本" width="100">
          <template #default="{ row }">
            {{ row.min_supported_version || '-' }}
          </template>
        </el-table-column>
        <el-table-column prop="file_size_formatted" label="APK大小" width="100" />
        <el-table-column prop="patch_file_size_formatted" label="增量包" width="100">
          <template #default="{ row }">
            <span v-if="row.patch_file_url" class="patch-info">
              {{ row.patch_file_size_formatted }}
              <el-tooltip :content="`从 ${row.patch_from_version}+${row.patch_from_code} 升级`">
                <el-icon><InfoFilled /></el-icon>
              </el-tooltip>
            </span>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column prop="published_at" label="发布时间" width="160">
          <template #default="{ row }">
            {{ row.published_at ? formatDateTime(row.published_at) : '-' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="320" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text size="small" @click="showDetail(row)">详情</el-button>
            <el-button
              v-if="row.status === 0"
              type="warning"
              text
              size="small"
              @click="handleUploadApk(row)"
            >
              上传APK
            </el-button>
            <el-button
              v-if="row.status === 0 && row.file_url"
              type="info"
              text
              size="small"
              @click="handleUploadPatch(row)"
            >
              增量包
            </el-button>
            <el-button
              v-if="row.status !== 2"
              type="primary"
              text
              size="small"
              @click="showRolloutDialog(row)"
            >
              灰度
            </el-button>
            <el-button
              v-if="row.status === 0 && row.file_url"
              type="success"
              text
              size="small"
              @click="handlePublish(row)"
            >
              发布
            </el-button>
            <el-button
              v-if="row.status === 1"
              type="warning"
              text
              size="small"
              @click="handleDeprecate(row)"
            >
              废弃
            </el-button>
            <el-button
              v-if="row.status === 0"
              type="danger"
              text
              size="small"
              @click="handleDelete(row)"
            >
              删除
            </el-button>
            <el-button
              v-if="row.status === 2"
              type="danger"
              text
              size="small"
              @click="handleDeleteDeprecated(row)"
            >
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-container">
        <el-pagination
          v-model:current-page="pagination.page"
          v-model:page-size="pagination.pageSize"
          :total="pagination.total"
          :page-sizes="[20, 50, 100]"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </div>

    <!-- Create Version Dialog -->
    <el-dialog v-model="createDialogVisible" title="新增版本" width="600px">
      <el-form ref="createFormRef" :model="createForm" :rules="createRules" label-width="120px">
        <el-form-item label="版本号" prop="version_name">
          <el-input v-model="createForm.version_name" placeholder="如 1.2.2 (格式: x.y.z)" />
          <div class="form-tip">格式要求: 主版本.次版本.修订版本，如 1.2.3</div>
        </el-form-item>
        <el-form-item label="构建号" prop="version_code">
          <el-input-number v-model="createForm.version_code" :min="1" />
        </el-form-item>
        <el-form-item label="平台" prop="platform">
          <el-select v-model="createForm.platform">
            <el-option label="Android" value="android" />
            <el-option label="iOS" value="ios" />
          </el-select>
        </el-form-item>
        <el-form-item label="更新说明" prop="release_notes">
          <el-input
            v-model="createForm.release_notes"
            type="textarea"
            :rows="4"
            placeholder="支持Markdown格式"
          />
        </el-form-item>
        <el-form-item label="英文更新说明">
          <el-input
            v-model="createForm.release_notes_en"
            type="textarea"
            :rows="4"
          />
        </el-form-item>
        <el-form-item label="强制更新">
          <el-switch v-model="createForm.is_force_update" />
        </el-form-item>
        <el-form-item label="最低支持版本">
          <el-input
            v-model="createForm.min_supported_version"
            placeholder="如 1.0.0，低于此版本强制更新"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="creating" @click="handleCreate">创建</el-button>
      </template>
    </el-dialog>

    <!-- Detail Dialog -->
    <el-dialog v-model="detailDialogVisible" title="版本详情" width="700px">
      <el-descriptions :column="2" border v-if="currentVersion">
        <el-descriptions-item label="版本号">
          {{ currentVersion.version_name }}+{{ currentVersion.version_code }}
        </el-descriptions-item>
        <el-descriptions-item label="平台">
          {{ currentVersion.platform === 'android' ? 'Android' : 'iOS' }}
        </el-descriptions-item>
        <el-descriptions-item label="状态">
          <el-tag :type="getStatusType(currentVersion.status)" size="small">
            {{ currentVersion.status_text }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="强制更新">
          <el-tag :type="currentVersion.is_force_update ? 'danger' : 'info'" size="small">
            {{ currentVersion.is_force_update ? '是' : '否' }}
          </el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="灰度发布">
          <el-tag :type="currentVersion.rollout_percentage < 100 ? 'warning' : 'success'" size="small">
            {{ currentVersion.rollout_percentage }}%
          </el-tag>
          <span v-if="currentVersion.rollout_start_date" class="rollout-date">
            ({{ formatDateTime(currentVersion.rollout_start_date) }} 开始)
          </span>
        </el-descriptions-item>
        <el-descriptions-item label="最低支持版本">
          {{ currentVersion.min_supported_version || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="APK大小">
          {{ currentVersion.file_size_formatted }}
        </el-descriptions-item>
        <el-descriptions-item label="APK MD5">
          {{ currentVersion.file_md5 || '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="增量包信息" :span="2" v-if="currentVersion.patch_file_url">
          <div class="patch-detail">
            <span>基础版本: {{ currentVersion.patch_from_version }}+{{ currentVersion.patch_from_code }}</span>
            <span>大小: {{ currentVersion.patch_file_size_formatted }}</span>
            <span>MD5: {{ currentVersion.patch_file_md5 }}</span>
          </div>
        </el-descriptions-item>
        <el-descriptions-item label="更新说明" :span="2">
          <pre class="release-notes">{{ currentVersion.release_notes }}</pre>
        </el-descriptions-item>
        <el-descriptions-item label="创建人">{{ currentVersion.created_by || '-' }}</el-descriptions-item>
        <el-descriptions-item label="创建时间">
          {{ formatDateTime(currentVersion.created_at) }}
        </el-descriptions-item>
        <el-descriptions-item label="发布时间" :span="2">
          {{ currentVersion.published_at ? formatDateTime(currentVersion.published_at) : '-' }}
        </el-descriptions-item>
        <el-descriptions-item label="下载地址" :span="2" v-if="currentVersion.file_url">
          <el-link :href="currentVersion.file_url" target="_blank" type="primary">
            {{ currentVersion.file_url }}
          </el-link>
        </el-descriptions-item>
      </el-descriptions>
      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>

    <!-- Upload APK Dialog -->
    <el-dialog v-model="uploadDialogVisible" title="上传APK" width="500px">
      <el-upload
        ref="uploadRef"
        class="upload-apk"
        drag
        :auto-upload="false"
        :limit="1"
        accept=".apk"
        :on-change="handleFileChange"
        :on-exceed="handleExceed"
      >
        <el-icon class="el-icon--upload"><UploadFilled /></el-icon>
        <div class="el-upload__text">
          将APK文件拖到此处，或<em>点击上传</em>
        </div>
        <template #tip>
          <div class="el-upload__tip">
            只能上传 .apk 文件
          </div>
        </template>
      </el-upload>
      <template #footer>
        <el-button @click="uploadDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="uploading" @click="confirmUpload">上传</el-button>
      </template>
    </el-dialog>

    <!-- Upload Patch Dialog -->
    <el-dialog v-model="patchDialogVisible" title="上传增量更新包" width="550px">
      <el-form ref="patchFormRef" :model="patchForm" :rules="patchRules" label-width="120px">
        <el-alert
          type="info"
          :closable="false"
          show-icon
          style="margin-bottom: 16px;"
        >
          增量包由 bsdiff 工具生成，用于从旧版本升级到当前版本
        </el-alert>
        <el-form-item label="基础版本号" prop="patch_from_version">
          <el-input v-model="patchForm.patch_from_version" placeholder="如 1.2.0" />
        </el-form-item>
        <el-form-item label="基础构建号" prop="patch_from_code">
          <el-input-number v-model="patchForm.patch_from_code" :min="1" :max="patchMaxCode" />
          <div class="form-tip">必须小于目标版本构建号 {{ patchMaxCode + 1 }}</div>
        </el-form-item>
        <el-form-item label="补丁文件" prop="file">
          <el-upload
            ref="patchUploadRef"
            class="upload-patch"
            drag
            :auto-upload="false"
            :limit="1"
            accept=".patch"
            :on-change="handlePatchFileChange"
            :on-exceed="handlePatchExceed"
          >
            <el-icon class="el-icon--upload"><UploadFilled /></el-icon>
            <div class="el-upload__text">
              将 .patch 文件拖到此处，或<em>点击上传</em>
            </div>
          </el-upload>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="patchDialogVisible = false">取消</el-button>
        <el-button
          v-if="currentVersion?.patch_file_url"
          type="danger"
          :loading="deletingPatch"
          @click="handleDeletePatch"
        >
          删除现有补丁
        </el-button>
        <el-button type="primary" :loading="uploadingPatch" @click="confirmUploadPatch">上传</el-button>
      </template>
    </el-dialog>

    <!-- Rollout Settings Dialog -->
    <el-dialog v-model="rolloutDialogVisible" title="灰度发布设置" width="500px">
      <el-form :model="rolloutForm" label-width="120px">
        <el-form-item label="当前版本">
          <span class="version-label">{{ rolloutVersionInfo }}</span>
        </el-form-item>
        <el-form-item label="发布比例">
          <el-slider
            v-model="rolloutForm.rollout_percentage"
            :min="0"
            :max="100"
            :step="5"
            show-stops
            show-input
          />
          <div class="form-tip">
            设置 0-100% 的用户可以看到此更新。100% 表示全量发布。
          </div>
        </el-form-item>
        <el-form-item label="发布时间">
          <el-date-picker
            v-model="rolloutForm.rollout_start_date"
            type="datetime"
            placeholder="选择灰度发布开始时间"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DDTHH:mm:ss"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="rolloutDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="updatingRollout" @click="confirmRollout">保存</el-button>
      </template>
    </el-dialog>

    <!-- Delete Deprecated Version Dialog -->
    <el-dialog v-model="deleteDialogVisible" title="删除废弃版本" width="450px">
      <div class="delete-dialog-content">
        <el-alert
          type="warning"
          :closable="false"
          show-icon
          style="margin-bottom: 16px;"
        >
          <template #title>
            <span>您正在删除废弃版本 <strong>{{ deleteVersionInfo }}</strong></span>
          </template>
          <template #default>
            此操作不可恢复，APK文件也将被删除。请输入管理员密码确认。
          </template>
        </el-alert>
        <el-form @submit.prevent="confirmDeleteDeprecated">
          <el-form-item label="管理员密码" required>
            <el-input
              v-model="deletePassword"
              type="password"
              placeholder="请输入您的管理员密码"
              show-password
              @keyup.enter="confirmDeleteDeprecated"
            />
          </el-form-item>
        </el-form>
      </div>
      <template #footer>
        <el-button @click="deleteDialogVisible = false">取消</el-button>
        <el-button type="danger" :loading="deleting" @click="confirmDeleteDeprecated">确认删除</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Plus, Search, UploadFilled, InfoFilled } from '@element-plus/icons-vue'
import type { FormInstance, UploadInstance, UploadFile } from 'element-plus'
import dayjs from 'dayjs'
import {
  getAppVersions,
  createAppVersion,
  updateAppVersion,
  uploadApk,
  uploadPatch,
  deletePatch,
  publishVersion,
  deprecateVersion,
  deleteAppVersion,
  deleteDeprecatedVersion,
  type AppVersion,
  type AppVersionCreate
} from '@/api/appVersions'

// State
const loading = ref(false)
const creating = ref(false)
const uploading = ref(false)
const uploadingPatch = ref(false)
const deletingPatch = ref(false)
const updatingRollout = ref(false)
const deleting = ref(false)
const versions = ref<AppVersion[]>([])
const currentVersion = ref<AppVersion | null>(null)
const selectedFile = ref<File | null>(null)
const selectedPatchFile = ref<File | null>(null)
const uploadVersionId = ref('')
const deleteVersionId = ref('')
const deleteVersionInfo = ref('')
const deletePassword = ref('')

// Dialogs
const createDialogVisible = ref(false)
const detailDialogVisible = ref(false)
const uploadDialogVisible = ref(false)
const patchDialogVisible = ref(false)
const rolloutDialogVisible = ref(false)
const deleteDialogVisible = ref(false)

// Refs
const createFormRef = ref<FormInstance>()
const patchFormRef = ref<FormInstance>()
const uploadRef = ref<UploadInstance>()
const patchUploadRef = ref<UploadInstance>()

// Filters
const filters = reactive({
  platform: 'android',
  status: null as number | null
})

// Pagination
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0
})

// Version name validator
const validateVersionName = (rule: any, value: string, callback: any) => {
  if (!value) {
    callback(new Error('请输入版本号'))
  } else if (!/^\d+\.\d+\.\d+$/.test(value)) {
    callback(new Error('版本号格式错误，应为 x.y.z 格式'))
  } else {
    callback()
  }
}

// Create form
const createForm = reactive<AppVersionCreate>({
  version_name: '',
  version_code: 1,
  platform: 'android',
  release_notes: '',
  release_notes_en: '',
  is_force_update: false,
  min_supported_version: ''
})

const createRules = {
  version_name: [{ required: true, validator: validateVersionName, trigger: 'blur' }],
  version_code: [{ required: true, message: '请输入构建号', trigger: 'blur' }],
  platform: [{ required: true, message: '请选择平台', trigger: 'change' }],
  release_notes: [{ required: true, message: '请输入更新说明', trigger: 'blur' }]
}

// Patch form
const patchForm = reactive({
  patch_from_version: '',
  patch_from_code: 1
})

const patchMaxCode = computed(() => {
  return currentVersion.value ? currentVersion.value.version_code - 1 : 999
})

const patchRules = {
  patch_from_version: [{ required: true, validator: validateVersionName, trigger: 'blur' }],
  patch_from_code: [{ required: true, message: '请输入基础构建号', trigger: 'blur' }]
}

// Rollout form
const rolloutForm = reactive({
  rollout_percentage: 100,
  rollout_start_date: null as string | null
})

const rolloutVersionInfo = computed(() => {
  if (!currentVersion.value) return ''
  return `${currentVersion.value.version_name}+${currentVersion.value.version_code}`
})

// Methods
const fetchVersions = async () => {
  loading.value = true
  try {
    const params: any = {
      platform: filters.platform,
      skip: (pagination.page - 1) * pagination.pageSize,
      limit: pagination.pageSize
    }
    if (filters.status !== null) {
      params.status = filters.status
    }
    const res = await getAppVersions(params)
    versions.value = res.items
    pagination.total = res.total
  } catch (error: any) {
    ElMessage.error(error.message || '获取版本列表失败')
  } finally {
    loading.value = false
  }
}

const formatDateTime = (dateStr: string) => {
  return dayjs(dateStr).format('YYYY-MM-DD HH:mm:ss')
}

const getStatusType = (status: number) => {
  switch (status) {
    case 0: return 'info'
    case 1: return 'success'
    case 2: return 'warning'
    default: return 'info'
  }
}

const showCreateDialog = () => {
  Object.assign(createForm, {
    version_name: '',
    version_code: 1,
    platform: 'android',
    release_notes: '',
    release_notes_en: '',
    is_force_update: false,
    min_supported_version: ''
  })
  createDialogVisible.value = true
}

const handleCreate = async () => {
  await createFormRef.value?.validate()
  creating.value = true
  try {
    await createAppVersion(createForm)
    ElMessage.success('版本创建成功')
    createDialogVisible.value = false
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '创建失败')
  } finally {
    creating.value = false
  }
}

const showDetail = (row: AppVersion) => {
  currentVersion.value = row
  detailDialogVisible.value = true
}

const handleUploadApk = (row: AppVersion) => {
  uploadVersionId.value = row.id
  selectedFile.value = null
  uploadRef.value?.clearFiles()
  uploadDialogVisible.value = true
}

const handleFileChange = (file: UploadFile) => {
  selectedFile.value = file.raw || null
}

const handleExceed = () => {
  ElMessage.warning('只能上传一个APK文件')
}

const confirmUpload = async () => {
  if (!selectedFile.value) {
    ElMessage.warning('请选择APK文件')
    return
  }
  uploading.value = true
  try {
    await uploadApk(uploadVersionId.value, selectedFile.value)
    ElMessage.success('APK上传成功')
    uploadDialogVisible.value = false
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '上传失败')
  } finally {
    uploading.value = false
  }
}

// Patch upload
const handleUploadPatch = (row: AppVersion) => {
  currentVersion.value = row
  selectedPatchFile.value = null
  patchUploadRef.value?.clearFiles()
  Object.assign(patchForm, {
    patch_from_version: row.patch_from_version || '',
    patch_from_code: row.patch_from_code || 1
  })
  patchDialogVisible.value = true
}

const handlePatchFileChange = (file: UploadFile) => {
  selectedPatchFile.value = file.raw || null
}

const handlePatchExceed = () => {
  ElMessage.warning('只能上传一个补丁文件')
}

const confirmUploadPatch = async () => {
  await patchFormRef.value?.validate()
  if (!selectedPatchFile.value) {
    ElMessage.warning('请选择补丁文件')
    return
  }
  if (!currentVersion.value) return

  uploadingPatch.value = true
  try {
    await uploadPatch(
      currentVersion.value.id,
      selectedPatchFile.value,
      patchForm.patch_from_version,
      patchForm.patch_from_code
    )
    ElMessage.success('增量包上传成功')
    patchDialogVisible.value = false
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '上传失败')
  } finally {
    uploadingPatch.value = false
  }
}

const handleDeletePatch = async () => {
  if (!currentVersion.value) return

  await ElMessageBox.confirm(
    '确定要删除此版本的增量更新包吗？',
    '确认删除',
    { type: 'warning' }
  )

  deletingPatch.value = true
  try {
    await deletePatch(currentVersion.value.id)
    ElMessage.success('增量包已删除')
    patchDialogVisible.value = false
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '删除失败')
  } finally {
    deletingPatch.value = false
  }
}

// Rollout settings
const showRolloutDialog = (row: AppVersion) => {
  currentVersion.value = row
  rolloutForm.rollout_percentage = row.rollout_percentage
  rolloutForm.rollout_start_date = row.rollout_start_date
  rolloutDialogVisible.value = true
}

const confirmRollout = async () => {
  if (!currentVersion.value) return

  updatingRollout.value = true
  try {
    await updateAppVersion(currentVersion.value.id, {
      rollout_percentage: rolloutForm.rollout_percentage,
      rollout_start_date: rolloutForm.rollout_start_date || undefined
    })
    ElMessage.success('灰度发布设置已更新')
    rolloutDialogVisible.value = false
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '更新失败')
  } finally {
    updatingRollout.value = false
  }
}

const handlePublish = async (row: AppVersion) => {
  await ElMessageBox.confirm(
    `确定要发布版本 ${row.version_name}+${row.version_code} 吗？发布后用户可以更新到此版本。`,
    '确认发布',
    { type: 'warning' }
  )
  try {
    await publishVersion(row.id)
    ElMessage.success('版本已发布')
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '发布失败')
  }
}

const handleDeprecate = async (row: AppVersion) => {
  await ElMessageBox.confirm(
    `确定要废弃版本 ${row.version_name}+${row.version_code} 吗？废弃后用户将无法更新到此版本。`,
    '确认废弃',
    { type: 'warning' }
  )
  try {
    await deprecateVersion(row.id)
    ElMessage.success('版本已废弃')
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '废弃失败')
  }
}

const handleDelete = async (row: AppVersion) => {
  await ElMessageBox.confirm(
    `确定要删除版本 ${row.version_name}+${row.version_code} 吗？此操作不可恢复。`,
    '确认删除',
    { type: 'error' }
  )
  try {
    await deleteAppVersion(row.id)
    ElMessage.success('版本已删除')
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '删除失败')
  }
}

const handleDeleteDeprecated = (row: AppVersion) => {
  deleteVersionId.value = row.id
  deleteVersionInfo.value = `${row.version_name}+${row.version_code}`
  deletePassword.value = ''
  deleteDialogVisible.value = true
}

const confirmDeleteDeprecated = async () => {
  if (!deletePassword.value) {
    ElMessage.warning('请输入管理员密码')
    return
  }

  deleting.value = true
  try {
    await deleteDeprecatedVersion(deleteVersionId.value, deletePassword.value)
    ElMessage.success('废弃版本已删除')
    deleteDialogVisible.value = false
    fetchVersions()
  } catch (error: any) {
    ElMessage.error(error.message || '删除失败')
  } finally {
    deleting.value = false
  }
}

const handleSizeChange = (size: number) => {
  pagination.pageSize = size
  fetchVersions()
}

const handlePageChange = (page: number) => {
  pagination.page = page
  fetchVersions()
}

onMounted(() => {
  fetchVersions()
})
</script>

<style scoped>
.app-versions-page {
  padding: 20px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.page-title {
  font-size: 20px;
  font-weight: 600;
  margin: 0;
}

.filter-form {
  margin-bottom: 20px;
  padding: 16px;
  background: #fff;
  border-radius: 4px;
}

.table-container {
  background: #fff;
  border-radius: 4px;
  padding: 16px;
}

.pagination-container {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
}

.release-notes {
  white-space: pre-wrap;
  word-break: break-word;
  margin: 0;
  font-family: inherit;
}

.upload-apk,
.upload-patch {
  width: 100%;
}

:deep(.el-upload-dragger) {
  width: 100%;
}

.delete-dialog-content {
  padding: 0 10px;
}

.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}

.patch-info {
  display: flex;
  align-items: center;
  gap: 4px;
}

.patch-detail {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.version-label {
  font-weight: 600;
  color: #409eff;
}

.rollout-date {
  margin-left: 8px;
  color: #909399;
  font-size: 12px;
}
</style>
