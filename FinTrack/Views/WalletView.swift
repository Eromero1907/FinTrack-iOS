import SwiftUI

struct WalletView: View {
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @StateObject private var viewModel = WalletViewModel()
    @State private var showAddAccount = false
    
    @State private var showAddAlias = false
    @State private var showLogoutAlert = false
    
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
                                    account: account,
                                    color: cardColor(for: account.type)
                                )
                                .contextMenu {
                                    if account.type == "Tarjeta de Crédito" && !(account.isPrimary ?? false) {
                                        Button(action: {
                                            Task { await viewModel.setPrimaryCreditCard(account: account) }
                                        }) {
                                            Label("Marcar como TC Principal", systemImage: "star.fill")
                                        }
                                    }
                                    Button(role: .destructive, action: {
                                        Task { await viewModel.deleteAccount(account: account) }
                                    }) {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    
                    // SECCIÓN DE CONTACTOS FRECUENTES (ALIAS PARA TRANSFERENCIAS)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contactos Frecuentes (Alias)")
                                    .font(.headline)
                                Text("Para que tus transferencias salgan con nombre propio")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button(action: { showAddAlias = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Añadir")
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
                        .padding(.horizontal)
                        
                        if viewModel.aliases.isEmpty {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                Text("Registra cuentas de destino frecuentes para asociar el nombre del contacto automáticamente.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(UIColor.systemBackground))
                            )
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(viewModel.aliases) { alias in
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(.purple)
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(alias.contactName)
                                                .font(.subheadline)
                                                .bold()
                                            Text("Cuenta que termina en •••• \(String(alias.accountNumberOrLast4.suffix(4)))")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Button(role: .destructive, action: {
                                            Task { await viewModel.deleteAlias(id: alias.id) }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red.opacity(0.8))
                                                .padding(6)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor.systemBackground))
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    Spacer(minLength: 30)
                    
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
            .sheet(isPresented: $showAddAlias) {
                AddAliasView(viewModel: viewModel)
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
    var account: Account
    var color: Color
    
    var iconName: String {
        switch account.type {
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
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)
                    if account.isPrimary == true {
                        Text("⭐ Principal")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                }
                
                // Detalles de dígitos
                if account.type == "Banco" {
                    HStack(spacing: 8) {
                        if let lf = account.lastFour, !lf.isEmpty {
                            Text("Cta: ••\(lf)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        if let lfd = account.lastFourDebit, !lfd.isEmpty {
                            Text("Déb: ••\(lfd)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                } else if let lf = account.lastFour, !lf.isEmpty {
                    Text("•••• \(lf)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                
                // Tipo o Fechas de Corte
                if account.type == "Tarjeta de Crédito", let cutoff = account.cutoffDay {
                    Text("Corte día \(cutoff)\(account.paymentDay != nil ? " · Pago día \(account.paymentDay!)" : "")")
                        .font(.caption2)
                        .foregroundColor(.purple)
                } else {
                    Text(account.type == "Préstamo / Me deben" ? "Por cobrar" : account.type)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .foregroundColor(color)
                        .cornerRadius(6)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.currentBalance, format: .currency(code: account.currency))
                    .font(.title3)
                    .bold()
                    .foregroundColor(account.currentBalance >= 0 ? .primary : .red)
                
                if account.currentBalance < 0 {
                    Text("Deuda actual")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if account.type == "Préstamo / Me deben" {
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
    @State private var lastFour: String = ""
    @State private var lastFourDebit: String = ""
    @State private var cutoffDayString: String = ""
    @State private var paymentDayString: String = ""
    @State private var isPrimary: Bool = false
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
                    
                    if type == "Banco" {
                        TextField("Últimos 4 de la Cuenta (ej. 2667)", text: $lastFour)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFour) { _, v in
                                lastFour = String(v.filter { "0123456789".contains($0) }.prefix(4))
                            }
                        
                        TextField("Últimos 4 de la Tarjeta Débito (ej. 2131)", text: $lastFourDebit)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFourDebit) { _, v in
                                lastFourDebit = String(v.filter { "0123456789".contains($0) }.prefix(4))
                            }
                    } else if type == "Tarjeta de Crédito" {
                        TextField("Últimos 4 dígitos de la tarjeta (ej. 5678)", text: $lastFour)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFour) { _, v in
                                lastFour = String(v.filter { "0123456789".contains($0) }.prefix(4))
                            }
                    }
                }
                
                if type == "Tarjeta de Crédito" {
                    Section(header: Text("Ciclo de Facturación (Presupuesto)")) {
                        TextField("Día de corte (ej. 24)", text: $cutoffDayString)
                            .keyboardType(.numberPad)
                            .onChange(of: cutoffDayString) { _, v in
                                cutoffDayString = String(v.filter { "0123456789".contains($0) }.prefix(2))
                            }
                        
                        TextField("Día límite de pago (ej. 14)", text: $paymentDayString)
                            .keyboardType(.numberPad)
                            .onChange(of: paymentDayString) { _, v in
                                paymentDayString = String(v.filter { "0123456789".contains($0) }.prefix(2))
                            }
                        
                        Toggle("⭐ Tarjeta Principal de Facturación", isOn: $isPrimary)
                    }
                    
                    Section(
                        header: Text("Cupo y Deuda"),
                        footer: Text("💡 El cupo total no suma a tu patrimonio. La deuda actual sí se resta.")
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
                    Section(
                        header: Text("Saldo Inicial de Apertura"),
                        footer: Text("💡 Este saldo forma tu Patrimonio Neto base. NO contará como gasto ni ingreso del mes.")
                    ) {
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
                        
                        let cutoff = Int(cutoffDayString)
                        let payment = Int(paymentDayString)
                        
                        await viewModel.addAccount(
                            name: name,
                            type: type,
                            currency: currency,
                            balance: balanceValue,
                            isDebt: isDebt,
                            lastFour: lastFour.isEmpty ? nil : lastFour,
                            lastFourDebit: lastFourDebit.isEmpty ? nil : lastFourDebit,
                            cutoffDay: cutoff,
                            paymentDay: payment,
                            isPrimary: isPrimary
                        )
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

// MARK: - Modal para Añadir Contactos Frecuentes (Alias)
struct AddAliasView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: WalletViewModel
    
    @State private var contactName: String = ""
    @State private var accountNumber: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Información del Destinatario"),
                    footer: Text("💡 Cuando te llegue un SMS con este número de cuenta, FinTrack reemplazará los dígitos por el nombre de la persona automáticamente.")
                ) {
                    TextField("Nombre del contacto (ej. Mamá, Arriendo)", text: $contactName)
                    TextField("Número de cuenta o últimos 4 dígitos", text: $accountNumber)
                        .keyboardType(.numberPad)
                        .onChange(of: accountNumber) { _, v in
                            accountNumber = v.filter { "0123456789".contains($0) }
                        }
                }
                
                Button(action: {
                    Task {
                        await viewModel.addAlias(
                            accountNumberOrLast4: accountNumber,
                            contactName: contactName
                        )
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Guardar Contacto")
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(contactName.isEmpty || accountNumber.isEmpty ? .gray : .blue)
                }
                .disabled(contactName.isEmpty || accountNumber.isEmpty)
            }
            .navigationTitle("Nuevo Contacto")
            .navigationBarItems(trailing: Button("Cancelar") { presentationMode.wrappedValue.dismiss() })
        }
    }
}
