import Foundation
import UIKit

struct Song: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var fileURL: URL
    var artworkData: Data?
    var genre: String?
    var year: String?
    var trackNumber: Int?
    var metadataFetched: Bool = false

    var artwork: UIImage? {
        guard let data = artworkData else { return nil }
        return UIImage(data: data)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }
}
