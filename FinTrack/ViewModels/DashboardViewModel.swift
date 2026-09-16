import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var totalBalance: Double = 0.0
    @Published var isLoading = false
    
    // Función para obtener transacciones de forma nativa
    func fetchTransactions() async {
        isLoading = true
        do {
            let fetchedTransactions = try await SupabaseManager.shared.fetchTransactions()
            self.transactions = fetchedTransactions
            self.calculateBalance()
        } catch {
            print("Error al descargar transacciones: \(error)")
        }
        isLoading = false
    }
    
    // Función para eliminar una transacción (Swipe to delete o menú)
    func deleteTransaction(transaction: Transaction) async {
        do {
            try await SupabaseManager.shared.deleteTransaction(id: transaction.id)
            self.transactions.removeAll { $0.id == transaction.id }
            self.calculateBalance()
        } catch {
            print("Error al borrar transacción: \(error)")
        }
    }
    
    private func calculateBalance() {
        totalBalance = transactions.reduce(0) { (result, transaction) in
            if transaction.type == "income" {
                return result + transaction.amount
            } else if transaction.type == "expense" {
                return result - abs(transaction.amount)
            }
            return result
        }
    }
}
