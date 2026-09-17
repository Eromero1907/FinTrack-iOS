import Foundation
import WidgetKit

public struct FinTrackWidgetData: Codable {
    public var totalBalance: Double
    public var hasForeignCurrency: Bool
    public var usdRate: Double
    public var accountsBalance: Double
    public var creditCardsDebt: Double
    public var cycleExpenses: Double
    public var monthlyBudgetLimit: Double
    public var daysRemaining: Int
    public var isCustomCycle: Bool
    public var cycleLabel: String
    public var lastUpdated: Date
    
    public init(
        totalBalance: Double = 0.0,
        hasForeignCurrency: Bool = false,
        usdRate: Double = 4150.0,
        accountsBalance: Double = 0.0,
        creditCardsDebt: Double = 0.0,
        cycleExpenses: Double = 0.0,
        monthlyBudgetLimit: Double = 2000000.0,
        daysRemaining: Int = 30,
        isCustomCycle: Bool = false,
        cycleLabel: String = "Mes actual",
        lastUpdated: Date = Date()
    ) {
        self.totalBalance = totalBalance
        self.hasForeignCurrency = hasForeignCurrency
        self.usdRate = usdRate
        self.accountsBalance = accountsBalance
        self.creditCardsDebt = creditCardsDebt
        self.cycleExpenses = cycleExpenses
        self.monthlyBudgetLimit = monthlyBudgetLimit
        self.daysRemaining = daysRemaining
        self.isCustomCycle = isCustomCycle
        self.cycleLabel = cycleLabel
        self.lastUpdated = lastUpdated
    }
}

public class WidgetDataManager {
    public static let shared = WidgetDataManager()
    private let appGroupSuite = "group.com.romero.FinTrack"
    private let widgetDataKey = "fintrack_shared_widget_data"
    
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? UserDefaults.standard
    }
    
    public func saveWidgetData(_ data: FinTrackWidgetData) {
        if let encoded = try? JSONEncoder().encode(data) {
            sharedDefaults.set(encoded, forKey: widgetDataKey)
            UserDefaults.standard.set(encoded, forKey: widgetDataKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    public func loadWidgetData() -> FinTrackWidgetData {
        if let data = sharedDefaults.data(forKey: widgetDataKey),
           let decoded = try? JSONDecoder().decode(FinTrackWidgetData.self, from: data) {
            return decoded
        }
        if let data = UserDefaults.standard.data(forKey: widgetDataKey),
           let decoded = try? JSONDecoder().decode(FinTrackWidgetData.self, from: data) {
            return decoded
        }
        return FinTrackWidgetData()
    }
}
