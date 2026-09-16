import SwiftUI

struct BudgetsView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @AppStorage("monthly_budget_limit") private var monthlyBudgetLimit: Double = 2000000.0
    @State private var showEditBudgetSheet = false
    @State private var newBudgetInput: String = ""
    
    // Categorías con sus respectivos colores e íconos para la gráfica/desglose
    let categoryMeta: [String: (icon: String, color: Color)] = [
        "Comida": ("fork.knife", .orange),
        "Transporte": ("car.fill", .blue),
        "Compras": ("bag.fill", .purple),
        "Ocio": ("popcorn.fill", .pink),
        "Salud": ("heart.fill", .red),
        "Servicios": ("bolt.fill", .yellow),
        "Supermercado": ("cart.fill", .green),
        "Salario": ("dollarsign.circle.fill", .teal),
        "Inversión": ("chart.line.uptrend.xyaxis", .indigo),
        "Otros": ("ellipsis.circle.fill", .gray)
    ]
    
    // Gasto total de solo los gastos (expense)
    var totalExpenses: Double {
        viewModel.transactions
            .filter { $0.type == "expense" }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Progreso del presupuesto (0.0 a 1.0)
    var budgetProgress: Double {
        guard monthlyBudgetLimit > 0 else { return 0.0 }
        return min(totalExpenses / monthlyBudgetLimit, 1.0)
    }
    
    // Desglose agrupado por categoría
    var categoryBreakdown: [(category: String, amount: Double, percentage: Double)] {
        let expenses = viewModel.transactions.filter { $0.type == "expense" }
        guard !expenses.isEmpty else { return [] }
        
        var dict: [String: Double] = [:]
        for tx in expenses {
            let cat = extractCategory(from: tx.description)
            dict[cat, default: 0] += tx.amount
        }
        
        let total = totalExpenses > 0 ? totalExpenses : 1.0
        return dict.map { (category: $0.key, amount: $0.value, percentage: ($0.value / total) * 100) }
            .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    
                    // 1. TARJETA DE PRESUPUESTO MENSUAL
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Presupuesto del Mes")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("$\(totalExpenses, specifier: "%.2f") / $\(monthlyBudgetLimit, specifier: "%.0f")")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            }
                            Spacer()
                            Button(action: {
                                newBudgetInput = String(format: "%.0f", monthlyBudgetLimit)
                                showEditBudgetSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("Ajustar")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Barra de progreso personalizada
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(progressColor)
                                    .frame(width: geo.size.width * CGFloat(budgetProgress), height: 12)
                                    .animation(.spring(), value: budgetProgress)
                            }
                        }
                        .frame(height: 12)
                        
                        HStack {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(progressColor)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(budgetProgress * 100))% consumido")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    
                    // 2. DESGLOSE DE GASTOS POR CATEGORÍA
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Gastos por Categoría")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)
                        
                        if categoryBreakdown.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("Aún no tienes gastos registrados este mes.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemBackground))
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(categoryBreakdown, id: \.category) { item in
                                    let meta = categoryMeta[item.category] ?? ("tag.fill", Color.gray)
                                    
                                    VStack(spacing: 8) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(meta.color.opacity(0.15))
                                                    .frame(width: 36, height: 36)
                                                Image(systemName: meta.icon)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(meta.color)
                                            }
                                            
                                            Text(item.category)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("$\(item.amount, specifier: "%.2f")")
                                                    .font(.subheadline)
                                                    .bold()
                                                Text("\(item.percentage, specifier: "%.1f")%")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
                                        // Barrita porcentual individual
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color(UIColor.secondarySystemBackground))
                                                    .frame(height: 6)
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(meta.color)
                                                    .frame(width: geo.size.width * CGFloat(item.percentage / 100), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(UIColor.systemBackground))
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // 3. SECCIÓN DE METAS DE AHORRO
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Metas de Ahorro")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)
                        
                        // Tarjetas de metas pre-configuradas de ejemplo
                        GoalProgressCard(
                            title: "Fondo de Emergencia",
                            icon: "shield.fill",
                            color: .green,
                            currentAmount: 1200000,
                            targetAmount: 3000000
                        )
                        
                        GoalProgressCard(
                            title: "Vacaciones de Fin de Año",
                            icon: "airplane.departure",
                            color: .cyan,
                            currentAmount: 850000,
                            targetAmount: 2000000
                        )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Metas y Presupuesto")
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .refreshable {
                await viewModel.fetchTransactions()
            }
            .task {
                await viewModel.fetchTransactions()
            }
            .sheet(isPresented: $showEditBudgetSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Límite Mensual de Gastos"), footer: Text("Define cuánto quieres gastar como máximo por mes para mantener tus finanzas bajo control.")) {
                            TextField("Ej. 2000000", text: $newBudgetInput)
                                .keyboardType(.numberPad)
                        }
                        
                        Button(action: {
                            if let newLimit = Double(newBudgetInput.filter { "0123456789".contains($0) }), newLimit > 0 {
                                monthlyBudgetLimit = newLimit
                            }
                            showEditBudgetSheet = false
                        }) {
                            Text("Guardar Presupuesto")
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                        }
                    }
                    .navigationTitle("Ajustar Presupuesto")
                    .navigationBarItems(trailing: Button("Cancelar") { showEditBudgetSheet = false })
                }
            }
        }
    }
    
    private var progressColor: Color {
        if budgetProgress < 0.7 {
            return .green
        } else if budgetProgress < 0.9 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var statusMessage: String {
        if budgetProgress < 0.7 {
            return "✓ Vas por buen camino este mes"
        } else if budgetProgress < 0.9 {
            return "⚠️ Atención: has usado más del 70%"
        } else {
            return "🚨 ¡Límite casi alcanzado o superado!"
        }
    }
    
    private func extractCategory(from description: String?) -> String {
        guard let desc = description else { return "Otros" }
        if let start = desc.range(of: "[", options: .backwards)?.upperBound,
           let end = desc.range(of: "]", options: .backwards)?.lowerBound {
            return String(desc[start..<end])
        }
        return "Otros"
    }
}

// Subvista para tarjeta de meta de ahorro
struct GoalProgressCard: View {
    let title: String
    let icon: String
    let color: Color
    let currentAmount: Double
    let targetAmount: Double
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("$\(currentAmount, specifier: "%.0f") de $\(targetAmount, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
}
