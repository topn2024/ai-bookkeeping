import { get, post, put, del, upload } from './request'

// Types
export interface AppVersion {
  id: string
  version_name: string
  version_code: number
  platform: string
  file_url: string | null
  file_size: number | null
  file_size_formatted: string
  file_md5: string | null
  // Patch file info
  patch_from_version: string | null
  patch_from_code: number | null
  patch_file_url: string | null
  patch_file_size: number | null
  patch_file_size_formatted: string
  patch_file_md5: string | null
  // Release info
  release_notes: string
  release_notes_en: string | null
  is_force_update: boolean
  min_supported_version: string | null
  // Rollout settings
  rollout_percentage: number
  rollout_start_date: string | null
  // Status
  status: number
  status_text: string
  published_at: string | null
  created_at: string
  updated_at: string
  created_by: string | null
}

export interface AppVersionListResponse {
  items: AppVersion[]
  total: number
}

export interface AppVersionCreate {
  version_name: string
  version_code: number
  platform?: string
  release_notes: string
  release_notes_en?: string
  is_force_update?: boolean
  min_supported_version?: string
}

export interface AppVersionUpdate {
  release_notes?: string
  release_notes_en?: string
  is_force_update?: boolean
  min_supported_version?: string
  rollout_percentage?: number
  rollout_start_date?: string
}

// API functions

/**
 * List app versions
 */
export const getAppVersions = (params: {
  platform?: string
  status?: number
  skip?: number
  limit?: number
}): Promise<AppVersionListResponse> => {
  return get('/app-versions', { params })
}

/**
 * Get latest published version
 */
export const getLatestVersion = (platform: string = 'android'): Promise<AppVersion | null> => {
  return get('/app-versions/latest', { params: { platform } })
}

/**
 * Get version by ID
 */
export const getAppVersion = (versionId: string): Promise<AppVersion> => {
  return get(`/app-versions/${versionId}`)
}

/**
 * Create new version
 */
export const createAppVersion = (data: AppVersionCreate): Promise<AppVersion> => {
  return post('/app-versions', data)
}

/**
 * Update version info
 */
export const updateAppVersion = (versionId: string, data: AppVersionUpdate): Promise<AppVersion> => {
  return put(`/app-versions/${versionId}`, data)
}

/**
 * Upload APK file
 */
export const uploadApk = (versionId: string, file: File): Promise<{
  message: string
  url: string
  size: number
  size_formatted: string
  md5: string
}> => {
  const formData = new FormData()
  formData.append('file', file)
  return upload(`/app-versions/${versionId}/upload-apk`, formData)
}

/**
 * Publish version
 */
export const publishVersion = (versionId: string): Promise<{
  message: string
  version: string
  published_at: string
}> => {
  return post(`/app-versions/${versionId}/publish`)
}

/**
 * Deprecate version
 */
export const deprecateVersion = (versionId: string): Promise<{
  message: string
  version: string
}> => {
  return post(`/app-versions/${versionId}/deprecate`)
}

/**
 * Delete version (draft only)
 */
export const deleteAppVersion = (versionId: string): Promise<{
  message: string
  version: string
}> => {
  return del(`/app-versions/${versionId}`)
}

/**
 * Delete deprecated version with password verification
 */
export const deleteDeprecatedVersion = (versionId: string, password: string): Promise<{
  message: string
  version: string
}> => {
  return post(`/app-versions/${versionId}/delete`, { password })
}

/**
 * Upload patch file for incremental update
 */
export const uploadPatch = (versionId: string, file: File, patchFromVersion: string, patchFromCode: number): Promise<{
  message: string
  url: string
  size: number
  size_formatted: string
  md5: string
  patch_from_version: string
  patch_from_code: number
}> => {
  const formData = new FormData()
  formData.append('file', file)
  formData.append('patch_from_version', patchFromVersion)
  formData.append('patch_from_code', patchFromCode.toString())
  return upload(`/app-versions/${versionId}/upload-patch`, formData)
}

/**
 * Delete patch file
 */
export const deletePatch = (versionId: string): Promise<{
  message: string
  version: string
}> => {
  return del(`/app-versions/${versionId}/patch`)
}
