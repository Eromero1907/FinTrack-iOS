import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedCategory: String = "Todas"
    
    // Control de confirmación de borrado
    @State private var transactionToDelete: Transaction? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    let categories = ["Todas", "Comida", "Transporte", "Compras", "Ocio", "Salud", "Servicios", "Supermercado", "Salario", "Inversión", "Otros"]
    
    var filteredTransactions: [Transaction] {
        if selectedCategory == "Todas" {
            return viewModel.transactions
        } else {
            return viewModel.transactions.filter { tx in
                let desc = tx.description ?? ""
                return desc.contains("[\(selectedCategory)]")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filtro horizontal con píldoras deslizables
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                withAnimation {
                                    selectedCategory = category
                                }
                            }) {
                                Text(category)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .background(Color(UIColor.systemBackground))
                
                // Lista de transacciones
                if viewModel.isLoading && viewModel.transactions.isEmpty {
                    Spacer()
                    ProgressView("Cargando historial...")
                    Spacer()
                } else if filteredTransactions.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 45))
                            .foregroundColor(.gray)
                        Text(selectedCategory == "Todas" ? "No tienes movimientos registrados." : "No hay movimientos en la categoría '\(selectedCategory)'")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTransactions) { transaction in
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(transaction.type == "income" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    
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
                            .padding(.vertical, 4)
                            // 1. Bloqueo de deslizamiento accidental: requires tap
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                            // 2. Opción también por long-press
                            .contextMenu {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Eliminar Movimiento", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Historial")
            .refreshable {
                await viewModel.fetchTransactions()
            }
            .task {
                await viewModel.fetchTransactions()
            }
            // 3. Ventana emergente obligatoria de confirmación
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
                Text("Se eliminará '\(cleanDescription(tx.description))' por $\(String(format: "%.2f", tx.amount)). El balance total se recalculará automáticamente.")
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
