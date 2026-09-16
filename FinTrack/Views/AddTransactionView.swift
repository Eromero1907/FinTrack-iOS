import SwiftUI

struct AddTransactionView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var type: String = "expense"
    @State private var amountString: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: String = "Comida"
    @State private var selectedAccountId: UUID? = nil
    @State private var accounts: [Account] = []
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    let categories = ["Comida", "Transporte", "Compras", "Ocio", "Salud", "Servicios", "Supermercado", "Salario", "Inversión", "Otros"]
    
    var body: some View {
        NavigationView {
            Form {
                // Selector principal (Gasto vs Ingreso)
                Picker("Tipo", selection: $type) {
                    Text("Gasto (-)").tag("expense")
                    Text("Ingreso (+)").tag("income")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 5)
                
                Section(header: Text("Monto del Movimiento")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.gray)
                            .font(.title2)
                        
                        TextField("0", text: $amountString)
                            .keyboardType(.numberPad)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(type == "income" ? .green : .primary)
                            .onChange(of: amountString) { _, newValue in
                                amountString = formatAsCurrency(newValue)
                            }
                    }
                    .padding(.vertical, 10)
                }
                
                Section(header: Text("Detalles")) {
                    TextField("Descripción (ej. Almuerzo, Uber)", text: $description)
                    
                    Picker("Categoría", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    
                    if !accounts.isEmpty {
                        Picker("Cuenta / Tarjeta", selection: $selectedAccountId) {
                            Text("Ninguna / Efectivo").tag(nil as UUID?)
                            ForEach(accounts) { account in
                                Text("\(account.name) (\(account.currency))").tag(account.id as UUID?)
                            }
                        }
                    }
                    
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
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
                        Text("Guardar \(type == "income" ? "Ingreso" : "Gasto")")
                            .bold()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
                    .background(isFormValid && !isLoading ? (type == "income" ? Color.green : Color.blue) : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid || isLoading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.top, 10)
            }
            .navigationTitle(type == "income" ? "Nuevo Ingreso" : "Nuevo Gasto")
            .navigationBarItems(trailing: Button("Cancelar") {
                presentationMode.wrappedValue.dismiss()
            })
            .task {
                do {
                    accounts = try await SupabaseManager.shared.fetchAccounts()
                    if let first = accounts.first {
                        selectedAccountId = first.id
                    }
                } catch {
                    print("Error cargando cuentas para picker: \(error)")
                }
            }
        }
    }
    
    var isFormValid: Bool {
        let clean = amountString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let value = Double(clean), value > 0 else { return false }
        return !description.trimmingCharacters(in: .whitespaces).isEmpty
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
            let finalDesc = "\(description.trimmingCharacters(in: .whitespaces)) [\(selectedCategory)]"
            try await SupabaseManager.shared.insertTransaction(
                amount: amountValue,
                type: type,
                description: finalDesc,
                date: date,
                sourceAccountId: selectedAccountId
            )
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
