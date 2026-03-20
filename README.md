# superpro-plugin

A feature-rich Super Productivity plugin with real-time study groups, insights, community, and planner.

## Features
- ⏱ **Timer** — Focus tracking, auto-break detection, max focus stat, rest timer
- 👥 **Study Groups** — Create/join groups (max 50), group chat with reactions/replies/edit/delete, image sharing
- 🔐 **Group Privacy** — Public or private with password + invite link
- 👑 **Admin Controls** — Promote admins, mute, kick, delete media, lock chat, notices, penalty rules
- 📅 **Attendance** — Daily check-in with optional proof photo, admin can enable/disable
- 🏆 **Leaderboard** — Daily/weekly/monthly rankings (group + global)
- 🎯 **Challenges** — Custom challenges by days and target study hours
- 📊 **Insights** — Heatmap, passion indicator, category stats, weekly/monthly reports, mini-calendar
- 🌍 **Community** — Global ranking, study photo feed
- 💬 **DMs** — Request → accept → chat flow
- 📴 **Offline** — Chat drafts + media upload queue via IndexedDB
- 🌐 **i18n** — Language download option

## Setup

```bash
npm install
cp .env.example .env   # fill in your Supabase keys
npm run dev
```

## Database
Run `docs/schema.sql` in your Supabase SQL editor.

## Structure
```
src/
  core/           Plugin registration
  features/
    auth/         Auth + user profile
    timer/        Study timer with break tracking
    groups/       Groups + chat + attendance + challenges + leaderboard + dashboard
    insights/     Heatmap, stats, passion indicator
    community/    Feed + global ranking
    profile/      DM request/accept system
    settings/     Language, notifications, preferences
  services/
    supabase/     Client + queries
    realtime/     Presence + live subscriptions
    offline/      IndexedDB drafts + media queue
  shared/         Types, hooks, utils, components
```

## Author
[dhananajay-030](https://github.com/dhananajay-030)
