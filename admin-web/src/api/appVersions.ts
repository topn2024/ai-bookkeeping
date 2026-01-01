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
  release_notes: string
  release_notes_en: string | null
  is_force_update: boolean
  min_supported_version: string | null
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
