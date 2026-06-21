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

struct YTMusicResult: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnail: String?
    let duration: Int
}

struct YTSearchItem: Codable {
    let type: String
    let title: String
    let url: String?
    let uploaderName: String?
    let thumbnail: String?
    let duration: Int?
}

struct YTSearchResponse: Codable {
    let items: [YTSearchItem]?
}

struct YTAudioStream: Codable {
    let url: String?
    let format: String?
    let bitrate: Int?
}

struct YTStreamResponse: Codable {
    let audioStreams: [YTAudioStream]?
}

class MetadataService {
    static let shared = MetadataService()
    private let session: URLSession = {
        var config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "MatteosMusicApp/1.0 ( costimateo2023@netizen.com )"]
        return URLSession(configuration: config)
    }()

    private let pipedBase = "https://pipedapi.kavin.rocks"

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

    func searchYouTube(query: String) async -> [YTMusicResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        guard let url = URL(string: "\(pipedBase)/search?q=\(encoded)&filter=videos") else { return [] }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(YTSearchResponse.self, from: data)
            return response.items?.compactMap { item in
                guard item.type == "video",
                      let url = item.url,
                      let vid = url.components(separatedBy: "?v=").last?.components(separatedBy: "&").first
                else { return nil }
                return YTMusicResult(
                    id: vid,
                    title: item.title,
                    artist: item.uploaderName ?? "Unbekannt",
                    thumbnail: item.thumbnail,
                    duration: item.duration ?? 0
                )
            } ?? []
        } catch {
            return []
        }
    }

    func getAudioStreamURL(videoId: String) async -> String? {
        guard let url = URL(string: "\(pipedBase)/streams/\(videoId)") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(YTStreamResponse.self, from: data)
            return response.audioStreams?
                .sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }
                .first?.url
        } catch {
            return nil
        }
    }

    func downloadAudio(from url: String) async -> Data? {
        guard let url = URL(string: url) else { return nil }
        return try? await URLSession.shared.data(from: url).0
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
