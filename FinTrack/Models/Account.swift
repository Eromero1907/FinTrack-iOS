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

// MARK: - Servicio de TRM Oficial y Conversión de Divisas
@MainActor
class CurrencyRateService: ObservableObject {
    static let shared = CurrencyRateService()
    
    @Published var usdToCopRate: Double {
        didSet { UserDefaults.standard.set(usdToCopRate, forKey: "trm_usd_cop") }
    }
    
    @Published var eurToCopRate: Double {
        didSet { UserDefaults.standard.set(eurToCopRate, forKey: "trm_eur_cop") }
    }
    
    @Published var lastUpdated: Date?
    
    private init() {
        let savedUSD = UserDefaults.standard.double(forKey: "trm_usd_cop")
        self.usdToCopRate = savedUSD > 0 ? savedUSD : 4150.0
        
        let savedEUR = UserDefaults.standard.double(forKey: "trm_eur_cop")
        self.eurToCopRate = savedEUR > 0 ? savedEUR : 4500.0
    }
    
    /// Consulta la TRM oficial de Colombia (Superfinanciera / Datos Abiertos)
    func fetchLatestRates() async {
        if let datosGovURL = URL(string: "https://www.datos.gov.co/resource/32sa-8pi3.json?$limit=1&$order=vigenciahasta%20DESC") {
            do {
                var req = URLRequest(url: datosGovURL)
                req.timeoutInterval = 6
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                       let first = jsonArray.first,
                       let valString = first["valor"] as? String,
                       let valDouble = Double(valString), valDouble > 0 {
                        self.usdToCopRate = valDouble
                        self.lastUpdated = Date()
                        print("TRM Oficial de Colombia actualizada: $\(valDouble) COP/USD")
                    }
                }
            } catch {
                print("Error consultando TRM de Superfinanciera: \(error)")
            }
        }
        
        // Respaldo para EUR
        if let openApiURL = URL(string: "https://open.er-api.com/v6/latest/USD") {
            do {
                var req = URLRequest(url: openApiURL)
                req.timeoutInterval = 6
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let rates = json["rates"] as? [String: Any] {
                        if let cop = rates["COP"] as? Double, cop > 0 && self.lastUpdated == nil {
                            self.usdToCopRate = cop
                        }
                        if let eur = rates["EUR"] as? Double, eur > 0 {
                            self.eurToCopRate = self.usdToCopRate / eur
                        }
                        self.lastUpdated = Date()
                    }
                }
            } catch {
                print("Error consultando tasa de respaldo: \(error)")
            }
        }
    }
    
    /// Convierte un monto en moneda extranjera a COP
    func convertToCOP(amount: Double, from currency: String) -> Double {
        let clean = currency.uppercased().trimmingCharacters(in: .whitespaces)
        switch clean {
        case "COP":
            return amount
        case "USD":
            return amount * usdToCopRate
        case "EUR":
            return amount * eurToCopRate
        default:
            return amount
        }
    }
}

