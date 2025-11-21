import Foundation
import Combine
import SwiftUI
import Supabase

struct Profile: Codable {
    let id: UUID
    let email: String
    let first_name: String?
    let last_name: String?
    
    var isComplete: Bool {
        return first_name != nil && !first_name!.isEmpty
    }
}

class ProfileManager: ObservableObject {
    @Published var profile: Profile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var supabase: SupabaseClient?
    
    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchProfile() async {
        guard let supabase = supabase else { return }
        guard let userId = supabase.auth.currentUser?.id else { return }
        
        DispatchQueue.main.async { self.isLoading = true }
        
        do {
            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.profile = profiles.first
                self.isLoading = false
            }
        } catch {
            print("Error fetching profile: \(error)")
            DispatchQueue.main.async { 
                self.isLoading = false
            }
        }
    }
    
    func updateProfile(firstName: String, lastName: String) async {
        guard let supabase = supabase else { return }
        guard let currentUser = supabase.auth.currentUser else { return }
        let userId = currentUser.id
        let email = currentUser.email ?? ""
        
        DispatchQueue.main.async { 
            self.isLoading = true 
            self.errorMessage = nil
        }
        
        struct UpsertProfile: Encodable {
            let id: UUID
            let email: String
            let first_name: String
            let last_name: String
        }
        
        do {
            let profileData = UpsertProfile(
                id: userId,
                email: email,
                first_name: firstName,
                last_name: lastName
            )
            
            let _: Profile = try await supabase
                .from("profiles")
                .upsert(profileData)
                .select()
                .single()
                .execute()
                .value
            
            await fetchProfile()
            
            DispatchQueue.main.async { self.isLoading = false }
        } catch {
            print("Error updating profile: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
            }
        }
    }
}
