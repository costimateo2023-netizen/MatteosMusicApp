import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                if libraryVM.playlists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.msAccent.opacity(0.4))
                        Text("Keine Playlists")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Erstelle deine erste Playlist")
                            .foregroundColor(.msSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(libraryVM.playlists) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    PlaylistRowView(playlist: playlist)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        libraryVM.deletePlaylist(playlist)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.msAccent)
                        .font(.title2)
                }
            }
            .alert("Neue Playlist", isPresented: $showCreate) {
                TextField("Name", text: $newName)
                Button("Erstellen") {
                    if !newName.isEmpty {
                        libraryVM.createPlaylist(name: newName)
                        newName = ""
                    }
                }
                Button("Abbrechen", role: .cancel) { newName = "" }
            }
        }
    }
}

struct PlaylistRowView: View {
    let playlist: Playlist
    @EnvironmentObject var libraryVM: LibraryViewModel

    var songs: [Song] { libraryVM.songs(for: playlist) }
    var artworkSong: Song? { songs.first(where: { $0.artwork != nil }) }

    var body: some View {
        HStack(spacing: 14) {
            // Artwork grid or icon
            if let art = artworkSong?.artwork {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .cornerRadius(10)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.msCard)
                        .frame(width: 64, height: 64)
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundColor(.msAccent.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text("\(playlist.songCount) Songs")
                        .font(.caption)
                        .foregroundColor(.msSecondary)
                    if playlist.isNonstop {
                        Label("Nonstop", systemImage: "infinity")
                            .font(.caption)
                            .foregroundColor(.msAccent)
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.msSecondary)
                .font(.caption)
        }
        .padding(12)
        .background(Color.msCard)
        .cornerRadius(12)
    }
}
