import Foundation

struct Playlist: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var songIDs: [UUID] = []
    var createdAt: Date = Date()
    var isNonstop: Bool = true

    var songCount: Int { songIDs.count }
}
