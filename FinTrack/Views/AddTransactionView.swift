import SwiftUI

struct AddTransactionView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var type: String = "expense"
    @State private var amountString: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: String = "Comida"
    
    // Cuentas origen y destino para transferencias / pagos
    @State private var selectedAccountId: UUID? = nil
    @State private var selectedDestAccountId: UUID? = nil
    @State private var accounts: [Account] = []
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    let categories = ["Comida", "Transporte", "Compras", "Ocio", "Salud", "Servicios", "Supermercado", "Salario", "Inversión", "Otros"]
    
    var body: some View {
        NavigationView {
            Form {
                // Selector principal (Gasto vs Ingreso vs Transferencia / Pago)
                Picker("Tipo", selection: $type) {
                    Text("Gasto (-)").tag("expense")
                    Text("Ingreso (+)").tag("income")
                    Text("Pago / Transferencia ⇄").tag("transfer")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 5)
                
                Section(header: Text(type == "transfer" ? "Monto a Transferir / Pagar" : "Monto del Movimiento")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.gray)
                            .font(.title2)
                        
                        TextField("0", text: $amountString)
                            .keyboardType(.numberPad)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(amountColor)
                            .onChange(of: amountString) { _, newValue in
                                amountString = formatAsCurrency(newValue)
                            }
                    }
                    .padding(.vertical, 10)
                }
                
                if type == "transfer" {
                    Section(header: Text("Cuentas Involucradas"), footer: Text("💡 El dinero saldrá de la cuenta origen y entrará a la cuenta destino (ej. para pagar la tarjeta Nu desde Bancolombia). El patrimonio total no cambia.")) {
                        Picker("De (Origen)", selection: $selectedAccountId) {
                            Text("Selecciona cuenta origen").tag(nil as UUID?)
                            ForEach(accounts) { account in
                                Text(accountLabel(for: account)).tag(account.id as UUID?)
                            }
                        }
                        
                        Picker("A (Destino / Tarjeta)", selection: $selectedDestAccountId) {
                            Text("Selecciona cuenta destino").tag(nil as UUID?)
                            ForEach(accounts) { account in
                                Text(accountLabel(for: account)).tag(account.id as UUID?)
                            }
                        }
                    }
                    
                    Section(header: Text("Detalles Adicionales")) {
                        TextField("Nota (opcional, ej. Pago mensual)", text: $description)
                        DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    }
                } else {
                    Section(header: Text("Detalles")) {
                        TextField("Descripción (ej. Almuerzo, Uber)", text: $description)
                        
                        Picker("Categoría", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { Text($0) }
                        }
                        
                        if !accounts.isEmpty {
                            Picker("Cuenta / Tarjeta", selection: $selectedAccountId) {
                                Text("Ninguna / Efectivo").tag(nil as UUID?)
                                ForEach(accounts) { account in
                                    Text(accountLabel(for: account)).tag(account.id as UUID?)
                                }
                            }
                        }
                        
                        DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    Task {
                        await saveTransaction()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 5)
                        }
                        Text(buttonTitle)
                            .bold()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
                    .background(isFormValid && !isLoading ? buttonColor : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || isLoading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, 10)
            }
            .navigationTitle(navTitle)
            .navigationBarItems(trailing: Button("Cancelar") {
                presentationMode.wrappedValue.dismiss()
            })
            .task {
                do {
                    accounts = try await SupabaseManager.shared.fetchAccounts()
                    if let first = accounts.first {
                        selectedAccountId = first.id
                    }
                    if accounts.count > 1 {
                        selectedDestAccountId = accounts[1].id
                    }
                } catch {
                    print("Error cargando cuentas para picker: \(error)")
                }
            }
        }
    }
    
    private var amountColor: Color {
        switch type {
        case "income": return .green
        case "transfer": return .indigo
        default: return .primary
        }
    }
    
    private var buttonColor: Color {
        switch type {
        case "income": return .green
        case "transfer": return .indigo
        default: return .blue
        }
    }
    
    private var buttonTitle: String {
        switch type {
        case "income": return "Guardar Ingreso"
        case "transfer": return "Realizar Pago / Transferencia"
        default: return "Guardar Gasto"
        }
    }
    
    private var navTitle: String {
        switch type {
        case "income": return "Nuevo Ingreso"
        case "transfer": return "Transferencia / Pago"
        default: return "Nuevo Gasto"
        }
    }
    
    private func accountLabel(for account: Account) -> String {
        let lastFourText = (account.lastFour != nil && !account.lastFour!.isEmpty) ? " •••• \(account.lastFour!)" : ""
        return "\(account.name)\(lastFourText) (\(account.currency))"
    }
    
    var isFormValid: Bool {
        let clean = amountString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let value = Double(clean), value > 0 else { return false }
        
        if type == "transfer" {
            guard let src = selectedAccountId, let dst = selectedDestAccountId, src != dst else {
                return false
            }
            return true
        } else {
            return !description.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    private func saveTransaction() async {
        isLoading = true
        errorMessage = nil
        
        let clean = amountString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let amountValue = Double(clean), amountValue > 0 else {
            isLoading = false
            return
        }
        
        do {
            if type == "transfer" {
                guard let srcId = selectedAccountId, let dstId = selectedDestAccountId, srcId != dstId else {
                    errorMessage = "Las cuentas origen y destino deben ser distintas."
                    isLoading = false
                    return
                }
                
                let srcName = accounts.first(where: { $0.id == srcId })?.name ?? "Cuenta Origen"
                let dstName = accounts.first(where: { $0.id == dstId })?.name ?? "Cuenta Destino"
                
                let note = description.trimmingCharacters(in: .whitespaces)
                let finalDesc = note.isEmpty ? "Transferencia: \(srcName) → \(dstName)" : "\(note) [\(srcName) → \(dstName)]"
                
                try await SupabaseManager.shared.insertTransaction(
                    amount: amountValue,
                    type: "transfer",
                    description: finalDesc,
                    date: date,
                    sourceAccountId: srcId,
                    destAccountId: dstId
                )
            } else {
                let finalDesc = "\(description.trimmingCharacters(in: .whitespaces)) [\(selectedCategory)]"
                try await SupabaseManager.shared.insertTransaction(
                    amount: amountValue,
                    type: type,
                    description: finalDesc,
                    date: date,
                    sourceAccountId: selectedAccountId
                )
            }
            
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = "Error guardando movimiento: \(error.localizedDescription)"
        }
        
        isLoading = false
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
