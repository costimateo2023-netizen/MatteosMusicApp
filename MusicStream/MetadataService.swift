import Foundation
import AVFoundation
import UIKit

struct MBArtistCredit: Codable {
    let name: String
}

struct MBRelease: Codable {
    let id: String
    let title: String?
    let date: String?
}

struct MBRecording: Codable {
    let id: String
    let title: String?
    let artistCredit: [MBArtistCredit]?
    let releases: [MBRelease]?

    enum CodingKeys: String, CodingKey {
        case id, title, releases
        case artistCredit = "artist-credit"
    }
}

struct MBResponse: Codable {
    let recordings: [MBRecording]?
}

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
    private let session: URLSession = {
        var config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "MatteosMusicApp/1.0 ( costimateo2023@netizen.com )"]
        return URLSession(configuration: config)
    }()

    var provider: String {
        UserDefaults.standard.string(forKey: "metadataProvider") ?? "musicbrainz"
    }

    func readLocalMetadata(from url: URL) -> (title: String, artist: String, album: String, duration: TimeInterval, artworkData: Data?) {
        let asset = AVAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unbekannter K\u{00FC}nstler"
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

    func enrichSong(_ song: inout Song) async {
        guard !song.metadataFetched else { return }
        if provider == "itunes" {
            await enrichViaITunes(&song)
        } else {
            await enrichViaMusicBrainz(&song)
        }
    }

    private func enrichViaMusicBrainz(_ song: inout Song) async {
        guard let result = await fetchMusicBrainz(title: song.title, artist: song.artist) else { return }
        if let t = result.title { song.title = t }
        if let artistCredit = result.artistCredit, let name = artistCredit.first?.name { song.artist = name }
        if let release = result.releases?.first {
            if let al = release.title { song.album = al }
            if let d = release.date { song.year = String(d.prefix(4)) }
            if song.artworkData == nil {
                song.artworkData = await downloadArtwork(from: release.id)
            }
        }
        song.metadataFetched = true
    }

    private func enrichViaITunes(_ song: inout Song) async {
        guard let result = await fetchITunes(title: song.title, artist: song.artist) else { return }
        if let t = result.trackName { song.title = t }
        if let a = result.artistName { song.artist = a }
        if let al = result.collectionName { song.album = al }
        if let g = result.primaryGenreName { song.genre = g }
        if let d = result.releaseDate { song.year = String(d.prefix(4)) }
        if let tn = result.trackNumber { song.trackNumber = tn }
        if song.artworkData == nil, let artUrl = result.artworkUrl100 {
            let highRes = artUrl.replacingOccurrences(of: "100x100", with: "600x600")
            guard let url = URL(string: highRes) else { return }
            song.artworkData = try? await URLSession.shared.data(from: url).0
        }
        song.metadataFetched = true
    }

    private func fetchMusicBrainz(title: String, artist: String) async -> MBRecording? {
        let queries = [
            "recording:\"\(title)\" AND artist:\"\(artist)\"",
            "recording:\"\(title)\""
        ]
        for query in queries {
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
            let urlString = "https://musicbrainz.org/ws/2/recording?query=\(encoded)&fmt=json&limit=3"
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await session.data(from: url)
                let response = try JSONDecoder().decode(MBResponse.self, from: data)
                if let recording = response.recordings?.first {
                    return recording
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func fetchITunes(title: String, artist: String) async -> iTunesResult? {
        let queries = [
            "\(title) \(artist)",
            title
        ]
        for query in queries {
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
            let urlString = "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=3"
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await session.data(from: url)
                let response = try JSONDecoder().decode(iTunesResponse.self, from: data)
                if let result = response.results.first {
                    return result
                }
            } catch {
                continue
            }
        }
        return nil
    }

    private func downloadArtwork(from releaseID: String) async -> Data? {
        let urls = [
            "https://coverartarchive.org/release/\(releaseID)/front",
            "https://coverartarchive.org/release/\(releaseID)/front-250"
        ]
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await session.data(from: url)
                if !data.isEmpty { return data }
            } catch {
                continue
            }
        }
        return nil
    }
}
