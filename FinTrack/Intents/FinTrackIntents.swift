import Foundation
import AppIntents

// MARK: - 1. Atajo Estructurado: Registrar Transacción Manual o por Bloques
@available(iOS 16.0, *)
struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Transacción en FinTrack"
    static var description = IntentDescription("Registra un gasto, ingreso o pago en tu cuenta de FinTrack.")
    
    @Parameter(title: "Monto", description: "El valor del movimiento")
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
                sourceAccountId = accounts.first(where: { $0.lastFour == lf || $0.lastFourDebit == lf })?.id
            }
            if let dlf = destLastFour?.filter({ "0123456789".contains($0) }), !dlf.isEmpty {
                destAccountId = accounts.first(where: { $0.lastFour == dlf || $0.lastFourDebit == dlf })?.id
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

// MARK: - 2. Atajo Mágico Inteligente: Procesar SMS Bancario con Calibración Quirúrgica y Alias
@available(iOS 16.0, *)
struct ParseBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Procesar SMS Bancario en FinTrack"
    static var description = IntentDescription("Lee el SMS, extrae el monto exacto, identifica compras, transferencias de/a personas con nombre propio y pagos propios.")
    
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
        
        // 1. EXTRAER MONTO CON PRECISIÓN MATEMÁTICA
        var extractedAmount: Double = 0.0
        if let match = text.range(of: #"\$\s?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+)"#, options: .regularExpression) {
            var raw = String(text[match]).replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
            
            if raw.contains(".") && raw.contains(",") {
                if let dotIdx = raw.firstIndex(of: "."), let commaIdx = raw.firstIndex(of: ",") {
                    if commaIdx < dotIdx {
                        // Formato US / Bre-B: 30,000.00 -> coma miles, punto decimales
                        raw = raw.replacingOccurrences(of: ",", with: "")
                    } else {
                        // Formato Col tradicional: 50.000,00 -> punto miles, coma decimales
                        raw = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                    }
                }
            } else if raw.contains(",") {
                let parts = raw.split(separator: ",")
                if parts.count > 1 && parts.last?.count == 3 {
                    raw = raw.replacingOccurrences(of: ",", with: "")
                } else {
                    raw = raw.replacingOccurrences(of: ",", with: ".")
                }
            } else if raw.contains(".") {
                let parts = raw.split(separator: ".")
                if parts.count > 1 && parts.last?.count == 3 {
                    raw = raw.replacingOccurrences(of: ".", with: "")
                }
            }
            extractedAmount = Double(raw) ?? 0.0
        }
        
        guard extractedAmount > 0 else {
            return .result(value: "⚠️ No se detectó un monto en el SMS: '\(text.prefix(30))...'")
        }
        
        // 2. EXTRAER DÍGITOS ORIGEN (Cuenta *2667 o T.Deb **2131)
        var sourceDigits: String? = nil
        if let debMatch = text.range(of: #"T\.Deb\s*\*+([0-9]{4})"#, options: [.regularExpression, .caseInsensitive]) {
            sourceDigits = String(text[debMatch]).filter { "0123456789".contains($0) }
        } else if let ctaMatch = text.range(of: #"cuenta\s*\*+([0-9]{4})"#, options: [.regularExpression, .caseInsensitive]) {
            sourceDigits = String(text[ctaMatch]).filter { "0123456789".contains($0) }
        } else if let genericMatch = text.range(of: #"\*([0-9]{4})"#, options: .regularExpression) {
            sourceDigits = String(text[genericMatch]).filter { "0123456789".contains($0) }
        }
        
        // 3. CARGAR CUENTAS Y ALIAS EN PARALELO
        async let fetchedAccounts = SupabaseManager.shared.fetchAccounts()
        async let fetchedAliases = SupabaseManager.shared.fetchAccountAliases()
        
        let allAccounts = (try? await fetchedAccounts) ?? []
        let allAliases = (try? await fetchedAliases) ?? []
        
        // Vincular cuenta origen (por cuenta bancaria o por tarjeta débito)
        var sourceAccount: Account? = nil
        if let digits = sourceDigits {
            sourceAccount = allAccounts.first(where: { $0.lastFour == digits || $0.lastFourDebit == digits })
        }
        if sourceAccount == nil {
            sourceAccount = allAccounts.first(where: { $0.type == "Banco" }) ?? allAccounts.first
        }
        
        // 4. PARSEO QUIRÚRGICO DE PATRONES BANCOLOMBIA
        var type = "expense"
        var title = "Movimiento Bancario"
        var category = "Otros"
        var destAccount: Account? = nil
        
        // PATRÓN 1: Transferencia Recibida por Llaves / Bre-B
        if lower.contains("recibiste una transferencia de") {
            type = "income"
            category = "Otros"
            if let range = text.range(of: #"recibiste una transferencia de ([A-Za-z\s]+?) por \$"#, options: [.regularExpression, .caseInsensitive]) {
                let rawName = String(text[range])
                    .replacingOccurrences(of: "recibiste una transferencia de ", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " por $", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                title = "Transferencia de \(rawName.capitalized)"
            } else {
                title = "Transferencia Recibida"
            }
        }
        // PATRÓN 2: Transferencia Recibida Tradicional
        else if lower.contains("recibiste una transferencia por") {
            type = "income"
            category = "Otros"
            if let range = text.range(of: #"de ([A-Za-z\s]+?) en tu cuenta"#, options: [.regularExpression, .caseInsensitive]) {
                let rawName = String(text[range])
                    .replacingOccurrences(of: "de ", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: " en tu cuenta", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
                title = "Transferencia de \(rawName.capitalized)"
            } else {
                title = "Transferencia Recibida"
            }
        }
        // PATRÓN 3: Retiro en Cajero
        else if lower.contains("retiraste") {
            type = "expense"
            category = "Otros"
            if let range = text.range(of: #"retiraste \S+ en ([A-Za-z0-9_\-]+) de"#, options: [.regularExpression, .caseInsensitive]) {
                let rawLoc = String(text[range])
                    .components(separatedBy: " en ").last?
                    .components(separatedBy: " de").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                title = "Retiro en \(rawLoc)"
            } else {
                title = "Retiro en Cajero"
            }
        }
        // PATRÓN 4: Pago con Código QR / Llave
        else if lower.contains("codigo qr") {
            type = "expense"
            category = "Compras"
            if let range = text.range(of: #"a la llave ([@A-Za-z0-9_\-]+)"#, options: [.regularExpression, .caseInsensitive]) {
                let rawKey = String(text[range]).replacingOccurrences(of: "a la llave ", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                title = "Pago QR a \(rawKey)"
            } else {
                title = "Pago con Código QR"
            }
        }
        // PATRÓN 5: Transferencia Enviada por Bre-B (Transfiya / Llaves)
        else if lower.contains("transferiste") && lower.contains("a la llave") {
            var key = ""
            var personName = ""
            if let keyRange = text.range(of: #"a la llave ([@A-Za-z0-9_\-]+)"#, options: [.regularExpression, .caseInsensitive]) {
                key = String(text[keyRange]).replacingOccurrences(of: "a la llave ", with: "").trimmingCharacters(in: .whitespaces)
            }
            if let nameRange = text.range(of: #"cuenta \*+[0-9]+ a ([A-Za-z\s]+?) el"#, options: [.regularExpression, .caseInsensitive]) {
                personName = String(text[nameRange]).components(separatedBy: " a ").last?.components(separatedBy: " el").first?.trimmingCharacters(in: .whitespaces).capitalized ?? ""
            }
            
            // Verificar si es cuenta propia
            for acc in allAccounts where acc.id != sourceAccount?.id {
                let accName = acc.name.lowercased()
                if (!personName.isEmpty && accName.contains(personName.lowercased())) || (!key.isEmpty && accName.contains(key.lowercased())) {
                    destAccount = acc
                    type = "transfer"
                    break
                }
            }
            
            if type != "transfer" {
                type = "expense"
                category = "Otros"
                if !personName.isEmpty && !key.isEmpty {
                    title = "Transferencia a \(personName) (\(key))"
                } else if !personName.isEmpty {
                    title = "Transferencia a \(personName)"
                } else {
                    title = "Transferencia a \(key)"
                }
            } else {
                title = "Transferencia propia: \(sourceAccount?.name ?? "Banco") → \(destAccount?.name ?? "")"
            }
        }
        // PATRÓN 6: Transferencia Enviada Tradicional a Cuenta
        else if lower.contains("transferiste") && lower.contains("a la cuenta") {
            var destDigits = ""
            if let range = text.range(of: #"a la cuenta \*+([0-9]+)"#, options: [.regularExpression, .caseInsensitive]) {
                destDigits = String(text[range]).filter { "0123456789".contains($0) }
            }
            
            // 1. ¿Es una cuenta propia registrada en FinTrack?
            for acc in allAccounts where acc.id != sourceAccount?.id {
                if let lf = acc.lastFour, !lf.isEmpty, (destDigits.hasSuffix(lf) || lf == destDigits) {
                    destAccount = acc
                    type = "transfer"
                    break
                }
                if let lfd = acc.lastFourDebit, !lfd.isEmpty, (destDigits.hasSuffix(lfd) || lfd == destDigits) {
                    destAccount = acc
                    type = "transfer"
                    break
                }
            }
            
            // 2. Si no es propia, buscar en Directorio de Contactos Frecuentes (Alias)
            if type != "transfer" {
                type = "expense"
                category = "Otros"
                
                var matchedAliasName: String? = nil
                for alias in allAliases {
                    let cleanAliasNumber = alias.accountNumberOrLast4.filter { "0123456789".contains($0) }
                    if !cleanAliasNumber.isEmpty && (destDigits == cleanAliasNumber || destDigits.hasSuffix(cleanAliasNumber)) {
                        matchedAliasName = alias.contactName
                        break
                    }
                }
                
                if let contact = matchedAliasName {
                    title = "Transferencia a \(contact)"
                } else if !destDigits.isEmpty {
                    title = "Transferencia a cta \(destDigits)"
                } else {
                    title = "Transferencia Bancaria"
                }
            } else {
                title = "Transferencia propia: \(sourceAccount?.name ?? "Banco") → \(destAccount?.name ?? "")"
            }
        }
        // PATRÓN 7: Pagos de Tarjeta / PSE a Terceros o Cuentas Propias
        else if lower.contains("pago tarjeta") || lower.contains("pago tc") || lower.contains("recibimos tu pago") {
            type = "transfer"
            destAccount = allAccounts.first(where: { $0.type == "Tarjeta de Crédito" && $0.id != sourceAccount?.id })
            title = "Pago de Tarjeta de Crédito"
        }
        // PATRÓN 8: Compra en Comercio (Datáfono o Online)
        else {
            type = "expense"
            var rawMerchant = "Compra"
            if let aRange = text.range(of: #"(?: a | en | pse a | pse en )([A-Za-z0-9\s]+?)(?: desde| con| por| el|\.|$)"#, options: [.regularExpression, .caseInsensitive]) {
                var matchStr = String(text[aRange])
                matchStr = matchStr.replacingOccurrences(of: " a ", with: "", options: .caseInsensitive)
                matchStr = matchStr.replacingOccurrences(of: " en ", with: "", options: .caseInsensitive)
                matchStr = matchStr.replacingOccurrences(of: "pse ", with: "", options: .caseInsensitive)
                rawMerchant = matchStr.trimmingCharacters(in: .whitespaces).capitalized
            }
            title = rawMerchant
            
            let mLower = rawMerchant.lowercased()
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
        
        // 5. REGISTRAR TRANSACCIÓN EN SUPABASE
        let finalDescription = type == "transfer" ? title : "\(title) [\(category)]"
        
        do {
            try await SupabaseManager.shared.insertTransaction(
                amount: extractedAmount,
                type: type,
                description: finalDescription,
                date: Date(),
                sourceAccountId: sourceAccount?.id,
                destAccountId: destAccount?.id
            )
            
            if type == "transfer" {
                return .result(value: "✓ FinTrack: Transferencia interna detectada ($\(Int(extractedAmount))) de \(sourceAccount?.name ?? "") a \(destAccount?.name ?? "")")
            } else if type == "income" {
                return .result(value: "✓ FinTrack: Ingreso registrado ($\(Int(extractedAmount))) de \(title)")
            } else {
                return .result(value: "✓ FinTrack: Gasto registrado ($\(Int(extractedAmount))) en \(title)")
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
