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

struct SCTrack: Codable {
    let id: Int
    let title: String
    let user: SCUser?
    let artworkUrl: String?
    let duration: Int?
    let permalinkUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, user, duration
        case artworkUrl = "artwork_url"
        case permalinkUrl = "permalink_url"
    }
}

struct SCUser: Codable {
    let username: String?
}

struct SCSearchResponse: Codable {
    let collection: [SCTrack]?
}

struct SCStreamData: Codable {
    let httpMp3Url: String?
    let hlsMp3Url: String?

    enum CodingKeys: String, CodingKey {
        case httpMp3Url = "http_mp3_128_url"
        case hlsMp3Url = "hls_mp3_128_url"
    }
}

class MetadataService {
    static let shared = MetadataService()
    private let session: URLSession = {
        var config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "MatteosMusicApp/1.0 ( costimateo2023@netizen.com )"]
        return URLSession(configuration: config)
    }()

    private let scBase = "https://api-v2.soundcloud.com"
    private var scClientID: String?
    private let fallbackClientIDs = [
        "a3e059563d7fd3372b49b37f00a00bcf",
        "iZIs9mchVcX5lhVRyQGGAYlNPVldzAoX",
        "2t9loNQH90kzJcsFCODdigxfp325aq4z"
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

    private func ensureClientID() async -> String? {
        if let existing = scClientID { return existing }
        for fallback in fallbackClientIDs {
            if await verifyClientID(fallback) {
                scClientID = fallback
                return fallback
            }
        }
        guard let htmlURL = URL(string: "https://soundcloud.com/"),
              let (data, _) = try? await URLSession.shared.data(from: htmlURL),
              let html = String(data: data, encoding: .utf8) else { return nil }
        let patterns = [
            "client_id\":\"",
            "client_id="
        ]
        for pattern in patterns {
            if let range = html.range(of: pattern) {
                let start = range.upperBound
                if let end = html[start...].firstIndex(of: "\"") ?? html[start...].firstIndex(of: "&") {
                    let cid = String(html[start..<end])
                    if !cid.isEmpty && cid.count < 64 {
                        await verifyClientID(cid)
                        scClientID = cid
                        return cid
                    }
                }
            }
        }
        return nil
    }

    private func verifyClientID(_ cid: String) async -> Bool {
        guard let url = URL(string: "\(scBase)/search/tracks?q=test&client_id=\(cid)&limit=1") else { return false }
        do {
            let (data, _) = try await session.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["collection"] != nil {
                return true
            }
            return false
        } catch {
            return false
        }
    }

    func searchSoundCloud(query: String) async -> [OnlineMusicResult] {
        guard let cid = await ensureClientID() else { return [] }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        guard let url = URL(string: "\(scBase)/search/tracks?q=\(encoded)&client_id=\(cid)&limit=20&app_locale=en") else { return [] }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(SCSearchResponse.self, from: data)
            return response.collection?.compactMap { track in
                let art = track.artworkUrl?
                    .replacingOccurrences(of: "-large.", with: "-t500x500.")
                return OnlineMusicResult(
                    id: "\(track.id)",
                    title: track.title,
                    artist: track.user?.username ?? "Unbekannt",
                    thumbnail: art,
                    duration: (track.duration ?? 0) / 1000
                )
            } ?? []
        } catch {
            return []
        }
    }

    func getSoundCloudStreamURL(trackId: String) async -> String? {
        guard let cid = await ensureClientID() else { return nil }
        guard let url = URL(string: "\(scBase)/tracks/\(trackId)/streams?client_id=\(cid)") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(SCStreamData.self, from: data)
            return response.httpMp3Url ?? response.hlsMp3Url
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
