import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct FinTrackTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinTrackEntry {
        FinTrackEntry(date: Date(), data: FinTrackWidgetData(
            totalBalance: 8450000.0,
            hasForeignCurrency: true,
            usdRate: 3128.0,
            accountsBalance: 11230000.0,
            creditCardsDebt: 2780000.0,
            cycleExpenses: 1200000.0,
            monthlyBudgetLimit: 2000000.0,
            daysRemaining: 7,
            isCustomCycle: true,
            cycleLabel: "24 Sep - 23 Oct",
            lastUpdated: Date()
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (FinTrackEntry) -> ()) {
        let data = WidgetDataManager.shared.loadWidgetData()
        let entry = FinTrackEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let data = WidgetDataManager.shared.loadWidgetData()
        let entry = FinTrackEntry(date: Date(), data: data)
        // Actualizar cada 15 minutos automáticamente
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct FinTrackEntry: TimelineEntry {
    let date: Date
    let data: FinTrackWidgetData
}

// MARK: - Formateador de moneda auxiliar para el Widget
extension Double {
    func widgetCurrencyFormatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_CO")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
    
    func widgetCompactFormatted() -> String {
        let absVal = abs(self)
        if absVal >= 1_000_000 {
            return String(format: "$%.1fM", self / 1_000_000)
        } else if absVal >= 1_000 {
            return String(format: "$%.0fk", self / 1_000)
        } else {
            return "$\(Int(self))"
        }
    }
}

// MARK: ==========================================
// MARK: 1. WIDGET DE BALANCE & PATRIMONIO NETO
// MARK: ==========================================
struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: FinTrackEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            smallView
        }
    }

    // Small Layout
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("FinTrack")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Balance Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(entry.data.totalBalance.widgetCurrencyFormatted())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            if entry.data.hasForeignCurrency {
                HStack(spacing: 3) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 8))
                    Text("USD: $\(Int(entry.data.usdRate))")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            } else {
                Text("Patrimonio Neto")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    // Medium Layout
    private var mediumView: some View {
        HStack(spacing: 16) {
            // Lado Izquierdo: Balance Total
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    Text("FinTrack")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Patrimonio Neto")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(entry.data.totalBalance.widgetCurrencyFormatted())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if entry.data.hasForeignCurrency {
                    Text("TRM: $\(Int(entry.data.usdRate)) COP/USD")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else {
                    Text("Actualizado")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Lado Derecho: Desglose Cuentas vs Tarjetas
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text("Disponibles")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(entry.data.accountsBalance.widgetCurrencyFormatted())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 7, height: 7)
                        Text("Deuda Tarjetas")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("-\(entry.data.creditCardsDebt.widgetCurrencyFormatted())")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    // Lock Screen Circular
    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "banknote")
                    .font(.system(size: 11))
                Text(entry.data.totalBalance.widgetCompactFormatted())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // Lock Screen Rectangular
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 10))
                Text("FinTrack · Balance")
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(entry.data.totalBalance.widgetCurrencyFormatted())
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(entry.data.hasForeignCurrency ? "TRM: $\(Int(entry.data.usdRate)) COP" : "Patrimonio neto")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

struct BalanceWidget: Widget {
    let kind: String = "FinTrackBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackTimelineProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Balance Total")
        .description("Visualiza tu patrimonio neto consolidado con cuentas y TRM.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: ==========================================
// MARK: 2. WIDGET DE SEMÁFORO DE PRESUPUESTO
// MARK: ==========================================
struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: FinTrackEntry

    var progress: Double {
        guard entry.data.monthlyBudgetLimit > 0 else { return 0.0 }
        return min(entry.data.cycleExpenses / entry.data.monthlyBudgetLimit, 1.0)
    }

    var trafficColor: Color {
        if progress < 0.70 {
            return .green
        } else if progress < 0.90 {
            return .yellow
        } else {
            return .red
        }
    }

    var remainingAmount: Double {
        max(entry.data.monthlyBudgetLimit - entry.data.cycleExpenses, 0)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallBudgetView
        case .systemMedium:
            mediumBudgetView
        case .accessoryCircular:
            lockCircularView
        case .accessoryRectangular:
            lockRectangularView
        default:
            smallBudgetView
        }
    }

    // Small Budget View
    private var smallBudgetView: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Presupuesto")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if entry.data.isCustomCycle {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.purple)
                }
            }

            Spacer()

            // Anillo dinámico de progreso
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(trafficColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(entry.data.cycleExpenses.widgetCompactFormatted()) / \(entry.data.monthlyBudgetLimit.widgetCompactFormatted())")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Corte en \(entry.data.daysRemaining)d")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(trafficColor)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    // Medium Budget View
    private var mediumBudgetView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(trafficColor).frame(width: 8, height: 8)
                    Text(entry.data.isCustomCycle ? "Ciclo Tarjeta de Crédito" : "Presupuesto Mensual")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Corte en \(entry.data.daysRemaining) días")
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(4)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gastado: \(entry.data.cycleExpenses.widgetCurrencyFormatted())")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Te quedan: \(remainingAmount.widgetCurrencyFormatted())")
                        .font(.caption)
                        .foregroundColor(trafficColor)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(trafficColor)
            }

            // Barra de progreso horizontal
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(trafficColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)

            // Botón de acción rápida con Deep Link
            HStack {
                Text(entry.data.cycleLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Link(destination: URL(string: "fintrack://add")!) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                        Text("Nuevo Gasto")
                    }
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    // Lock Screen Circular
    private var lockCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: progress) {
                Image(systemName: "chart.bar.fill")
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)
        }
    }

    // Lock Screen Rectangular
    private var lockRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Presupuesto")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .bold))
            }
            ProgressView(value: progress)
            Text("\(entry.data.cycleExpenses.widgetCompactFormatted()) de \(entry.data.monthlyBudgetLimit.widgetCompactFormatted()) · \(entry.data.daysRemaining)d")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

struct BudgetWidget: Widget {
    let kind: String = "FinTrackBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackTimelineProvider()) { entry in
            BudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Semáforo de Presupuesto")
        .description("Controla cuánto te queda para gastar en el mes o ciclo de tu tarjeta.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: ==========================================
// MARK: WIDGET BUNDLE
// MARK: ==========================================
@main
struct FinTrackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        BudgetWidget()
    }
}
