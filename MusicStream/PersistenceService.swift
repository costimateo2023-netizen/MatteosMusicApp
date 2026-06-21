import Foundation

class PersistenceService {
    static let shared = PersistenceService()

    private let songsKey = "saved_songs"
    private let playlistsKey = "saved_playlists"

    var musicDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let music = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: music, withIntermediateDirectories: true)
        return music
    }

    func saveSongs(_ songs: [Song]) {
        if let data = try? JSONEncoder().encode(songs) {
            UserDefaults.standard.set(data, forKey: songsKey)
        }
    }

    func loadSongs() -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: songsKey),
              let songs = try? JSONDecoder().decode([Song].self, from: data) else {
            return []
        }
        // Filter only songs whose file still exists
        return songs.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    func savePlaylists(_ playlists: [Playlist]) {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: playlistsKey)
        }
    }

    func loadPlaylists() -> [Playlist] {
        guard let data = UserDefaults.standard.data(forKey: playlistsKey),
              let playlists = try? JSONDecoder().decode([Playlist].self, from: data) else {
            return []
        }
        return playlists
    }

    func copyFileToMusicDirectory(from sourceURL: URL) throws -> URL {
        let filename = sourceURL.lastPathComponent
        let dest = musicDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }

    func deleteSong(_ song: Song) {
        try? FileManager.default.removeItem(at: song.fileURL)
    }
}
