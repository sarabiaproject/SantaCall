import Foundation
import SwiftUI
import Combine
import Supabase
import AuthenticationServices

class AuthManager: ObservableObject {
    @Published var session: Session?
    @Published var isAuthenticated = false
    
    var supabase: SupabaseClient?
    
    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
        // Check for existing session
        Task {
            do {
                self.session = try await supabase.auth.session
                self.isAuthenticated = true
            } catch {
                self.isAuthenticated = false
            }
        }
        
        // Listen for auth changes
        Task {
            for await state in supabase.auth.authStateChanges {
                if state.event == .signedIn {
                    self.session = state.session
                    self.isAuthenticated = true
                } else if state.event == .signedOut {
                    self.session = nil
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        guard let supabase = supabase else { return }
        print("Attempting to sign in with email: \(email)")
        do {
            let _ = try await supabase.auth.signIn(email: email, password: password)
            print("Sign in successful")
        } catch {
            print("Sign in error: \(error)")
            throw error
        }
    }

    func signUp(email: String, password: String) async throws {
        guard let supabase = supabase else { return }
        print("Attempting to sign up with email: \(email)")
        do {
            let response = try await supabase.auth.signUp(email: email, password: password)
            print("Sign up successful. User ID: \(response.user.id)")
            if response.session == nil {
                print("WARNING: Session is nil. Email confirmation might be required.")
            }
        } catch {
            print("Sign up error: \(error)")
            throw error
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let supabase = supabase else { return }
        
        let _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        // Session update handled by listener
    }
    
    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        guard let supabase = supabase else { return }
        
        let _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
    }
    
    func signOut() async {
        try? await supabase?.auth.signOut()
    }
}
