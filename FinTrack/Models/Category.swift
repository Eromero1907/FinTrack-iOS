import Foundation

struct Category: Identifiable, Codable {
    var id: UUID
    var userId: UUID
    var name: String
    var icon: String?
    var color: String?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case icon
        case color
        case createdAt = "created_at"
    }
}
