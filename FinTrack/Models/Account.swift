import Foundation

struct Account: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var name: String
    var lastFour: String?
    var currency: String
    var type: String
    var currentBalance: Double
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case lastFour = "last_four"
        case currency
        case type
        case currentBalance = "current_balance"
        case createdAt = "created_at"
    }
}
