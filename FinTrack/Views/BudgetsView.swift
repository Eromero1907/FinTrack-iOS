import SwiftUI

// Modelo para metas de ahorro persistentes
struct SavingsGoal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var icon: String
    var colorName: String
    var currentAmount: Double
    var targetAmount: Double
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
}

struct BudgetsView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @AppStorage("monthly_budget_limit") private var monthlyBudgetLimit: Double = 2000000.0
    
    // Estado para modificar presupuesto
    @State private var showEditBudgetSheet = false
    @State private var newBudgetInput: String = ""
    
    // Metas de ahorro dinámicas guardadas en el teléfono (100% limpias sin dummies)
    @State private var goals: [SavingsGoal] = []
    @State private var showAddGoalSheet = false
    @State private var selectedGoalForDeposit: SavingsGoal? = nil
    
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
    
    var currentCycle: (start: Date, end: Date, daysRemaining: Int, label: String, isCustomCycle: Bool) {
        viewModel.currentCycleRange()
    }
    
    var cycleExpenses: [Transaction] {
        let cycle = currentCycle
        return viewModel.transactions.filter { tx in
            tx.type == "expense" &&
            !(tx.description?.hasPrefix("Saldo inicial") ?? false) &&
            tx.date >= cycle.start && tx.date <= cycle.end
        }
    }
    
    var totalExpenses: Double {
        cycleExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var budgetProgress: Double {
        guard monthlyBudgetLimit > 0 else { return 0.0 }
        return min(totalExpenses / monthlyBudgetLimit, 1.0)
    }
    
    var categoryBreakdown: [(category: String, amount: Double, percentage: Double)] {
        let expenses = cycleExpenses
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
                                HStack(spacing: 6) {
                                    Text(currentCycle.isCustomCycle ? "Ciclo de Facturación (TC)" : "Presupuesto del Mes")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    if currentCycle.isCustomCycle {
                                        Image(systemName: "creditcard.fill")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                    }
                                }
                                Text("\(totalExpenses.formattedCurrency()) / \(monthlyBudgetLimit.formattedCurrency())")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                
                                Text(currentCycle.label)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(currentCycle.isCustomCycle ? Color.purple.opacity(0.12) : Color.gray.opacity(0.12))
                                    .foregroundColor(currentCycle.isCustomCycle ? .purple : .gray)
                                    .cornerRadius(6)
                            }
                            Spacer()
                            Button(action: {
                                newBudgetInput = formatAsCurrency(String(format: "%.0f", monthlyBudgetLimit))
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
                                                Text(item.amount.formattedCurrency())
                                                    .font(.subheadline)
                                                    .bold()
                                                Text("\(item.percentage, specifier: "%.1f")%")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        
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
                    
                    // 3. SECCIÓN DE METAS DE AHORRO (LIMPIA)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Metas de Ahorro")
                                .font(.title3)
                                .bold()
                            Spacer()
                            Button(action: {
                                showAddGoalSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Nueva Meta")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if goals.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "target")
                                    .font(.system(size: 34))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("Aún no tienes metas creadas.")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.gray)
                                Text("Toca '+ Nueva Meta' para definir un objetivo real de ahorro con su monto objetivo.")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemBackground))
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(goals) { goal in
                                    InteractiveGoalCard(
                                        goal: goal,
                                        onDeposit: {
                                            selectedGoalForDeposit = goal
                                        },
                                        onDelete: {
                                            deleteGoal(goal)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 30)
                }
                .padding(.top)
            }
            .navigationTitle("Metas y Presupuesto")
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .refreshable {
                await viewModel.fetchTransactions()
            }
            .task {
                loadGoals()
                await viewModel.fetchTransactions()
            }
            // Sheet de ajustar presupuesto con formateo en tiempo real
            .sheet(isPresented: $showEditBudgetSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Límite Mensual de Gastos"), footer: Text("Define cuánto quieres gastar como máximo por mes para mantener tus finanzas bajo control.")) {
                            HStack {
                                Text("$").foregroundColor(.gray)
                                TextField("0", text: $newBudgetInput)
                                    .keyboardType(.numberPad)
                                    .onChange(of: newBudgetInput) { _, v in
                                        newBudgetInput = formatAsCurrency(v)
                                    }
                            }
                        }
                        
                        Button(action: {
                            let clean = newBudgetInput.filter { "0123456789".contains($0) }
                            if let newLimit = Double(clean), newLimit > 0 {
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
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Listo") { hideKeyboard() }
                        }
                    }
                }
            }
            // Sheet para crear nueva meta con formateo en tiempo real
            .sheet(isPresented: $showAddGoalSheet) {
                CreateGoalView { newGoal in
                    goals.append(newGoal)
                    saveGoals()
                }
            }
            // Sheet para abonar dinero con formateo en tiempo real
            .sheet(item: $selectedGoalForDeposit) { goal in
                DepositGoalView(goal: goal) { amountToAdd in
                    if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                        goals[index].currentAmount += amountToAdd
                        saveGoals()
                    }
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
    
    // MARK: - Persistencia 100% Limpia (Sin dummies)
    private func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: "user_savings_goals"),
           let decoded = try? JSONDecoder().decode([SavingsGoal].self, from: data) {
            // Filtramos cualquier dato dummy viejo de prueba
            self.goals = decoded.filter { $0.title != "Fondo de Emergencia" && $0.title != "Vacaciones" }
        } else {
            self.goals = []
        }
    }
    
    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: "user_savings_goals")
        }
    }
    
    private func deleteGoal(_ goal: SavingsGoal) {
        withAnimation {
            goals.removeAll { $0.id == goal.id }
            saveGoals()
        }
    }
    
    private func formatAsCurrency(_ value: String) -> String {
        let filtered = value.filter { "0123456789".contains($0) }
        if let intValue = Int(filtered) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: intValue)) ?? ""
        }
        return ""
    }
}

// Subvista para tarjeta interactiva de meta
struct InteractiveGoalCard: View {
    let goal: SavingsGoal
    let onDeposit: () -> Void
    let onDelete: () -> Void
    
    var color: Color {
        switch goal.colorName {
        case "green": return .green
        case "cyan": return .cyan
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        default: return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: goal.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(goal.currentAmount.formattedCurrency()) de \(goal.targetAmount.formattedCurrency())")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: onDeposit) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Abonar")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .cornerRadius(8)
                }
            }
            
            // Barra de progreso
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(goal.progress), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text(goal.progress >= 1.0 ? "🎉 ¡Meta Cumplida!" : "Faltan \(max(goal.targetAmount - goal.currentAmount, 0).formattedCurrency())")
                    .font(.caption2)
                    .foregroundColor(goal.progress >= 1.0 ? .green : .gray)
                    .fontWeight(goal.progress >= 1.0 ? .bold : .regular)
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar Meta", systemImage: "trash")
            }
        }
    }
}

// Modal para crear una nueva meta con formateo en tiempo real
struct CreateGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = ""
    @State private var targetInput: String = ""
    @State private var initialInput: String = ""
    @State private var selectedIcon: String = "target"
    @State private var selectedColor: String = "blue"
    
    let icons = ["target", "shield.fill", "airplane.departure", "car.fill", "house.fill", "gift.fill", "heart.fill"]
    let colors = [("Azul", "blue"), ("Verde", "green"), ("Cian", "cyan"), ("Morado", "purple"), ("Naranja", "orange"), ("Rosa", "pink")]
    
    var onSave: (SavingsGoal) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nombre de la Meta")) {
                    TextField("Ej: Viaje a Europa, Nuevo Celular", text: $title)
                }
                
                Section(header: Text("Montos")) {
                    HStack {
                        Text("$").foregroundColor(.gray)
                        TextField("Monto Objetivo (¿Cuánto necesitas?)", text: $targetInput)
                            .keyboardType(.numberPad)
                            .onChange(of: targetInput) { _, v in
                                targetInput = formatAsCurrency(v)
                            }
                    }
                    
                    HStack {
                        Text("$").foregroundColor(.gray)
                        TextField("Ahorro Inicial (opcional)", text: $initialInput)
                            .keyboardType(.numberPad)
                            .onChange(of: initialInput) { _, v in
                                initialInput = formatAsCurrency(v)
                            }
                    }
                }
                
                Section(header: Text("Personalización")) {
                    Picker("Ícono", selection: $selectedIcon) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon).tag(icon)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("Color", selection: $selectedColor) {
                        ForEach(colors, id: \.1) { color in
                            Text(color.0).tag(color.1)
                        }
                    }
                }
                
                Button(action: {
                    let cleanTarget = targetInput.filter { "0123456789".contains($0) }
                    let cleanInitial = initialInput.filter { "0123456789".contains($0) }
                    
                    let target = Double(cleanTarget) ?? 0.0
                    let initial = Double(cleanInitial) ?? 0.0
                    
                    guard !title.isEmpty, target > 0 else { return }
                    
                    let newGoal = SavingsGoal(
                        title: title,
                        icon: selectedIcon,
                        colorName: selectedColor,
                        currentAmount: initial,
                        targetAmount: target
                    )
                    onSave(newGoal)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Crear Meta")
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(title.isEmpty || targetInput.isEmpty ? .gray : .blue)
                }
                .disabled(title.isEmpty || targetInput.isEmpty)
            }
            .navigationTitle("Nueva Meta")
            .navigationBarItems(trailing: Button("Cancelar") { presentationMode.wrappedValue.dismiss() })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { hideKeyboard() }
                }
            }
        }
    }
    
    private func formatAsCurrency(_ value: String) -> String {
        let filtered = value.filter { "0123456789".contains($0) }
        if let intValue = Int(filtered) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: intValue)) ?? ""
        }
        return ""
    }
}

// Modal para abonar a una meta con formateo en tiempo real
struct DepositGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    let goal: SavingsGoal
    @State private var amountInput: String = ""
    var onDeposit: (Double) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meta: \(goal.title)"), footer: Text("Este monto se sumará al progreso actual de tu meta.")) {
                    HStack {
                        Text("$").foregroundColor(.gray)
                        TextField("0", text: $amountInput)
                            .keyboardType(.numberPad)
                            .onChange(of: amountInput) { _, v in
                                amountInput = formatAsCurrency(v)
                            }
                    }
                }
                
                Button(action: {
                    let clean = amountInput.filter { "0123456789".contains($0) }
                    if let amount = Double(clean), amount > 0 {
                        onDeposit(amount)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Confirmar Abono")
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(amountInput.isEmpty ? .gray : .green)
                }
                .disabled(amountInput.isEmpty)
            }
            .navigationTitle("Abonar a Meta")
            .navigationBarItems(trailing: Button("Cancelar") { presentationMode.wrappedValue.dismiss() })
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { hideKeyboard() }
                }
            }
        }
    }
    
    private func formatAsCurrency(_ value: String) -> String {
        let filtered = value.filter { "0123456789".contains($0) }
        if let intValue = Int(filtered) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: intValue)) ?? ""
        }
        return ""
    }
}
