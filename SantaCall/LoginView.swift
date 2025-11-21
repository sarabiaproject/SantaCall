import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            Image(systemName: "gift.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .padding()
            
            Text("SantaCall")
                .font(.largeTitle)
                .bold()
            
            Text("Talk to Santa anytime!")
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
            
            // Email/Password Form
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        Task {
                            do {
                                errorMessage = nil
                                try await authManager.signIn(email: email, password: password)
                            } catch {
                                print("LoginView Sign In Error: \(error)")
                                errorMessage = "Sign In Failed: \(error.localizedDescription)"
                            }
                        }
                    }) {
                        Text("Sign In")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        Task {
                            do {
                                errorMessage = nil
                                try await authManager.signUp(email: email, password: password)
                            } catch {
                                print("LoginView Sign Up Error: \(error)")
                                errorMessage = "Sign Up Failed: \(error.localizedDescription)"
                            }
                        }
                    }) {
                        Text("Sign Up")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            Divider()
                .padding(.bottom, 20)
            
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
                request.nonce = "MOCKED_NONCE" // In prod, generate random nonce
            } onCompletion: { result in
                switch result {
                case .success(let authResults):
                    switch authResults.credential {
                    case let appleIDCredential as ASAuthorizationAppleIDCredential:
                        guard let idTokenData = appleIDCredential.identityToken,
                              let idTokenString = String(data: idTokenData, encoding: .utf8) else {
                            return
                        }
                        
                        Task {
                            try? await authManager.signInWithApple(
                                idToken: idTokenString,
                                nonce: "MOCKED_NONCE"
                            )
                        }
                    default:
                        break
                    }
                case .failure(let error):
                    print("Sign in failed: \(error.localizedDescription)")
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal)
            
            // Google Sign In Button Placeholder
            // In a real app, use GoogleSignIn-Swift package
            Button(action: {
                // Trigger Google Sign In Flow
                // This usually involves GIDSignIn.sharedInstance.signIn
                print("Google Sign In Tapped")
            }) {
                HStack {
                    Image(systemName: "globe") // Placeholder icon
                    Text("Sign in with Google")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
