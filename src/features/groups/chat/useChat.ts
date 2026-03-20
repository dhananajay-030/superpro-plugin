import { create } from 'zustand'
import { supabase } from '@/services/supabase/client'
import { Message } from '@/shared/types'
import { subscribeToGroup } from '@/services/realtime'
import { saveDraft } from '@/services/offline'

interface ChatState {
  messages: Message[]
  loading: boolean
  unsubscribe: (() => void) | null
  fetchMessages: (groupId: string) => Promise<void>
  sendMessage: (groupId: string, content: string, imageFile?: File, replyTo?: string) => Promise<void>
  editMessage: (id: string, content: string) => Promise<void>
  deleteMessage: (id: string) => Promise<void>
  addReaction: (id: string, emoji: string, userId: string) => Promise<void>
  saveDraft: (groupId: string, content: string) => void
  subscribe: (groupId: string) => void
  unsubscribeGroup: () => void
}

export const useChat = create<ChatState>((set, get) => ({
  messages: [],
  loading: false,
  unsubscribe: null,

  fetchMessages: async (groupId) => {
    set({ loading: true })
    const { data } = await supabase.from('messages')
      .select('*').eq('group_id', groupId).order('created_at', { ascending: true })
    set({ messages: data || [], loading: false })
  },

  sendMessage: async (groupId, content, imageFile, replyTo) => {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return
    let image_url: string | undefined
    if (imageFile) {
      const { data } = await supabase.storage.from('chat-images')
        .upload(`${groupId}/${Date.now()}-${imageFile.name}`, imageFile)
      if (data) {
        const { data: urlData } = supabase.storage.from('chat-images').getPublicUrl(data.path)
        image_url = urlData.publicUrl
      }
    }
    await supabase.from('messages').insert({
      group_id: groupId, sender_id: user.id, content, image_url, reply_to: replyTo,
      reactions: {}, edited: false, deleted: false
    })
  },

  editMessage: async (id, content) => {
    await supabase.from('messages').update({ content, edited: true }).eq('id', id)
  },

  deleteMessage: async (id) => {
    await supabase.from('messages').update({ deleted: true, content: '[deleted]' }).eq('id', id)
  },

  addReaction: async (id, emoji, userId) => {
    const msg = get().messages.find(m => m.id === id)
    if (!msg) return
    const reactions = { ...msg.reactions }
    if (!reactions[emoji]) reactions[emoji] = []
    if (reactions[emoji].includes(userId)) {
      reactions[emoji] = reactions[emoji].filter(u => u !== userId)
    } else {
      reactions[emoji].push(userId)
    }
    await supabase.from('messages').update({ reactions }).eq('id', id)
  },

  saveDraft: (groupId, content) => {
    saveDraft({ id: `${groupId}-draft`, groupId, content, timestamp: Date.now() })
  },

  subscribe: (groupId) => {
    const unsub = subscribeToGroup(groupId, (payload) => {
      if (payload.eventType === 'INSERT') {
        set(s => ({ messages: [...s.messages, payload.new as Message] }))
      } else if (payload.eventType === 'UPDATE') {
        set(s => ({ messages: s.messages.map(m => m.id === payload.new.id ? payload.new as Message : m) }))
      }
    })
    set({ unsubscribe: unsub || null })
  },

  unsubscribeGroup: () => {
    get().unsubscribe?.()
    set({ unsubscribe: null })
  }
}))
