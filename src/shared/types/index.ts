export interface User {
  id: string
  username: string
  avatar_url?: string
  total_study_hours: number
  streak_days: number
  is_online: boolean
  last_seen: string
}

export interface Group {
  id: string
  name: string
  goal: string
  max_members: number      // hard cap: 50
  privacy: 'public' | 'private'
  password?: string
  invite_link?: string
  penalty_rules: PenaltyRule[]
  admin_id: string
  member_count: number
  created_at: string
  notice?: string
  chat_locked: boolean
  attendance_proof_required: boolean
}

export interface GroupMember {
  user_id: string
  group_id: string
  role: 'member' | 'admin'
  is_muted: boolean
  joined_at: string
  study_hours_today: number
}

export interface Message {
  id: string
  group_id: string
  sender_id: string
  content: string
  image_url?: string
  reply_to?: string
  reactions: Record<string, string[]>
  edited: boolean
  deleted: boolean
  created_at: string
}

export interface AttendanceRecord {
  id: string
  user_id: string
  group_id: string
  date: string
  proof_photo_url?: string
  verified: boolean
}

export interface Challenge {
  id: string
  group_id: string
  title: string
  target_days: number
  target_hours_per_day: number
  start_date: string
  end_date: string
  participants: string[]
}

export interface PenaltyRule {
  id: string
  condition: string
  penalty: string
  auto: boolean
}

export interface StudySession {
  id: string
  user_id: string
  start_time: string
  end_time?: string
  duration_minutes: number
  category: string
  breaks: Break[]
}

export interface Break {
  start: string
  end: string
  duration_minutes: number
}

export interface LeaderboardEntry {
  user_id: string
  username: string
  avatar_url?: string
  total_minutes: number
  rank: number
  period: 'daily' | 'weekly' | 'monthly'
}

export interface DMRequest {
  id: string
  from_user_id: string
  to_user_id: string
  status: 'pending' | 'accepted' | 'rejected'
  created_at: string
}
