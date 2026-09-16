import Foundation
import SwiftUI

@MainActor
class WalletViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var aliases: [AccountAlias] = []
    @Published var isLoading = false
    
    func fetchAccounts() async {
        isLoading = true
        do {
            self.accounts = try await SupabaseManager.shared.fetchAccounts()
            self.aliases = (try? await SupabaseManager.shared.fetchAccountAliases()) ?? []
        } catch {
            print("Error cargando cuentas: \(error)")
        }
        isLoading = false
    }
    
    func addAccount(
        name: String,
        type: String,
        currency: String,
        balance: Double,
        isDebt: Bool,
        lastFour: String? = nil,
        lastFourDebit: String? = nil,
        cutoffDay: Int? = nil,
        paymentDay: Int? = nil,
        isPrimary: Bool? = nil
    ) async {
        isLoading = true
        do {
            let finalBalance = isDebt ? -abs(balance) : balance
            let _ = try await SupabaseManager.shared.insertAccount(
                name: name,
                type: type,
                currency: currency,
                balance: finalBalance,
                lastFour: lastFour,
                lastFourDebit: lastFourDebit,
                cutoffDay: cutoffDay,
                paymentDay: paymentDay,
                isPrimary: isPrimary
            )
            
            // IMPORTANTE: Ya NO creamos transacción de "Saldo inicial" en el historial de gastos del mes.
            // El saldo base queda registrado exclusivamente en la cuenta para el Patrimonio Neto real.
            
            await fetchAccounts()
        } catch {
            print("Error guardando cuenta: \(error)")
        }
        isLoading = false
    }
    
    func setPrimaryCreditCard(account: Account) async {
        do {
            try await SupabaseManager.shared.setPrimaryCreditCard(id: account.id)
            await fetchAccounts()
        } catch {
            print("Error marcando TC principal: \(error)")
        }
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
    
    // MARK: - Alias Management
    func addAlias(accountNumberOrLast4: String, contactName: String) async {
        do {
            let newAlias = try await SupabaseManager.shared.insertAccountAlias(
                accountNumberOrLast4: accountNumberOrLast4,
                contactName: contactName
            )
            self.aliases.insert(newAlias, at: 0)
        } catch {
            print("Error creando alias: \(error)")
        }
    }
    
    func deleteAlias(id: UUID) async {
        do {
            try await SupabaseManager.shared.deleteAccountAlias(id: id)
            self.aliases.removeAll { $0.id == id }
        } catch {
            print("Error borrando alias: \(error)")
        }
    }
}
