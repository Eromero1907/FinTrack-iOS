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
                                                .fill(transaction.type == "income" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                                .frame(width: 45, height: 45)
                                            
                                            Image(systemName: transaction.type == "income" ? "arrow.down.left" : "cart.fill")
                                                .foregroundColor(transaction.type == "income" ? .green : .red)
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
                                        
                                        Text(transaction.type == "income" ? "+$\(transaction.amount, specifier: "%.2f")" : "-$\(abs(transaction.amount), specifier: "%.2f")")
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(transaction.type == "income" ? .green : .primary)
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
}
