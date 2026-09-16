import Foundation
import AppIntents

// MARK: - 1. Atajo Estructurado: Registrar Transacción Manual o por Bloques
@available(iOS 16.0, *)
struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Transacción en FinTrack"
    static var description = IntentDescription("Registra un gasto, ingreso o pago en tu cuenta de FinTrack.")
    
    @Parameter(title: "Monto", description: "El valor del movimiento (ej. 25000)")
    var amount: Double
    
    @Parameter(title: "Tipo", description: "expense (gasto), income (ingreso) o transfer (transferencia/pago)", default: "expense")
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
        
        var sourceAccountId: UUID? = nil
        var destAccountId: UUID? = nil
        
        if let accounts = try? await SupabaseManager.shared.fetchAccounts() {
            if let lf = lastFour?.filter({ "0123456789".contains($0) }), !lf.isEmpty {
                sourceAccountId = accounts.first(where: { $0.lastFour == lf })?.id
            }
            if let dlf = destLastFour?.filter({ "0123456789".contains($0) }), !dlf.isEmpty {
                destAccountId = accounts.first(where: { $0.lastFour == dlf })?.id
            }
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

// MARK: - 2. Atajo Mágico Inteligente: Procesar SMS Bancario con Detección entre Cuentas Propias
@available(iOS 16.0, *)
struct ParseBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Procesar SMS Bancario en FinTrack"
    static var description = IntentDescription("Lee el SMS, extrae el monto y detecta si el pago fue hacia una de tus propias tarjetas (ej. PSE a Nu) para registrarlo como transferencia automática.")
    
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
        
        // 1. Extraer Monto con Regex ($XX,XXX o $XX.XXX)
        var extractedAmount: Double = 0.0
        if let match = text.range(of: #"\$\s?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?)"#, options: .regularExpression) {
            var rawValue = String(text[match]).replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            if rawValue.contains(".") && rawValue.contains(",") {
                rawValue = rawValue.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else if rawValue.contains(".") {
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
        
        // 2. Extraer últimos 4 dígitos de la cuenta origen (*1234)
        var sourceLastFour: String? = nil
        if let match = text.range(of: #"\*([0-9]{4})"#, options: .regularExpression) {
            sourceLastFour = String(text[match]).replacingOccurrences(of: "*", with: "")
        }
        
        // 3. Extraer Nombre del Comercio o Destino ("a COMERCIO", "en COMERCIO", etc.)
        var destinationRawName = "Movimiento Bancario"
        if let aRange = text.range(of: #"(?: a | en | pse a | pse en )([A-Za-z0-9\s]+?)(?: desde| con| por| el|\.|$)"#, options: [.regularExpression, .caseInsensitive]) {
            var matchStr = String(text[aRange])
            matchStr = matchStr.replacingOccurrences(of: " a ", with: "", options: .caseInsensitive)
            matchStr = matchStr.replacingOccurrences(of: " en ", with: "", options: .caseInsensitive)
            matchStr = matchStr.replacingOccurrences(of: "pse ", with: "", options: .caseInsensitive)
            destinationRawName = matchStr.trimmingCharacters(in: .whitespaces)
        }
        
        // 4. Buscar cuentas en FinTrack para emparejar automáticamente
        let allAccounts = (try? await SupabaseManager.shared.fetchAccounts()) ?? []
        
        // Identificar Cuenta Origen
        var sourceAccount: Account? = nil
        if let slf = sourceLastFour {
            sourceAccount = allAccounts.first(where: { $0.lastFour == slf })
        }
        if sourceAccount == nil {
            sourceAccount = allAccounts.first(where: { $0.type == "Banco" }) ?? allAccounts.first
        }
        
        // 5. DETECCIÓN INTELIGENTE DE CUENTAS PROPIAS (Transferencia vs Gasto)
        var type = "expense"
        var destAccount: Account? = nil
        
        // Verificamos si el destinatario mencionado en el SMS coincide con alguna de tus cuentas registradas
        let destLower = destinationRawName.lowercased()
        for acc in allAccounts {
            guard acc.id != sourceAccount?.id else { continue } // No puede ser la misma cuenta
            
            let accNameLower = acc.name.lowercased()
            
            // Si el SMS menciona el nombre de tu cuenta (ej. "Nu", "Nubank", "Tarjeta Nu", "Falabella", etc.)
            let keywords = accNameLower.components(separatedBy: " ").filter { $0.count >= 2 }
            let matchesKeyword = keywords.contains { kw in
                destLower.contains(kw) || lower.contains(kw)
            }
            
            if matchesKeyword || (acc.lastFour != nil && lower.contains("*\(acc.lastFour!)")) {
                destAccount = acc
                type = "transfer"
                break
            }
        }
        
        // Detección complementaria de palabras clave de pago
        if type != "transfer" {
            if lower.contains("pago tarjeta") || lower.contains("pago tc") || lower.contains("pago de tarjeta") || lower.contains("recibimos tu pago") {
                type = "transfer"
                // Asignar primera tarjeta de crédito si no se detectó por nombre
                destAccount = allAccounts.first(where: { $0.type == "Tarjeta de Crédito" && $0.id != sourceAccount?.id })
            } else if lower.contains("transferencia recibida") || lower.contains("abono") || lower.contains("consignacion") {
                type = "income"
            }
        }
        
        // 6. Categorización si resultó ser un Gasto normal
        var category = "Otros"
        if type == "expense" {
            let mLower = destinationRawName.lowercased()
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
        }
        
        // 7. Generar descripción
        let finalDesc: String
        if type == "transfer" {
            let srcName = sourceAccount?.name ?? "Banco"
            let dstName = destAccount?.name ?? "Tarjeta de Crédito"
            finalDesc = "Pago PSE: \(srcName) → \(dstName)"
        } else {
            finalDesc = "\(destinationRawName) [\(category)]"
        }
        
        do {
            try await SupabaseManager.shared.insertTransaction(
                amount: extractedAmount,
                type: type,
                description: finalDesc,
                date: Date(),
                sourceAccountId: sourceAccount?.id,
                destAccountId: destAccount?.id
            )
            
            if type == "transfer" {
                return .result(value: "✓ FinTrack: Pago propio detectado ($\(Int(extractedAmount))) de \(sourceAccount?.name ?? "") a \(destAccount?.name ?? "")")
            } else {
                return .result(value: "✓ FinTrack: Registrado $\(Int(extractedAmount)) en \(destinationRawName) (\(category))")
            }
        } catch {
            return .result(value: "⚠️ Error al guardar: \(error.localizedDescription)")
        }
    }
}

// MARK: - 3. Proveedor de Atajos de iOS
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
