import SwiftUI

struct DashboardView: View {
    // Aquí conectaremos el ViewModel más adelante
    @State private var totalBalance: Double = 0.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Tarjeta de Balance Total
                VStack {
                    Text("Balance Total")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("$\(totalBalance, specifier: "%.2f")")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                // Espacio para la gráfica del mes
                VStack {
                    Text("Gastos de este mes")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Placeholder para la gráfica
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: 200)
                        .overlay(Text("Gráfica en construcción...").foregroundColor(.gray))
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Inicio")
            .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
