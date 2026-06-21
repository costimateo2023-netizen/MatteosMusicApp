import Foundation
import AVFoundation
import UIKit

struct iTunesResult: Codable {
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let primaryGenreName: String?
    let releaseDate: String?
    let trackNumber: Int?
}

struct iTunesResponse: Codable {
    let resultCount: Int
    let results: [iTunesResult]
}

class MetadataService {
    static let shared = MetadataService()

    // Read embedded metadata from local file (offline)
    func readLocalMetadata(from url: URL) -> (title: String, artist: String, album: String, duration: TimeInterval, artworkData: Data?) {
        let asset = AVAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unbekannter Künstler"
        var album = "Unbekanntes Album"
        var artworkData: Data? = nil

        let metadata = asset.commonMetadata
        for item in metadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if let val = item.stringValue, !val.isEmpty { title = val }
            case .commonKeyArtist:
                if let val = item.stringValue, !val.isEmpty { artist = val }
            case .commonKeyAlbumName:
                if let val = item.stringValue, !val.isEmpty { album = val }
            case .commonKeyArtwork:
                if let data = item.dataValue { artworkData = data }
            default:
                break
            }
        }

        let duration = CMTimeGetSeconds(asset.duration)
        return (title, artist, album, duration, artworkData)
    }

    // Fetch extended metadata from iTunes Search API (requires internet)
    func fetchOnlineMetadata(title: String, artist: String) async -> iTunesResult? {
        let query = "\(title) \(artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&limit=5"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
            return response.results.first
        } catch {
            print("iTunes metadata error: \(error)")
            return nil
        }
    }

    // Download artwork from URL
    func downloadArtwork(from urlString: String) async -> Data? {
        let highRes = urlString.replacingOccurrences(of: "100x100", with: "600x600")
        guard let url = URL(string: highRes) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }

    // Full online enrichment
    func enrichSong(_ song: inout Song) async {
        guard !song.metadataFetched else { return }
        guard let result = await fetchOnlineMetadata(title: song.title, artist: song.artist) else { return }

        if let t = result.trackName { song.title = t }
        if let a = result.artistName { song.artist = a }
        if let al = result.collectionName { song.album = al }
        if let g = result.primaryGenreName { song.genre = g }
        if let d = result.releaseDate { song.year = String(d.prefix(4)) }
        if let tn = result.trackNumber { song.trackNumber = tn }

        if song.artworkData == nil, let artUrl = result.artworkUrl100 {
            song.artworkData = await downloadArtwork(from: artUrl)
        }
        song.metadataFetched = true
    }
}
