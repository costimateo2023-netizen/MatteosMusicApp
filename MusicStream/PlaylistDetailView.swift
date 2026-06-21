import SwiftUI
import PhotosUI

struct PlaylistDetailView: View {
    let playlist: Playlist
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var playerVM: MusicPlayerViewModel
    @State private var showAddSongs = false
    @State private var photoItem: PhotosPickerItem?

    var songs: [Song] { libraryVM.songs(for: playlist) }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    PlaylistHeaderView(playlist: playlist, songs: songs, photoItem: $photoItem)

                    // Play All Button
                    if !songs.isEmpty {
                        Button {
                            playerVM.play(song: songs[0], in: songs)
                        } label: {
                            Label("Alle abspielen", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.msAccent)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }

                    // Songs
                    ForEach(songs) { song in
                        SongRowView(song: song)
                            .onTapGesture {
                                playerVM.play(song: song, in: songs)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    libraryVM.removeSong(song, from: playlist)
                                } label: {
                                    Label("Aus Playlist entfernen", systemImage: "minus.circle")
                                }
                            }
                    }

                    if songs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(.msSecondary)
                            Text("Noch keine Songs")
                                .foregroundColor(.msSecondary)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button {
                showAddSongs = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.msAccent)
            }
        }
        .sheet(isPresented: $showAddSongs) {
            AddSongsView(playlist: playlist)
        }
        .onChange(of: photoItem) { newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                await MainActor.run {
                    libraryVM.updatePlaylistCover(playlist, imageData: data)
                }
            }
        }
    }
}

struct PlaylistHeaderView: View {
    let playlist: Playlist
    let songs: [Song]
    @Binding var photoItem: PhotosPickerItem?
    @EnvironmentObject var libraryVM: LibraryViewModel

    var artworkSong: Song? { songs.first(where: { $0.artwork != nil }) }

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let data = playlist.coverImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.4), radius: 20)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.msAccent)
                                .background(Color.black.opacity(0.6).clipShape(Circle()))
                                .offset(x: 4, y: 4)
                        }
                } else if let art = artworkSong?.artwork {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 180)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.4), radius: 20)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.msAccent)
                                .background(Color.black.opacity(0.6).clipShape(Circle()))
                                .offset(x: 4, y: 4)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.msCard)
                            .frame(width: 180, height: 180)
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.msAccent.opacity(0.5))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.msAccent)
                            .background(Color.black.opacity(0.6).clipShape(Circle()))
                            .offset(x: 4, y: 4)
                    }
                }
            }
            Text("\(songs.count) Songs")
                .font(.caption)
                .foregroundColor(.msSecondary)
            if playlist.isNonstop {
                Label("Nonstop Playlist", systemImage: "infinity")
                    .font(.caption)
                    .foregroundColor(.msAccent)
            }
        }
        .padding(.vertical, 20)
    }
}

struct AddSongsView: View {
    let playlist: Playlist
    @EnvironmentObject var libraryVM: LibraryViewModel
    @Environment(\.dismiss) var dismiss

    var availableSongs: [Song] {
        libraryVM.songs.filter { !playlist.songIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                List(availableSongs) { song in
                    SongRowView(song: song)
                        .listRowBackground(Color.msBackground)
                        .onTapGesture {
                            libraryVM.addSong(song, to: playlist)
                            dismiss()
                        }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Song hinzufügen")
            .toolbar {
                Button("Fertig") { dismiss() }
            }
        }
    }
}
