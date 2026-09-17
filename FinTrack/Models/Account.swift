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

// MARK: - Extensiones Globales de Formato y Teclado
import SwiftUI

extension Double {
    /// Formato limpio de moneda sin decimales para Colombia (COP) u otras divisas
    func formattedCurrency(code: String = "COP") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale(identifier: "es_CO")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

