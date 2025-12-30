/**
 * Common formatting utility functions
 */

/**
 * Format date/time string to localized format
 * @param date - Date string or Date object
 * @param options - Intl.DateTimeFormatOptions
 * @returns Formatted date string
 */
export const formatDateTime = (
  date: string | Date | null | undefined,
  options?: Intl.DateTimeFormatOptions
): string => {
  if (!date) return '-'
  const d = typeof date === 'string' ? new Date(date) : date
  if (isNaN(d.getTime())) return '-'

  return d.toLocaleString('zh-CN', options ?? {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/**
 * Format date string (without time)
 * @param date - Date string or Date object
 * @returns Formatted date string
 */
export const formatDate = (
  date: string | Date | null | undefined
): string => {
  if (!date) return '-'
  const d = typeof date === 'string' ? new Date(date) : date
  if (isNaN(d.getTime())) return '-'

  return d.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
}

/**
 * Format short date (month/day hour:minute)
 * @param date - Date string or Date object
 * @returns Formatted short date string
 */
export const formatShortDate = (
  date: string | Date | null | undefined
): string => {
  if (!date) return '-'
  const d = typeof date === 'string' ? new Date(date) : date
  if (isNaN(d.getTime())) return '-'

  return d.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/**
 * Format money amount
 * @param amount - Amount number
 * @param decimals - Number of decimal places (default: 2)
 * @param currency - Currency symbol (default: '')
 * @returns Formatted money string
 */
export const formatMoney = (
  amount: number | string | null | undefined,
  decimals: number = 2,
  currency: string = ''
): string => {
  if (amount === null || amount === undefined) return '-'
  const num = typeof amount === 'string' ? parseFloat(amount) : amount
  if (isNaN(num)) return '-'

  const formatted = num.toLocaleString('zh-CN', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })

  return currency ? `${currency}${formatted}` : formatted
}

/**
 * Format number with abbreviation (e.g., 10000 -> 1w)
 * @param num - Number to format
 * @returns Formatted number string
 */
export const formatNumber = (num: number | null | undefined): string => {
  if (num === null || num === undefined) return '0'
  if (num >= 100000000) {
    return (num / 100000000).toFixed(1) + '亿'
  }
  if (num >= 10000) {
    return (num / 10000).toFixed(1) + 'w'
  }
  return num.toLocaleString()
}

/**
 * Format file size
 * @param bytes - Size in bytes
 * @returns Formatted size string
 */
export const formatFileSize = (bytes: number | null | undefined): string => {
  if (!bytes || bytes === 0) return '0 B'

  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(1024))
  const size = bytes / Math.pow(1024, i)

  return `${size.toFixed(i > 0 ? 2 : 0)} ${units[i]}`
}

/**
 * Format percentage
 * @param value - Percentage value (0-100 or 0-1)
 * @param isDecimal - Whether value is in decimal format (0-1)
 * @returns Formatted percentage string
 */
export const formatPercent = (
  value: number | null | undefined,
  isDecimal: boolean = false
): string => {
  if (value === null || value === undefined) return '-'
  const pct = isDecimal ? value * 100 : value
  return `${pct.toFixed(1)}%`
}

/**
 * Format duration in seconds to readable format
 * @param seconds - Duration in seconds
 * @returns Formatted duration string
 */
export const formatDuration = (seconds: number | null | undefined): string => {
  if (!seconds || seconds < 0) return '-'

  if (seconds < 60) {
    return `${seconds.toFixed(0)}秒`
  }
  if (seconds < 3600) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return secs > 0 ? `${mins}分${secs}秒` : `${mins}分`
  }
  if (seconds < 86400) {
    const hours = Math.floor(seconds / 3600)
    const mins = Math.floor((seconds % 3600) / 60)
    return mins > 0 ? `${hours}小时${mins}分` : `${hours}小时`
  }

  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  return hours > 0 ? `${days}天${hours}小时` : `${days}天`
}
