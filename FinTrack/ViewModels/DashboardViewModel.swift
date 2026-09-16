import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var accounts: [Account] = []
    @Published var totalBalance: Double = 0.0
    @Published var isLoading = false
    
    // Función para obtener transacciones y cuentas de forma nativa
    func fetchTransactions() async {
        isLoading = true
        do {
            async let fetchedTx = SupabaseManager.shared.fetchTransactions()
            async let fetchedAcc = SupabaseManager.shared.fetchAccounts()
            
            let (txList, accList) = try await (fetchedTx, fetchedAcc)
            self.transactions = txList
            self.accounts = accList
            self.calculateBalance()
        } catch {
            print("Error al descargar datos de dashboard: \(error)")
        }
        isLoading = false
    }
    
    // Función para eliminar una transacción
    func deleteTransaction(transaction: Transaction) async {
        do {
            try await SupabaseManager.shared.deleteTransaction(id: transaction.id)
            self.transactions.removeAll { $0.id == transaction.id }
            // Recargar cuentas para reflejar balances revertidos
            if let updatedAccounts = try? await SupabaseManager.shared.fetchAccounts() {
                self.accounts = updatedAccounts
            }
            self.calculateBalance()
        } catch {
            print("Error al borrar transacción: \(error)")
        }
    }
    
    // El balance real es el Patrimonio Neto acumulado de todas las cuentas
    private func calculateBalance() {
        if !accounts.isEmpty {
            totalBalance = accounts.reduce(0) { $0 + $1.currentBalance }
        } else {
            // Fallback a transacciones si aún no se han cargado cuentas
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
    
    // MARK: - Tarjeta de Crédito Principal y Ciclo de Facturación
    var primaryCreditCard: Account? {
        accounts.first(where: { $0.type == "Tarjeta de Crédito" && ($0.isPrimary == true) })
    }
    
    // Calcula la ventana activa del ciclo de facturación
    func currentCycleRange() -> (start: Date, end: Date, daysRemaining: Int, label: String, isCustomCycle: Bool) {
        let calendar = Calendar.current
        let now = Date()
        
        guard let primaryCard = primaryCreditCard,
              let cutoffDay = primaryCard.cutoffDay,
              cutoffDay >= 1 && cutoffDay <= 31 else {
            // Ciclo por defecto: Mes Calendario
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components) ?? now
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) ?? now
            let daysLeft = calendar.dateComponents([.day], from: now, to: end).day ?? 0
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_CO")
            formatter.dateFormat = "d MMM"
            let label = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
            
            return (start, end, max(0, daysLeft), label, false)
        }
        
        let currentDay = calendar.component(.day, from: now)
        var startComponents = calendar.dateComponents([.year, .month], from: now)
        startComponents.day = cutoffDay
        startComponents.hour = 0
        startComponents.minute = 0
        startComponents.second = 0
        
        let startDate: Date
        if currentDay >= cutoffDay {
            startDate = calendar.date(from: startComponents) ?? now
        } else {
            let currentMonthStart = calendar.date(from: startComponents) ?? now
            startDate = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? now
        }
        
        let nextCycleStart = calendar.date(byAdding: .month, value: 1, to: startDate) ?? now
        let endDate = calendar.date(byAdding: .second, value: -1, to: nextCycleStart) ?? now
        let daysLeft = calendar.dateComponents([.day], from: now, to: nextCycleStart).day ?? 0
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "d MMM"
        let label = "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate)) (Corte en \(max(0, daysLeft)) días)"
        
        return (startDate, endDate, max(0, daysLeft), label, true)
    }
}
