import Foundation

struct Account: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var name: String
    var lastFour: String?
    var lastFourDebit: String?
    var currency: String
    var type: String
    var currentBalance: Double
    var cutoffDay: Int?
    var paymentDay: Int?
    var isPrimary: Bool?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case lastFour = "last_four"
        case lastFourDebit = "last_four_debit"
        case currency
        case type
        case currentBalance = "current_balance"
        case cutoffDay = "cutoff_day"
        case paymentDay = "payment_day"
        case isPrimary = "is_primary"
        case createdAt = "created_at"
    }
}

struct AccountAlias: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var accountNumberOrLast4: String
    var contactName: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountNumberOrLast4 = "account_number_or_last4"
        case contactName = "contact_name"
        case createdAt = "created_at"
    }
}
