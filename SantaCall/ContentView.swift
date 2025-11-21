import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if let profile = profileManager.profile, profile.isComplete {
                    HomeView()
                } else {
                    ProfileSetupView()
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            if authManager.isAuthenticated {
                Task {
                    await profileManager.fetchProfile()
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    await profileManager.fetchProfile()
                }
            } else {
                profileManager.profile = nil
            }
        }
    }
}
