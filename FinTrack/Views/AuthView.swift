import SwiftUI

struct AuthView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    
    @StateObject private var viewModel = AuthViewModel()
    @State private var isLoginMode = true
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Modo", selection: $isLoginMode) {
                        Text("Iniciar Sesión").tag(true)
                        Text("Crear Cuenta").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    Text("FinTrack")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(.bottom, 20)
                    
                    VStack(spacing: 15) {
                        if !isLoginMode {
                            HStack {
                                TextField("Nombre", text: $firstName)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                
                                TextField("Apellido", text: $lastName)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                            }
                        }
                        
                        TextField("Correo Electrónico", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        
                        SecureField("Contraseña", text: $password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        
                        if !isLoginMode {
                            SecureField("Repetir Contraseña", text: $confirmPassword)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                RequirementText(text: "Mínimo 8 caracteres", isValid: password.count >= 8)
                                RequirementText(text: "Debe contener un número", isValid: password.rangeOfCharacter(from: .decimalDigits) != nil)
                                RequirementText(text: "Las contraseñas coinciden", isValid: !password.isEmpty && password == confirmPassword)
                            }
                            .padding(.top, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 5)
                    }
                    
                    Button(action: {
                        Task {
                            if isLoginMode {
                                await viewModel.signIn(email: email, password: password) {
                                    isAuthenticated = true
                                }
                            } else {
                                await viewModel.signUp(email: email, password: password, firstName: firstName, lastName: lastName) {
                                    isAuthenticated = true
                                }
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                            }
                            Text(isLoginMode ? "Entrar a mi cuenta" : "Registrarme")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid && !viewModel.isLoading ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .font(.headline)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && password.count >= 8 &&
                   password.rangeOfCharacter(from: .decimalDigits) != nil &&
                   password == confirmPassword &&
                   !firstName.isEmpty
        }
    }
}

struct RequirementText: View {
    var text: String
    var isValid: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .green : .gray)
        }
    }
}
