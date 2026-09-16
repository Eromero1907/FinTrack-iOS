import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Iniciar Sesión
    func signIn(email: String, password: String, onSuccess: @escaping () -> Void) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseManager.shared.signIn(email: email, password: password)
            onSuccess() // Le avisamos a la vista que todo salió bien
        } catch {
            errorMessage = "Correo o contraseña incorrectos."
        }
        
        isLoading = false
    }
    
    // Crear Cuenta (Sin apodo)
    func signUp(email: String, password: String, firstName: String, lastName: String, onSuccess: @escaping () -> Void) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseManager.shared.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
            onSuccess() // Le avisamos a la vista que todo salió bien
        } catch {
            errorMessage = "El correo ya está en uso o ocurrió un error."
        }
        
        isLoading = false
    }
}
