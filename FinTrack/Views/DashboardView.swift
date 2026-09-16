import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var transactionToDelete: Transaction? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // TARJETA DE BALANCE
                    VStack {
                        Text("Balance Total")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("$\(viewModel.totalBalance, specifier: "%.2f")")
                            .font(.system(size: 45, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
                    )
                    .padding(.horizontal)
                    
                    // SECCIÓN DE TRANSACCIONES
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Transacciones Recientes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.isLoading && viewModel.transactions.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.transactions.isEmpty {
                            Text("Aún no tienes movimientos. ¡Tu cuenta está en ceros!")
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.transactions) { transaction in
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(transactionBadgeColor(for: transaction.type).opacity(0.15))
                                                .frame(width: 45, height: 45)
                                            
                                            Image(systemName: transactionIcon(for: transaction.type))
                                                .foregroundColor(transactionBadgeColor(for: transaction.type))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(cleanDescription(transaction.description))
                                                .font(.subheadline)
                                                .bold()
                                            Text(transaction.date, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(transactionAmountText(for: transaction))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(transactionAmountColor(for: transaction))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .fill(Color(UIColor.systemBackground))
                                    )
                                    .padding(.horizontal)
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            transactionToDelete = transaction
                                            showDeleteConfirmation = true
                                        }) {
                                            Label("Eliminar Movimiento", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Inicio")
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .refreshable {
                await viewModel.fetchTransactions()
            }
            .task {
                await viewModel.fetchTransactions()
            }
            .alert(
                "¿Eliminar este movimiento?",
                isPresented: $showDeleteConfirmation,
                presenting: transactionToDelete
            ) { tx in
                Button("Eliminar", role: .destructive) {
                    Task {
                        await viewModel.deleteTransaction(transaction: tx)
                    }
                }
                Button("Cancelar", role: .cancel) {
                    transactionToDelete = nil
                }
            } message: { tx in
                Text("Se eliminará '\(cleanDescription(tx.description))' por $\(String(format: "%.2f", tx.amount)) y se recalculará tu balance.")
            }
        }
    }
    
    private func cleanDescription(_ raw: String?) -> String {
        guard let raw = raw else { return "Movimiento" }
        if let bracketIndex = raw.range(of: " [", options: .backwards)?.lowerBound {
            return String(raw[..<bracketIndex])
        }
        return raw
    }
    
    private func transactionIcon(for type: String) -> String {
        switch type {
        case "income": return "arrow.down.left"
        case "transfer": return "arrow.left.arrow.right"
        default: return "cart.fill"
        }
    }
    
    private func transactionBadgeColor(for type: String) -> Color {
        switch type {
        case "income": return .green
        case "transfer": return .indigo
        default: return .red
        }
    }
    
    private func transactionAmountText(for tx: Transaction) -> String {
        switch tx.type {
        case "income": return "+$\(String(format: "%.2f", tx.amount))"
        case "transfer": return "$\(String(format: "%.2f", tx.amount))"
        default: return "-$\(String(format: "%.2f", abs(tx.amount)))"
        }
    }
    
    private func transactionAmountColor(for tx: Transaction) -> Color {
        switch tx.type {
        case "income": return .green
        case "transfer": return .indigo
        default: return .primary
        }
    }
}
