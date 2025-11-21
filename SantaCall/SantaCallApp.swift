
import SwiftUI
import Supabase

@main
struct SantaCallApp: App {
    let supabase = SupabaseClient(
        supabaseURL: Config.supabaseUrl,
        supabaseKey: Config.supabaseKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
    
    @StateObject var authManager = AuthManager()
    @StateObject var childManager = ChildManager()
    @StateObject var profileManager = ProfileManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(childManager)
                .environmentObject(profileManager)
                .onAppear {
                    authManager.configure(supabase: supabase)
                    childManager.configure(supabase: supabase)
                    profileManager.configure(supabase: supabase)
                }
        }
    }
}
