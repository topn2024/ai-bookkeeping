// API Response Types
export interface ApiResponse<T = any> {
  code: number
  message: string
  data: T
}

export interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  page_size: number
}

// Auth Types
export interface LoginForm {
  username: string
  password: string
  mfa_code?: string
}

export interface LoginResponse {
  access_token: string
  refresh_token?: string
  token_type: string
  expires_in?: number
  admin: AdminUser
}

export interface AdminUser {
  id: string
  username: string
  email: string
  display_name: string | null
  phone: string | null
  avatar_url: string | null
  role_id: string
  role_name: string
  is_superadmin: boolean
  is_active: boolean
  mfa_enabled: boolean
  last_login_at: string | null
  created_at: string
  permissions: string[]
}

// Dashboard Types
export interface DashboardStats {
  new_users_today: number
  active_users_today: number
  transactions_today: number
  transaction_amount_today: number
  total_users: number
  total_transactions: number
  trends: {
    new_users_change: number
    active_users_change: number
    transactions_change: number
    amount_change: number
  }
}

export interface TrendData {
  date: string
  value: number
}

export interface HeatmapData {
  matrix: number[][]
  by_hour: { hour: number; count: number }[]
  by_day_of_week: { day: number; count: number }[]
  peak_hour: number
  peak_day: number
}

// User Types
export interface AppUser {
  id: string
  email_masked: string
  display_name: string | null
  avatar_url: string | null
  is_active: boolean
  is_premium: boolean
  transaction_count: number
  total_amount: string
  book_count: number
  account_count: number
  last_login_at: string | null
  created_at: string
  // Extended fields from detail API
  nickname?: string | null
  phone?: string | null
  email?: string | null
  gender?: string | null
  status?: string
}

export interface UserDetail extends AppUser {
  category_count: number
  budget_count: number
  total_income: string
  total_expense: string
  total_balance: string
  last_transaction_at: string | null
}

// User Detail API Response
export interface UserDetailResponse {
  user: AppUser
  stats: {
    transaction_count: number
    total_income: number
    total_expense: number
    book_count: number
  }
  recent_transactions: any[]
  books: any[]
  login_history: any[]
}

export interface UserBehaviorAnalysis {
  user_id: string
  activity_summary: {
    period_days: number
    transaction_count: number
    daily_average: number
    active_days: number
    activity_rate: number
  }
  usage_patterns: {
    type_distribution: Record<string, number>
    peak_hours: number[]
    preferred_categories: string[]
  }
  feature_usage: Record<string, number>
  risk_indicators: string[]
}

// Transaction Types
export interface Transaction {
  id: string
  user_id: string
  user_email: string | null
  book_id: string
  book_name: string | null
  account_id: string
  account_name: string | null
  category_id: string
  category_name: string | null
  transaction_type: number  // Backend: 1=expense, 2=income, 3=transfer
  type: 'expense' | 'income' | 'transfer'  // Frontend display type
  amount: number
  fee: number | null
  transaction_date: string  // Date part: "YYYY-MM-DD"
  transaction_time: string | null  // Time part: "HH:mm:ss"
  note: string | null
  tags: string[] | null
  source: number
  is_reimbursable: boolean
  is_reimbursed: boolean
  created_at: string
}

export interface TransactionStats {
  total_count: number
  total_expense: number
  total_income: number
  total_transfer: number
  avg_expense: number
  avg_income: number
  by_date: { date: string; expense: number; income: number; count: number }[]
  by_category: { category_id: string; category_name: string; amount: number; count: number }[]
  by_source: Record<string, number>
}

// Statistics Types
export interface RetentionData {
  cohort_date: string
  cohort_size: number
  day_1: number | null
  day_7: number | null
  day_14: number | null
  day_30: number | null
}

export interface ChurnRiskUser {
  user_id: string
  email: string | null
  last_active: string
  days_inactive: number
  transaction_count_30d: number
  risk_score: number
  risk_level: string
}

// Monitoring Types
export interface SystemHealth {
  overall_status: string
  services: {
    name: string
    status: string
    latency_ms: number | null
    message: string | null
    last_check: string
  }[]
  checked_at: string
}

export interface SystemResources {
  cpu_percent: number
  memory_percent: number
  memory_used_mb: number
  memory_total_mb: number
  disk: {
    total_bytes: number
    used_bytes: number
    free_bytes: number
    usage_percent: number
    total_formatted: string
    used_formatted: string
    free_formatted: string
  }
  platform: string
  python_version: string
  uptime_seconds: number
}

// Settings Types
export interface SystemSettings {
  system_name: string
  system_logo: string | null
  registration_enabled: boolean
  registration_require_email_verify: boolean
}

export interface EmailSettings {
  enabled: boolean
  smtp_host: string
  smtp_port: number
  smtp_user: string
  smtp_from: string
  use_tls: boolean
}

export interface AISettings {
  enabled: boolean
  provider: string
  model: string
  max_tokens: number
  temperature: number
}

// Audit Log Types
export interface AuditLog {
  id: string
  admin_id: string
  admin_username: string
  action: string
  action_name: string
  module: string
  target_type: string | null
  target_id: string | null
  target_name: string | null
  description: string | null
  ip_address: string | null
  status: number
  created_at: string
}

// Menu Types
export interface MenuItem {
  path: string
  title: string
  icon?: string
  children?: MenuItem[]
  permission?: string
}

// Backup Types
export interface Backup {
  id: number
  user_id: string | null
  type: string
  status: string
  file_path: string | null
  file_size: number | null
  record_count: number | null
  note: string | null
  created_at: string
  expires_at: string | null
}

export interface BackupStats {
  total_count: number
  total_size: number
  today_count: number
  failed_count: number
}

// Element Plus Tag Type Helper
export type TagType = 'success' | 'warning' | 'info' | 'primary' | 'danger' | ''
