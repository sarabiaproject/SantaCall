import Foundation
import Combine
import SwiftUI
import Supabase

struct Child: Identifiable, Codable, Hashable {
    let id: UUID
    let first_name: String
    let age: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case first_name
        case age
    }
}

class ChildManager: ObservableObject {
    @Published var children: [Child] = []
    @Published var selectedChild: Child?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var supabase: SupabaseClient?
    
    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchChildren() async {
        guard let supabase = supabase else { return }
        
        DispatchQueue.main.async { 
            self.isLoading = true 
            self.errorMessage = nil
        }
        
        do {
            let children: [Child] = try await supabase
                .from("children")
                .select()
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.children = children
                if self.selectedChild == nil, !children.isEmpty {
                    self.selectedChild = children.first
                }
                self.isLoading = false
            }
        } catch {
            print("Error fetching children: \(error)")
            DispatchQueue.main.async { 
                self.isLoading = false
                self.errorMessage = "Failed to fetch children: \(error.localizedDescription)"
            }
        }
    }
    
    func createChild(name: String, age: Int) async {
        guard let supabase = supabase else {
            print("ChildManager: Supabase client is nil")
            return
        }
        guard let userId = supabase.auth.currentUser?.id else {
            print("ChildManager: User not authenticated")
            DispatchQueue.main.async {
                self.errorMessage = "User not authenticated"
            }
            return
        }
        
        print("ChildManager: Creating child for user \(userId) with name \(name)")
        
        struct NewChild: Encodable {
            let user_id: UUID
            let first_name: String
            let age: Int
        }
        
        DispatchQueue.main.async { self.errorMessage = nil }
        
        do {
            let newChild = NewChild(user_id: userId, first_name: name, age: age)
            let createdChild: Child = try await supabase
                .from("children")
                .insert(newChild)
                .select()
                .single()
                .execute()
                .value
            
            print("ChildManager: Child created successfully: \(createdChild.id)")
            await fetchChildren()
        } catch {
            print("Error creating child: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create child: \(error.localizedDescription)"
            }
        }
    }
}
