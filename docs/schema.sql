-- =============================================
-- SuperPro Plugin - Supabase Database Schema
-- =============================================

-- Profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  total_study_hours FLOAT DEFAULT 0,
  streak_days INT DEFAULT 0,
  is_online BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT NOW()
);

-- Groups
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  goal TEXT,
  max_members INT DEFAULT 10 CHECK (max_members <= 50),
  privacy TEXT DEFAULT 'public' CHECK (privacy IN ('public','private')),
  password TEXT,
  invite_link TEXT UNIQUE,
  penalty_rules JSONB DEFAULT '[]',
  admin_id UUID REFERENCES profiles(id),
  member_count INT DEFAULT 0,
  notice TEXT,
  chat_locked BOOLEAN DEFAULT false,
  attendance_proof_required BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Group Members
CREATE TABLE group_members (
  user_id UUID REFERENCES profiles(id),
  group_id UUID REFERENCES groups(id),
  role TEXT DEFAULT 'member' CHECK (role IN ('member','admin')),
  is_muted BOOLEAN DEFAULT false,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  study_hours_today FLOAT DEFAULT 0,
  PRIMARY KEY (user_id, group_id)
);

-- Messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id),
  sender_id UUID REFERENCES profiles(id),
  content TEXT NOT NULL,
  image_url TEXT,
  reply_to UUID REFERENCES messages(id),
  reactions JSONB DEFAULT '{}',
  edited BOOLEAN DEFAULT false,
  deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Study Sessions
CREATE TABLE study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration_minutes INT DEFAULT 0,
  max_focus_seconds INT DEFAULT 0,
  category TEXT DEFAULT 'general',
  breaks JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Attendance
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  group_id UUID REFERENCES groups(id),
  date DATE NOT NULL,
  proof_photo_url TEXT,
  verified BOOLEAN DEFAULT false,
  UNIQUE (user_id, group_id, date)
);

-- Challenges
CREATE TABLE challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id),
  title TEXT NOT NULL,
  target_days INT NOT NULL,
  target_hours_per_day FLOAT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  participants UUID[] DEFAULT '{}'
);

-- Community Posts
CREATE TABLE community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  photo_url TEXT NOT NULL,
  caption TEXT,
  likes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- DM Requests
CREATE TABLE dm_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID REFERENCES profiles(id),
  to_user_id UUID REFERENCES profiles(id),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Direct Messages
CREATE TABLE direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID REFERENCES profiles(id),
  to_user_id UUID REFERENCES profiles(id),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- RPC Functions
-- =============================================

CREATE OR REPLACE FUNCTION get_leaderboard(period_type TEXT, limit_n INT)
RETURNS TABLE(user_id UUID, username TEXT, avatar_url TEXT, total_minutes BIGINT, rank BIGINT) AS $$
  SELECT p.id, p.username, p.avatar_url,
    SUM(s.duration_minutes) AS total_minutes,
    RANK() OVER (ORDER BY SUM(s.duration_minutes) DESC) AS rank
  FROM study_sessions s JOIN profiles p ON s.user_id = p.id
  WHERE s.start_time >= CASE
    WHEN period_type = 'daily' THEN NOW() - INTERVAL '1 day'
    WHEN period_type = 'weekly' THEN NOW() - INTERVAL '7 days'
    ELSE NOW() - INTERVAL '30 days' END
  GROUP BY p.id, p.username, p.avatar_url
  ORDER BY total_minutes DESC LIMIT limit_n;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_group_leaderboard(gid UUID, period_type TEXT)
RETURNS TABLE(user_id UUID, username TEXT, avatar_url TEXT, total_minutes BIGINT, rank BIGINT) AS $$
  SELECT p.id, p.username, p.avatar_url,
    SUM(s.duration_minutes) AS total_minutes,
    RANK() OVER (ORDER BY SUM(s.duration_minutes) DESC) AS rank
  FROM study_sessions s
  JOIN profiles p ON s.user_id = p.id
  JOIN group_members gm ON gm.user_id = s.user_id AND gm.group_id = gid
  WHERE s.start_time >= CASE
    WHEN period_type = 'daily' THEN NOW() - INTERVAL '1 day'
    WHEN period_type = 'weekly' THEN NOW() - INTERVAL '7 days'
    ELSE NOW() - INTERVAL '30 days' END
  GROUP BY p.id, p.username, p.avatar_url ORDER BY total_minutes DESC;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_community_avg_daily_minutes()
RETURNS FLOAT AS $$
  SELECT AVG(daily_total) FROM (
    SELECT DATE(start_time), SUM(duration_minutes) AS daily_total
    FROM study_sessions WHERE start_time >= NOW() - INTERVAL '30 days'
    GROUP BY user_id, DATE(start_time)
  ) t;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_user_global_rank(uid UUID)
RETURNS INT AS $$
  SELECT rank FROM (
    SELECT user_id, RANK() OVER (ORDER BY SUM(duration_minutes) DESC) AS rank
    FROM study_sessions WHERE start_time >= NOW() - INTERVAL '30 days'
    GROUP BY user_id
  ) t WHERE user_id = uid;
$$ LANGUAGE SQL;

-- =============================================
-- Enable Realtime on key tables
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE group_members;
ALTER PUBLICATION supabase_realtime ADD TABLE groups;

-- =============================================
-- Row Level Security (RLS)
-- =============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Groups readable by members" ON groups FOR SELECT USING (
  EXISTS (SELECT 1 FROM group_members WHERE group_id = id AND user_id = auth.uid())
  OR privacy = 'public'
);
CREATE POLICY "Messages readable by members" ON messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM group_members WHERE group_id = messages.group_id AND user_id = auth.uid())
);
CREATE POLICY "Sessions are private" ON study_sessions FOR ALL USING (auth.uid() = user_id);
