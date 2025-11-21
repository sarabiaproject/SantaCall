import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to SantaCall!")
                .font(.largeTitle)
                .bold()
            
            Text("Please tell us your name to get started.")
                .foregroundColor(.secondary)
            
            TextField("First Name", text: $firstName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.givenName)
            
            TextField("Last Name", text: $lastName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.familyName)
            
            if let error = profileManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                Task {
                    await profileManager.updateProfile(firstName: firstName, lastName: lastName)
                }
            }) {
                if profileManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Continue")
                        .bold()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(firstName.isEmpty || profileManager.isLoading)
            
            Spacer()
        }
        .padding()
    }
}
