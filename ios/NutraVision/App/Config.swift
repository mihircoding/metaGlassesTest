import Foundation

/// Replace both values with your own: Supabase dashboard > Project Settings > API
/// ("Project URL" and the "anon public" key). The anon key is safe to ship in the app.
enum Config {
    static let supabaseURL = URL(string: "https://YOUR-PROJECT.supabase.co")!
    static let supabaseAnonKey = "YOUR-ANON-KEY"
}
