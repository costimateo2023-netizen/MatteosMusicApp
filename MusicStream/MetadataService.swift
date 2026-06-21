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
    let mimeType: String?
    let videoOnly: Bool?
    let itag: Int?
}

struct PipedStreamResponse: Codable {
    let audioStreams: [PipedAudioStream]?
    let videoStreams: [PipedAudioStream]?
    let error: String?
}

struct InnerTubeFormat: Codable {
    let url: String?
    let mimeType: String?
    let bitrate: Int?
    let audioQuality: String?
    let signatureCipher: String?
}

struct InnerTubeStreamingData: Codable {
    let adaptiveFormats: [InnerTubeFormat]?
    let formats: [InnerTubeFormat]?
}

struct InnerTubePlayabilityStatus: Codable {
    let status: String?
}

struct InnerTubeResponse: Codable {
    let streamingData: InnerTubeStreamingData?
    let playabilityStatus: InnerTubePlayabilityStatus?
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
            if let audioUrl = response.audioStreams?
                .sorted(by: { a, b in (a.bitrate ?? 0) > (b.bitrate ?? 0) })
                .first?.url {
                return audioUrl
            }
            return response.videoStreams?
                .filter { $0.videoOnly != true && $0.url?.hasPrefix("https") == true }
                .sorted(by: { a, b in (a.bitrate ?? 0) > (b.bitrate ?? 0) })
                .first?.url
        } catch {
            return nil
        }
    }

    private let y2mateBase = "https://de1.y2mate.gg"

    private func streamY2mate(videoId: String) async -> String? {
        let ytUrl = "https://www.youtube.com/watch?v=\(videoId)"
        guard let analyzeUrl = URL(string: "\(y2mateBase)/mates/analyzeV2/ajax") else { return nil }
        var req = URLRequest(url: analyzeUrl)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let body = "k_query=\(ytUrl)&k_page=home&hl=en&q_auto=False"
        guard let bodyData = body.data(using: .utf8) else { return nil }
        req.httpBody = bodyData
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vid = json["vid"] as? String,
              let links = json["links"] as? [String: Any],
              let mp3 = links["mp3"] as? [String: Any] else { return nil }
        let keys = mp3.compactMap { ($0.value as? [String: Any])?["k"] as? String }
        guard var key = keys.first else { return nil }
        let quals = mp3.compactMap { ($0.value as? [String: Any])?["q"] as? String }
        if let bestIdx = quals.firstIndex(of: "320"), keys.indices.contains(bestIdx) {
            key = keys[bestIdx]
        }
        guard let convertUrl = URL(string: "\(y2mateBase)/mates/convertV2/index") else { return nil }
        var req2 = URLRequest(url: convertUrl)
        req2.httpMethod = "POST"
        req2.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body2 = "vid=\(vid)&k=\(key)"
        req2.httpBody = body2.data(using: .utf8)
        guard let (data2, _) = try? await URLSession.shared.data(for: req2),
              let result = try? JSONSerialization.jsonObject(with: data2) as? [String: Any],
              let dlink = result["dlink"] as? String else { return nil }
        return dlink
    }

    private func streamInnerTube(videoId: String) async -> String? {
        let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
        let urlString = "https://www.youtube.com/youtubei/v1/player?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20220801.00.00"
                ]
            ],
            "videoId": videoId
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let response = try? JSONDecoder().decode(InnerTubeResponse.self, from: data),
              response.playabilityStatus?.status == "OK",
              let formats = response.streamingData?.adaptiveFormats else { return nil }
        let audioFormats = formats.filter { $0.mimeType?.contains("audio") ?? false }
        for f in audioFormats.sorted(by: { ($0.bitrate ?? 0) > ($1.bitrate ?? 0) }) {
            if let url = f.url { return url }
            if let cipher = f.signatureCipher {
                let params = cipher.split(separator: "&").reduce(into: [String: String]()) {
                    let kv = $1.split(separator: "=", maxSplits: 1).map(String.init)
                    $0[kv[0]] = kv.count > 1 ? kv[1].removingPercentEncoding ?? kv[1] : ""
                }
                if let urlParam = params["url"]?.removingPercentEncoding {
                    return urlParam
                }
            }
        }
        return nil
    }

    func searchOnline(query: String) async -> [OnlineMusicResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        for instance in pipedInstances {
            let results = await searchPiped(instance: instance, query: query)
            if !results.isEmpty { return results }
        }
        return []
    }

    func getAudioStreamURL(videoId: String) async -> String? {
        if let url = await streamY2mate(videoId: videoId) { return url }
        for instance in pipedInstances {
            if let url = await streamPiped(instance: instance, videoId: videoId) {
                return url
            }
        }
        return await streamInnerTube(videoId: videoId)
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
