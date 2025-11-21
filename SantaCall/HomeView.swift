import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var childManager: ChildManager
    
    @State private var showAddChildSheet = false
    @State private var newChildName = ""
    @State private var newChildAge = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                if let child = childManager.selectedChild {
                    Text("Selected: \(child.first_name)")
                        .font(.headline)
                } else {
                    Text("Select a child")
                        .font(.headline)
                }
                Spacer()
                Button("Sign Out") {
                    Task { await authManager.signOut() }
                }
            }
            .padding()
            
            // Child Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(childManager.children) { child in
                        Button(action: {
                            childManager.selectedChild = child
                        }) {
                            Text(child.first_name)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(childManager.selectedChild?.id == child.id ? Color.red : Color.gray.opacity(0.2))
                                .foregroundColor(childManager.selectedChild?.id == child.id ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                    
                    Button(action: { showAddChildSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Main Content Area
            VStack {
                Image("santa_placeholder") // Ensure you have an asset or use system image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                            .offset(x: 60, y: -60)
                            .opacity(childManager.selectedChild != nil ? 1 : 0)
                    )
                
                if let child = childManager.selectedChild {
                    Text("Hello, \(child.first_name)!")
                        .font(.title)
                        .bold()
                    
                    Text("Ready for Christmas?")
                        .font(.title2)
                        .padding(.top, 5)
                } else {
                    Text("Welcome!")
                        .font(.title)
                        .bold()
                    
                    Text("Select a child to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .sheet(isPresented: $showAddChildSheet) {
            VStack(spacing: 20) {
                Text("Add Child")
                    .font(.title2)
                    .bold()
                
                TextField("Name", text: $newChildName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                TextField("Age", text: $newChildAge)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("Save") {
                    if let age = Int(newChildAge), !newChildName.isEmpty {
                        Task {
                            await childManager.createChild(name: newChildName, age: age)
                            if childManager.errorMessage == nil {
                                showAddChildSheet = false
                                newChildName = ""
                                newChildAge = ""
                            }
                        }
                    }
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                if let error = childManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .padding()
            .presentationDetents([.medium])
        }
        .onAppear {
            Task {
                await childManager.fetchChildren()
            }
        }
    }
}
