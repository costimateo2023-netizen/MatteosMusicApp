import Foundation
import Combine
import AVFoundation

class LibraryViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []
    @Published var isImporting: Bool = false
    @Published var isFetchingMetadata: Bool = false
    @Published var searchText: String = ""

    private let persistence = PersistenceService.shared
    private let metadata = MetadataService.shared

    var filteredSongs: [Song] {
        if searchText.isEmpty { return songs }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText) ||
            $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    init() {
        songs = persistence.loadSongs()
        playlists = persistence.loadPlaylists()
    }

    func importSong(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let localURL = try persistence.copyFileToMusicDirectory(from: url)
            let (title, artist, album, duration, artworkData) = metadata.readLocalMetadata(from: localURL)
            let song = Song(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                fileURL: localURL,
                artworkData: artworkData
            )
            DispatchQueue.main.async {
                self.songs.append(song)
                self.persistence.saveSongs(self.songs)
            }
        } catch {
            print("Import error: \(error)")
        }
    }

    func fetchMetadataOnline(for song: Song) async {
        guard let s = songs.first(where: { $0.id == song.id }) else { return }
        var songToUpdate = s
        await metadata.enrichSong(&songToUpdate)
        let updatedSong = songToUpdate
        DispatchQueue.main.async {
            if let idx = self.songs.firstIndex(where: { $0.id == song.id }) {
                self.songs[idx] = updatedSong
                self.persistence.saveSongs(self.songs)
            }
        }
    }

    func fetchAllMetadata() async {
        DispatchQueue.main.async { self.isFetchingMetadata = true }
        for song in songs where !song.metadataFetched {
            await fetchMetadataOnline(for: song)
        }
        DispatchQueue.main.async { self.isFetchingMetadata = false }
    }

    func deleteSong(_ song: Song) {
        persistence.deleteSong(song)
        songs.removeAll { $0.id == song.id }
        // Remove from playlists
        for i in playlists.indices {
            playlists[i].songIDs.removeAll { $0 == song.id }
        }
        persistence.saveSongs(songs)
        persistence.savePlaylists(playlists)
    }

    func createPlaylist(name: String) {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        persistence.savePlaylists(playlists)
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        persistence.savePlaylists(playlists)
    }

    func addSong(_ song: Song, to playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        if !playlists[idx].songIDs.contains(song.id) {
            playlists[idx].songIDs.append(song.id)
            persistence.savePlaylists(playlists)
        }
    }

    func removeSong(_ song: Song, from playlist: Playlist) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[idx].songIDs.removeAll { $0 == song.id }
        persistence.savePlaylists(playlists)
    }

    func songs(for playlist: Playlist) -> [Song] {
        playlist.songIDs.compactMap { id in songs.first { $0.id == id } }
    }
}
