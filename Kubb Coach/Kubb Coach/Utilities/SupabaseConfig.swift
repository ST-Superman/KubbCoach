// SupabaseConfig.swift
// Single shared SupabaseClient instance for the app.
// The publishable/anon key is intentionally client-visible — security is
// enforced by Row Level Security policies on the database, not by key secrecy.

import Supabase
import Foundation

enum SupabaseConfig {
    static let projectURL = URL(string: "https://rvirzarsjivkaeedodir.supabase.co")!
    static let anonKey    = "sb_publishable_r55zCy_mx_87nlpS-p6nDQ_s9iI0uQg"

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey
    )
}
