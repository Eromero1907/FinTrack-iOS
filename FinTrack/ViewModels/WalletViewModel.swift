import Foundation
import SwiftUI

@MainActor
class WalletViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    
    func fetchAccounts() async {
        isLoading = true
        do {
            self.accounts = try await SupabaseManager.shared.fetchAccounts()
        } catch {
            print("Error cargando cuentas: \(error)")
        }
        isLoading = false
    }
    
    func addAccount(name: String, type: String, currency: String, balance: Double, isDebt: Bool) async {
        isLoading = true
        do {
            let finalBalance = isDebt ? -abs(balance) : balance
            let _ = try await SupabaseManager.shared.insertAccount(name: name, type: type, currency: currency, balance: finalBalance)
            
            if finalBalance != 0 {
                let transactionType = finalBalance > 0 ? "income" : "expense"
                try await SupabaseManager.shared.insertTransaction(
                    amount: abs(finalBalance),
                    type: transactionType,
                    description: "Saldo inicial - \(name)",
                    date: Date()
                )
            }
            
            await fetchAccounts()
        } catch {
            print("Error guardando cuenta: \(error)")
        }
        isLoading = false
    }
    
    // Función para borrar cuenta
    func deleteAccount(account: Account) async {
        do {
            try await SupabaseManager.shared.deleteAccount(id: account.id, name: account.name)
            self.accounts.removeAll { $0.id == account.id }
        } catch {
            print("Error borrando cuenta: \(error)")
        }
    }
}
