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

struct OnlineMusicResult: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnail: String?
    let duration: Int
}

struct PipedSearchItem: Codable {
    let url: String?
    let type: String?
    let title: String?
    let thumbnail: String?
    let uploaderName: String?
    let duration: Int?
}

struct PipedSearchResponse: Codable {
    let items: [PipedSearchItem]?
}

struct PipedAudioStream: Codable {
    let url: String?
    let format: String?
    let bitrate: Int?
}

struct PipedStreamResponse: Codable {
    let audioStreams: [PipedAudioStream]?
    let error: String?
}

struct YTPlayerFormat: Codable {
    let itag: Int?
    let url: String?
    let mimeType: String?
    let bitrate: Int?
}

struct YTStreamingData: Codable {
    let formats: [YTPlayerFormat]?
    let adaptiveFormats: [YTPlayerFormat]?
}

struct YTPlayerResponse: Codable {
    let streamingData: YTStreamingData?
}

class MetadataService {
    static let shared = MetadataService()
    private let session: URLSession = {
        var config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "MatteosMusicApp/1.0 ( costimateo2023@netizen.com )"]
        return URLSession(configuration: config)
    }()

    private let pipedInstances = [
        "https://api.piped.private.coffee",
        "https://pipedapi.kavin.rocks",
        "https://pipedapi-libre.kavin.rocks"
    ]

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

    private func searchPiped(instance: String, query: String) async -> [OnlineMusicResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        guard let url = URL(string: "\(instance)/search?q=\(encoded)&filter=music_songs") else { return [] }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(PipedSearchResponse.self, from: data)
            return response.items?.compactMap { item in
                guard let url = item.url,
                      let vid = url.components(separatedBy: "?v=").last?.components(separatedBy: "&").first
                else { return nil }
                let thumb = item.thumbnail?
                    .replacingOccurrences(of: "=w120-h120", with: "=w600-h600")
                return OnlineMusicResult(
                    id: vid,
                    title: item.title ?? "Unbekannt",
                    artist: item.uploaderName ?? "Unbekannt",
                    thumbnail: thumb,
                    duration: item.duration ?? 0
                )
            } ?? []
        } catch {
            return []
        }
    }

    private func streamPiped(instance: String, videoId: String) async -> String? {
        guard let url = URL(string: "\(instance)/streams/\(videoId)") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(PipedStreamResponse.self, from: data)
            if response.error != nil { return nil }
            return response.audioStreams?
                .sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }
                .first?.url
        } catch {
            return nil
        }
    }

    private func streamYouTubeDirect(videoId: String) async -> String? {
        let browserUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(browserUA, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) else { return nil }

        guard let markerRange = html.range(of: "ytInitialPlayerResponse") else { return nil }
        let afterMarker = html[markerRange.upperBound...]
        guard let bracePos = afterMarker.firstIndex(of: "{"),
              let jsonEnd = findMatchingBrace(from: afterMarker[bracePos...]) else { return nil }
        let fullRange = bracePos..<jsonEnd
        let jsonText = String(html[fullRange])
        guard let jsonData = jsonText.data(using: .utf8),
              let response = try? JSONDecoder().decode(YTPlayerResponse.self, from: jsonData),
              let formats = response.streamingData?.adaptiveFormats ?? response.streamingData?.formats else { return nil }
        let audioFormats = formats.filter { $0.mimeType?.contains("audio") ?? false }
        return audioFormats
            .sorted { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }
            .first?.url
    }

    private func findMatchingBrace(from substring: Substring) -> String.Index? {
        var depth = 0
        for (i, c) in substring.enumerated() {
            if c == "{" { depth += 1 }
            else if c == "}" { depth -= 1 }
            if depth == 0 { return substring.index(substring.startIndex, offsetBy: i + 1) }
        }
        return nil
    }

    func searchOnline(query: String) async -> [OnlineMusicResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        for instance in pipedInstances {
            let results = await searchPiped(instance: instance, query: query)
            if !results.isEmpty { return results }
        }
        return []
    }

    func getAudioStreamURL(videoId: String) async -> String? {
        for instance in pipedInstances {
            if let url = await streamPiped(instance: instance, videoId: videoId) {
                return url
            }
        }
        return await streamYouTubeDirect(videoId: videoId)
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
