import { create } from 'zustand'
import { supabase } from '@/services/supabase/client'
import { Group, GroupMember } from '@/shared/types'

interface GroupsState {
  groups: Group[]
  currentGroup: Group | null
  members: GroupMember[]
  loading: boolean
  fetchMyGroups: () => Promise<void>
  fetchGroupDetail: (id: string) => Promise<void>
  createGroup: (data: Partial<Group>) => Promise<Group | null>
  joinGroup: (groupId: string, password?: string) => Promise<boolean>
  leaveGroup: (groupId: string) => Promise<void>
  kickMember: (groupId: string, userId: string) => Promise<void>
  promoteAdmin: (groupId: string, userId: string) => Promise<void>
  muteMember: (groupId: string, userId: string, mute: boolean) => Promise<void>
  lockChat: (groupId: string, locked: boolean) => Promise<void>
  updateNotice: (groupId: string, notice: string) => Promise<void>
  deleteMedia: (messageId: string) => Promise<void>
}

export const useGroups = create<GroupsState>((set) => ({
  groups: [],
  currentGroup: null,
  members: [],
  loading: false,

  fetchMyGroups: async () => {
    set({ loading: true })
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    const { data } = await supabase
      .from('group_members')
      .select('group:groups(*)')
      .eq('user_id', user.id)
    set({ groups: (data?.map((d: any) => d.group) || []), loading: false })
  },

  fetchGroupDetail: async (id: string) => {
    const [{ data: group }, { data: members }] = await Promise.all([
      supabase.from('groups').select('*').eq('id', id).single(),
      supabase.from('group_members').select('*').eq('group_id', id)
    ])
    set({ currentGroup: group, members: members || [] })
  },

  createGroup: async (data) => {
    if ((data.max_members || 50) > 50) data.max_members = 50 // hard cap
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return null
    const { data: group } = await supabase.from('groups').insert({
      ...data, admin_id: user.id, chat_locked: false, member_count: 1
    }).select().single()
    if (group) {
      await supabase.from('group_members').insert({ user_id: user.id, group_id: group.id, role: 'admin' })
    }
    return group
  },

  joinGroup: async (groupId, password) => {
    const { data: group } = await supabase.from('groups').select('*').eq('id', groupId).single()
    if (!group) return false
    if (group.privacy === 'private' && group.password && group.password !== password) return false
    if (group.member_count >= group.max_members) return false
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return false
    await supabase.from('group_members').insert({ user_id: user.id, group_id: groupId, role: 'member' })
    await supabase.from('groups').update({ member_count: group.member_count + 1 }).eq('id', groupId)
    return true
  },

  leaveGroup: async (groupId) => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    await supabase.from('group_members').delete().eq('user_id', user.id).eq('group_id', groupId)
  },

  kickMember: async (groupId, userId) => {
    await supabase.from('group_members').delete().eq('user_id', userId).eq('group_id', groupId)
  },

  promoteAdmin: async (groupId, userId) => {
    await supabase.from('group_members').update({ role: 'admin' }).eq('user_id', userId).eq('group_id', groupId)
  },

  muteMember: async (groupId, userId, mute) => {
    await supabase.from('group_members').update({ is_muted: mute }).eq('user_id', userId).eq('group_id', groupId)
  },

  lockChat: async (groupId, locked) => {
    await supabase.from('groups').update({ chat_locked: locked }).eq('id', groupId)
  },

  updateNotice: async (groupId, notice) => {
    await supabase.from('groups').update({ notice }).eq('id', groupId)
  },

  deleteMedia: async (messageId) => {
    await supabase.from('messages').update({ image_url: null, deleted: false }).eq('id', messageId)
  }
}))
