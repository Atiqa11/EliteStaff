import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

export const isSupabaseConfigured = Boolean(url && anonKey)
export const supabase = isSupabaseConfigured ? createClient(url!, anonKey!) : null

export type ClientStatus = 'Active' | 'Pending' | 'Archived'
export interface ClientRecord {
  id: string
  client_number: string
  full_name: string
  email: string | null
  phone: string | null
  company: string | null
  purpose: string | null
  industry: string | null
  practice_area: string | null
  client_type: string | null
  assigned_lawyer: string | null
  related_matter: string | null
  address: string | null
  budget: number
  payment_terms: string | null
  total_invoice: number
  paid_amount: number
  pending_amount: number
  status: ClientStatus
  favorite: boolean
  notes: string | null
  created_at: string
  updated_at: string
}

export const nullable = (value: string) => value.trim() || null
export const currency = (value: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(value || 0)
