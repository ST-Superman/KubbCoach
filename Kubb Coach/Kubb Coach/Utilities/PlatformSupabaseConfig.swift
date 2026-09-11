// PlatformSupabaseConfig.swift
// Second SupabaseClient — the KUBB PLATFORM project (real accounts: email/Apple/Google),
// distinct from the leaderboard project in SupabaseConfig.swift. The leaderboard client
// stays anonymous and untouched; this one carries a real, persisted login used to unlock
// and play virtual matches.
//
// The publishable/anon key is intentionally client-visible — Row Level Security enforces
// access, not key secrecy (same rationale as SupabaseConfig).

import Supabase
import Foundation

enum PlatformSupabaseConfig {
    static let projectURL = URL(string: "https://wynockzaeikgkntosqek.supabase.co")!
    static let anonKey    = "sb_publishable_H-TkOUycEJl1zocAaMhVSA_gE6dO69l"

    /// Its own client so the platform session (Keychain-persisted by the SDK) never
    /// mingles with the leaderboard's anonymous session.
    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey
    )

    /// The web sign-in hand-off page the app opens in ASWebAuthenticationSession.
    /// It routes through the platform's own login (email / Apple / Google) and hands
    /// the resulting session back over the callback scheme's URL fragment.
    /// See kubb-platform `src/app/connect/app/page.tsx`.
    static let connectURL = URL(string: "https://kubbportal.com/connect/app")!
    static let callbackScheme = "kubbcoach"
}
