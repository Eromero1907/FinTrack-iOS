import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedCategory: String = "Todas"
    
    // Control de confirmación de borrado
    @State private var transactionToDelete: Transaction? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    // Control de exportación a Excel / CSV
    @State private var csvFileURL: URL? = nil
    @State private var showShareSheet: Bool = false
    
    let categories = ["Todas", "Comida", "Transporte", "Compras", "Ocio", "Salud", "Servicios", "Supermercado", "Salario", "Inversión", "Transferencias", "Otros"]
    
    var filteredTransactions: [Transaction] {
        if selectedCategory == "Todas" {
            return viewModel.transactions
        } else if selectedCategory == "Transferencias" {
            return viewModel.transactions.filter { $0.type == "transfer" }
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
                                        .fill(transactionBadgeColor(for: transaction.type).opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    
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
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
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
            .navigationBarItems(trailing: Button(action: {
                exportToCSV()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Excel")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(viewModel.transactions.isEmpty ? .gray : .blue)
            }
            .disabled(viewModel.transactions.isEmpty))
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
                Text("Se eliminará '\(cleanDescription(tx.description))' por $\(String(format: "%.2f", tx.amount)). El balance total se recalculará automáticamente.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = csvFileURL {
                    ShareSheet(activityItems: [url])
                }
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
    
    private func extractCategory(from raw: String?) -> String {
        guard let raw = raw else { return "Otros" }
        if let start = raw.range(of: "[", options: .backwards)?.upperBound,
           let end = raw.range(of: "]", options: .backwards)?.lowerBound {
            return String(raw[start..<end])
        }
        return "Otros"
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
    
    // MARK: - Generación de archivo Excel / CSV
    private func exportToCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        var csvString = "\u{FEFF}Fecha,Tipo,Categoría,Descripción,Monto\n"
        
        for tx in viewModel.transactions {
            let dateStr = dateFormatter.string(from: tx.date)
            let typeStr = tx.type == "income" ? "Ingreso" : (tx.type == "transfer" ? "Transferencia / Pago" : "Gasto")
            let catStr = tx.type == "transfer" ? "Transferencia" : extractCategory(from: tx.description)
            let descStr = cleanDescription(tx.description).replacingOccurrences(of: ",", with: " ")
            let amountStr = String(format: "%.2f", tx.amount)
            
            csvString.append("\"\(dateStr)\",\"\(typeStr)\",\"\(catStr)\",\"\(descStr)\",\(amountStr)\n")
        }
        
        let fileName = "FinTrack_Movimientos_\(Date().formatted(date: .numeric, time: .omitted)).csv"
            .replacingOccurrences(of: "/", with: "-")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            self.csvFileURL = tempURL
            self.showShareSheet = true
        } catch {
            print("Error al generar CSV: \(error)")
        }
    }
}

// Representable para la hoja de compartir nativa de iOS (AirDrop, WhatsApp, Excel, Archivos)
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
