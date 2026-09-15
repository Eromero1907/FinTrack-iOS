import Foundation

struct Transaction: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var sourceAccountId: UUID?
    var destAccountId: UUID?
    var categoryId: UUID?
    var amount: Double
    var type: String // income, expense, transfer
    var description: String?
    var date: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceAccountId = "source_account_id"
        case destAccountId = "dest_account_id"
        case categoryId = "category_id"
        case amount
        case type
        case description
        case date
    }
}
