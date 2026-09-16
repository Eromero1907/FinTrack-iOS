import Foundation
import AppIntents

// MARK: - 1. Atajo Estructurado: Registrar Transacción Manual o por Bloques
@available(iOS 16.0, *)
struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Transacción en FinTrack"
    static var description = IntentDescription("Registra un gasto, ingreso o pago en tu cuenta de FinTrack.")
    
    @Parameter(title: "Monto", description: "El valor del movimiento (ej. 25000)")
    var amount: Double
    
    @Parameter(title: "Tipo", default: "expense", description: "expense (gasto), income (ingreso) o transfer (transferencia/pago)")
    var type: String
    
    @Parameter(title: "Descripción", default: "Movimiento Atajo")
    var desc: String
    
    @Parameter(title: "Categoría", default: "Otros")
    var category: String
    
    @Parameter(title: "Últimos 4 Dígitos de Cuenta (opcional)")
    var lastFour: String?
    
    @Parameter(title: "Últimos 4 Dígitos Destino (opcional para pago tarjeta)")
    var destLastFour: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Registrar \(\.$type) de $\(\.$amount) como \(\.$desc)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard SupabaseManager.shared.currentUserId != nil else {
            return .result(value: "⚠️ Error: Debes iniciar sesión en la app FinTrack primero.")
        }
        
        // Buscar cuentas que coincidan con los últimos 4 dígitos
        var sourceAccountId: UUID? = nil
        var destAccountId: UUID? = nil
        
        if let accounts = try? await SupabaseManager.shared.fetchAccounts() {
            if let lf = lastFour?.filter({ "0123456789".contains($0) }), !lf.isEmpty {
                sourceAccountId = accounts.first(where: { $0.lastFour == lf })?.id
            }
            if let dlf = destLastFour?.filter({ "0123456789".contains($0) }), !dlf.isEmpty {
                destAccountId = accounts.first(where: { $0.lastFour == dlf })?.id
            }
            // Si no especificó origen pero hay una sola cuenta, usarla por defecto
            if sourceAccountId == nil && accounts.count == 1 {
                sourceAccountId = accounts.first?.id
            }
        }
        
        let finalDesc = "\(desc) [\(category)]"
        
        do {
            try await SupabaseManager.shared.insertTransaction(
                amount: amount,
                type: type,
                description: finalDesc,
                date: Date(),
                sourceAccountId: sourceAccountId,
                destAccountId: destAccountId
            )
            return .result(value: "✓ Registrado con éxito: $\(Int(amount)) en \(desc)")
        } catch {
            return .result(value: "⚠️ Error al guardar en FinTrack: \(error.localizedDescription)")
        }
    }
}

// MARK: - 2. Atajo Mágico: Procesar SMS de Banco Automáticamente
@available(iOS 16.0, *)
struct ParseBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Procesar SMS Bancario en FinTrack"
    static var description = IntentDescription("Lee el texto de un SMS de Bancolombia, Nu, Davivienda, etc., extrae el monto y registra el gasto en automático.")
    
    @Parameter(title: "Texto del SMS", description: "El mensaje recibido del banco")
    var smsText: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Procesar SMS bancario: \(\.$smsText)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard SupabaseManager.shared.currentUserId != nil else {
            return .result(value: "⚠️ Error: Abre e inicia sesión en FinTrack primero.")
        }
        
        let text = smsText
        let lower = text.lowercased()
        
        // 1. Detectar si es Pago de Tarjeta o Transferencia
        var type = "expense"
        if lower.contains("pago tarjeta") || lower.contains("pago tc") || lower.contains("pago de tarjeta") || lower.contains("recibimos tu pago") {
            type = "transfer"
        } else if lower.contains("transferencia recibida") || lower.contains("abono") || lower.contains("consignacion") {
            type = "income"
        }
        
        // 2. Extraer Monto con Regex ($XX,XXX o $XX.XXX)
        var extractedAmount: Double = 0.0
        if let match = text.range(of: #"\$\s?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?)"#, options: .regularExpression) {
            var rawValue = String(text[match]).replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            // Quitar separadores de miles
            if rawValue.contains(".") && rawValue.contains(",") {
                rawValue = rawValue.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else if rawValue.contains(".") {
                // En Colombia el punto suele ser miles (ej. 50.000)
                let parts = rawValue.split(separator: ".")
                if parts.last?.count == 3 {
                    rawValue = rawValue.replacingOccurrences(of: ".", with: "")
                }
            } else if rawValue.contains(",") {
                let parts = rawValue.split(separator: ",")
                if parts.last?.count == 3 {
                    rawValue = rawValue.replacingOccurrences(of: ",", with: "")
                }
            }
            extractedAmount = Double(rawValue) ?? 0.0
        }
        
        guard extractedAmount > 0 else {
            return .result(value: "⚠️ No se detectó un monto en el SMS: '\(text.prefix(30))...'")
        }
        
        // 3. Extraer últimos 4 dígitos (*1234)
        var lastFour: String? = nil
        if let match = text.range(of: #"\*([0-9]{4})"#, options: .regularExpression) {
            lastFour = String(text[match]).replacingOccurrences(of: "*", with: "")
        }
        
        // 4. Extraer Comercio o Descripción ("en COMERCIO")
        var merchant = "Compra Bancaria"
        if let enRange = text.range(of: #" en ([A-Za-z0-9\s]+?)(?: con| por| el|\.|$)"#, options: .regularExpression) {
            var matchStr = String(text[enRange])
            matchStr = matchStr.replacingOccurrences(of: " en ", with: "")
            merchant = matchStr.trimmingCharacters(in: .whitespaces)
        } else if type == "transfer" {
            merchant = "Pago Tarjeta de Crédito"
        }
        
        // 5. Categorización Inteligente Automática
        var category = "Otros"
        let mLower = merchant.lowercased()
        if mLower.contains("exito") || mLower.contains("jumbo") || mLower.contains("carulla") || mLower.contains("d1") || mLower.contains("ara") {
            category = "Supermercado"
        } else if mLower.contains("uber") || mLower.contains("didi") || mLower.contains("gasolin") || mLower.contains("peaje") || mLower.contains("taxi") {
            category = "Transporte"
        } else if mLower.contains("restaurante") || mLower.contains("mcdonald") || mLower.contains("starbucks") || mLower.contains("rappi") || mLower.contains("cafe") {
            category = "Comida"
        } else if mLower.contains("zara") || mLower.contains("h&m") || mLower.contains("falabella") || mLower.contains("nike") || mLower.contains("adidas") {
            category = "Compras"
        } else if mLower.contains("cine") || mLower.contains("netflix") || mLower.contains("spotify") || mLower.contains("bar") {
            category = "Ocio"
        } else if mLower.contains("farmacia") || mLower.contains("drogueria") || mLower.contains("salud") {
            category = "Salud"
        }
        
        // 6. Vincular con cuentas
        var sourceAccountId: UUID? = nil
        var destAccountId: UUID? = nil
        
        if let accounts = try? await SupabaseManager.shared.fetchAccounts() {
            if let lf = lastFour {
                if type == "transfer" {
                    // Si es pago de tarjeta, la que termina en *XXXX suele ser la tarjeta destino
                    destAccountId = accounts.first(where: { $0.lastFour == lf })?.id
                    // Y el origen es la primera cuenta de banco disponible
                    sourceAccountId = accounts.first(where: { $0.type == "Banco" })?.id
                } else {
                    sourceAccountId = accounts.first(where: { $0.lastFour == lf })?.id
                }
            }
            if sourceAccountId == nil {
                sourceAccountId = accounts.first(where: { $0.type == "Banco" })?.id ?? accounts.first?.id
            }
        }
        
        let finalDesc = type == "transfer" ? "Pago Tarjeta Automático" : "\(merchant) [\(category)]"
        
        do {
            try await SupabaseManager.shared.insertTransaction(
                amount: extractedAmount,
                type: type,
                description: finalDesc,
                date: Date(),
                sourceAccountId: sourceAccountId,
                destAccountId: destAccountId
            )
            return .result(value: "✓ FinTrack: Registrado $\(Int(extractedAmount)) en \(merchant) (\(category))")
        } catch {
            return .result(value: "⚠️ Error al guardar: \(error.localizedDescription)")
        }
    }
}

// MARK: - 3. Proveedor de Atajos para que aparezcan en la app Atajos de iOS
@available(iOS 16.0, *)
struct FinTrackShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ParseBankSMSIntent(),
            phrases: [
                "Procesar gasto bancario en \(.applicationName)",
                "Registrar SMS en \(.applicationName)"
            ],
            shortTitle: "Procesar SMS Bancario",
            systemImageName: "creditcard.and.123"
        )
        AppShortcut(
            intent: LogTransactionIntent(),
            phrases: [
                "Registrar movimiento en \(.applicationName)",
                "Añadir gasto a \(.applicationName)"
            ],
            shortTitle: "Registrar Transacción",
            systemImageName: "plus.circle.fill"
        )
    }
}
