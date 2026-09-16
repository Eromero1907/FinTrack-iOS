import Foundation

// Modelos de respuesta de Supabase Auth
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String // Llave de repuesto
    let user: SupabaseUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseUser: Codable {
    let id: String
    let email: String
    let userMetadata: UserMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
}

struct UserMetadata: Codable {
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
    }
}
