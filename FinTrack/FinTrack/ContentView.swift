import SwiftUI

struct ContentView: View {
    // Al usar AppStorage, el iPhone recuerda esta variable incluso si cierras la app por completo
    @AppStorage("isAuthenticated") private var isAuthenticated = false
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    
    var body: some View {
        if !isAuthenticated {
            AuthView()
        } else {
            ZStack(alignment: .bottom) {
                TabView {
                    DashboardView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Inicio")
                        }
                    
                    HistoryView()
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle.portrait")
                            Text("Historial")
                        }
                    
                    Text("")
                        .tabItem {
                            Text("")
                        }
                    
                    BudgetsView()
                        .tabItem {
                            Image(systemName: "chart.bar.fill")
                            Text("Metas")
                        }
                    
                    WalletView()
                        .tabItem {
                            Image(systemName: "creditcard.fill")
                            Text("Billetera")
                        }
                }
                .accentColor(.blue)
                .environmentObject(dashboardViewModel)
                
                Button(action: {
                    showAddTransaction = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .offset(y: -10)
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(onSave: {
                    Task {
                        await dashboardViewModel.fetchTransactions()
                    }
                })
            }
            .task {
                await dashboardViewModel.fetchTransactions()
            }
            .onOpenURL { url in
                if url.scheme == "fintrack" && url.host == "add" {
                    showAddTransaction = true
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
