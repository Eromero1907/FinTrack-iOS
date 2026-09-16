import SwiftUI

struct WalletView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @StateObject private var viewModel = WalletViewModel()
    @State private var showAddAccount = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Button(action: { showAddAccount = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Añadir Cuenta, Tarjeta o Préstamo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Mis Cuentas y Activos")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        if viewModel.isLoading && viewModel.accounts.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else if viewModel.accounts.isEmpty {
                            Text("Aún no tienes cuentas registradas.")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.accounts) { account in
                                AccountCard(
                                    name: account.name,
                                    type: account.type,
                                    balance: account.currentBalance,
                                    currency: account.currency,
                                    color: cardColor(for: account.type)
                                )
                                .contextMenu {
                                    Button(role: .destructive, action: {
                                        Task { await viewModel.deleteAccount(account: account) }
                                    }) {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                    
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Cerrar Sesión")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.top)
            }
            .navigationTitle("Billetera")
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .sheet(isPresented: $showAddAccount) {
                AddAccountView(viewModel: viewModel)
            }
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("¿Cerrar Sesión?"),
                    message: Text("Tendrás que volver a ingresar tu correo y contraseña para entrar."),
                    primaryButton: .destructive(Text("Cerrar Sesión")) {
                        SupabaseManager.shared.signOut()
                    },
                    secondaryButton: .cancel(Text("Cancelar"))
                )
            }
            .onAppear {
                Task {
                    await viewModel.fetchAccounts()
                }
            }
            .refreshable {
                await viewModel.fetchAccounts()
            }
        }
    }
    
    @State private var showLogoutAlert = false
    
    private func cardColor(for type: String) -> Color {
        switch type {
        case "Tarjeta de Crédito":
            return .purple
        case "Préstamo / Me deben":
            return .orange
        case "Efectivo":
            return .green
        default:
            return .blue
        }
    }
}

struct AccountCard: View {
    var name: String
    var type: String
    var balance: Double
    var currency: String
    var color: Color
    
    var iconName: String {
        switch type {
        case "Tarjeta de Crédito":
            return "creditcard.fill"
        case "Préstamo / Me deben":
            return "hand.raised.fill"
        case "Efectivo":
            return "banknote.fill"
        default:
            return "building.columns.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .foregroundColor(color)
                    .font(.system(size: 18, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(type == "Préstamo / Me deben" ? "Por cobrar" : type)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .cornerRadius(6)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(balance, format: .currency(code: currency))
                    .font(.title3)
                    .bold()
                    .foregroundColor(balance >= 0 ? .primary : .red)
                
                if balance < 0 {
                    Text("Deuda actual")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if type == "Préstamo / Me deben" {
                    Text("Te deben")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal)
    }
}

struct AddAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: WalletViewModel
    
    @State private var name: String = ""
    @State private var type: String = "Banco"
    @State private var currency: String = "COP"
    @State private var balanceString: String = ""
    @State private var creditLimitString: String = ""
    
    let types = ["Banco", "Efectivo", "Tarjeta de Crédito", "Préstamo / Me deben"]
    let currencies = ["COP", "USD", "EUR", "MXN", "GBP", "ARS", "CLP"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detalles de la Cuenta")) {
                    TextField(namePlaceholder, text: $name)
                    Picker("Tipo", selection: $type) { ForEach(types, id: \.self) { Text($0) } }
                    Picker("Moneda", selection: $currency) { ForEach(currencies, id: \.self) { Text($0) } }
                }
                
                if type == "Tarjeta de Crédito" {
                    Section(
                        header: Text("Información de la Tarjeta"),
                        footer: Text("💡 El cupo total no suma a tu patrimonio (no es dinero tuyo). La deuda actual sí se resta.")
                    ) {
                        TextField("Cupo Total (Límite)", text: $creditLimitString)
                            .keyboardType(.numberPad)
                            .onChange(of: creditLimitString) { _, v in creditLimitString = formatAsCurrency(v) }
                        
                        TextField("Deuda Actual", text: $balanceString)
                            .keyboardType(.numberPad)
                            .onChange(of: balanceString) { _, v in balanceString = formatAsCurrency(v) }
                    }
                } else if type == "Préstamo / Me deben" {
                    Section(
                        header: Text("Monto del Préstamo"),
                        footer: Text("💡 Este dinero cuenta como parte de tu patrimonio porque sigue siendo tuyo y está pendiente por cobrar.")
                    ) {
                        TextField("¿Cuánto dinero te deben?", text: $balanceString)
                            .keyboardType(.numberPad)
                            .onChange(of: balanceString) { _, v in balanceString = formatAsCurrency(v) }
                    }
                } else {
                    Section(header: Text("Saldo Actual")) {
                        TextField("¿Cuánto dinero tienes aquí?", text: $balanceString)
                            .keyboardType(.numberPad)
                            .onChange(of: balanceString) { _, v in balanceString = formatAsCurrency(v) }
                    }
                }
                
                Button(action: {
                    Task {
                        let cleanBalance = balanceString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        let balanceValue = Double(cleanBalance) ?? 0.0
                        let isDebt = type == "Tarjeta de Crédito"
                        
                        await viewModel.addAccount(name: name, type: type, currency: currency, balance: balanceValue, isDebt: isDebt)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView().padding(.trailing, 5)
                        }
                        Text("Guardar").bold()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(name.isEmpty ? .gray : .blue)
                }
                .disabled(name.isEmpty || viewModel.isLoading)
            }
            .navigationTitle(type == "Préstamo / Me deben" ? "Nuevo Préstamo" : "Nueva Cuenta")
            .navigationBarItems(trailing: Button("Cancelar") { presentationMode.wrappedValue.dismiss() })
        }
    }
    
    var namePlaceholder: String {
        switch type {
        case "Préstamo / Me deben":
            return "Nombre (ej. Préstamo a Mateo)"
        case "Tarjeta de Crédito":
            return "Nombre (ej. Tarjeta Nu)"
        case "Efectivo":
            return "Nombre (ej. Billetera física)"
        default:
            return "Nombre (ej. Bancolombia)"
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
