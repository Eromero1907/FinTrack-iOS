import Foundation

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let projectURL = "https://whsexqrhrbiusjxmwpzl.supabase.co"
    let apiKey = "sb_publishable_mKaoQeJ2NUswUx0oqHlHhQ_issRQgFX"
    
    var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "supabase_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "supabase_access_token") }
    }
    
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "supabase_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "supabase_refresh_token") }
    }
    
    var currentUserId: String? {
        get { UserDefaults.standard.string(forKey: "supabase_user_id") }
        set { UserDefaults.standard.set(newValue, forKey: "supabase_user_id") }
    }
    
    var currentUser: SupabaseUser?
    
    private var isRefreshing = false
    
    private init() {}
    
    func signIn(email: String, password: String) async throws {
        guard let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=password") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        request.httpBody = try? JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        self.currentUser = authResponse.user
        self.currentUserId = authResponse.user.id
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws {
        guard let url = URL(string: "\(projectURL)/auth/v1/signup") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email, "password": password, "data": ["first_name": firstName, "last_name": lastName]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.accessToken = authResponse.accessToken
        self.refreshToken = authResponse.refreshToken
        self.currentUser = authResponse.user
        self.currentUserId = authResponse.user.id
    }
    
    func signOut() {
        self.accessToken = nil
        self.refreshToken = nil
        self.currentUser = nil
        self.currentUserId = nil
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
    }
    
    private func refreshSessionToken() async -> Bool {
        guard !isRefreshing else { return false }
        guard let currentRefresh = refreshToken else { return false }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        guard let url = URL(string: "\(projectURL)/auth/v1/token?grant_type=refresh_token") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": currentRefresh]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.accessToken = authResponse.accessToken
            self.refreshToken = authResponse.refreshToken
            return true
        } catch {
            return false
        }
    }
    
    private func makeAuthRequest(path: String, method: String = "GET", body: Data? = nil, isRetry: Bool = false) async throws -> Data {
        guard let url = URL(string: "\(projectURL)/rest/v1/\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if method == "POST" || method == "PATCH" {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 && !isRetry {
            print("Token expirado (401). Intentando renovar sesión automáticamente...")
            let success = await refreshSessionToken()
            if success {
                print("Sesión renovada con éxito. Reintentando la petición original...")
                return try await makeAuthRequest(path: path, method: method, body: body, isRetry: true)
            } else {
                print("No se pudo renovar la sesión. Expulsando usuario.")
                signOut()
                throw URLError(.userAuthenticationRequired)
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Error"
            print("API Error (\(method) \(path)): \(httpResponse.statusCode) - \(errorMsg)")
            throw URLError(.badServerResponse)
        }
        return data
    }
    
    // MARK: - Transactions
    func fetchTransactions() async throws -> [Transaction] {
        let data = try await makeAuthRequest(path: "transactions?select=*&order=date.desc")
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = formatter.date(from: dateString) { return date }
            return Date()
        }
        return try decoder.decode([Transaction].self, from: data)
    }
    
    func insertTransaction(amount: Double, type: String, description: String, date: Date, sourceAccountId: UUID? = nil) async throws {
        guard let userId = currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        var body: [String: Any] = [
            "user_id": userId,
            "amount": amount,
            "type": type,
            "description": description,
            "date": ISO8601DateFormatter().string(from: date)
        ]
        
        if let sourceAccountId = sourceAccountId {
            body["source_account_id"] = sourceAccountId.uuidString
        }
        
        let data = try JSONSerialization.data(withJSONObject: body)
        _ = try await makeAuthRequest(path: "transactions", method: "POST", body: data)
    }
    
    func deleteTransaction(id: UUID) async throws {
        let path = "transactions?id=eq.\(id.uuidString)"
        _ = try await makeAuthRequest(path: path, method: "DELETE")
    }
    
    // MARK: - Accounts
    func fetchAccounts() async throws -> [Account] {
        let data = try await makeAuthRequest(path: "accounts?select=*")
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = formatter.date(from: dateString) { return date }
            return Date()
        }
        return try decoder.decode([Account].self, from: data)
    }
    
    func insertAccount(name: String, type: String, currency: String, balance: Double) async throws -> Account {
        guard let userId = currentUserId else { throw URLError(.userAuthenticationRequired) }
        
        let body: [String: Any] = [
            "user_id": userId,
            "name": name,
            "type": type,
            "currency": currency,
            "current_balance": balance
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let responseData = try await makeAuthRequest(path: "accounts", method: "POST", body: data)
        
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatter.date(from: dateString) { return date }
            return Date()
        }
        
        let accounts = try decoder.decode([Account].self, from: responseData)
        guard let newAccount = accounts.first else { throw URLError(.cannotParseResponse) }
        return newAccount
    }
    
    func deleteAccount(id: UUID, name: String) async throws {
        if let encodedDesc = "Saldo inicial - \(name)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let txPath = "transactions?description=eq.\(encodedDesc)"
            _ = try? await makeAuthRequest(path: txPath, method: "DELETE")
        }
        
        let path = "accounts?id=eq.\(id.uuidString)"
        _ = try await makeAuthRequest(path: path, method: "DELETE")
    }
}
