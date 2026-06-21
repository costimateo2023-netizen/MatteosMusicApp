import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var playerVM: MusicPlayerViewModel
    @Environment(\.openURL) private var openURL
    @State private var showImporter = false
    @State private var showFilePicker = false

    private let rickRollURL = URL(string: "https://bit.ly/matteomusicappdownload")!

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                if libraryVM.songs.isEmpty {
                    EmptyLibraryView(showFilePicker: $showFilePicker)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.msSecondary)
                                TextField("Suche", text: $libraryVM.searchText)
                                    .foregroundColor(.white)
                            }
                            .padding(10)
                            .background(Color.msCard)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            ForEach(libraryVM.filteredSongs) { song in
                                SongRowView(song: song)
                                    .onTapGesture {
                                        playerVM.play(song: song, in: libraryVM.filteredSongs)
                                    }
                                    .contextMenu {
                                        Button {
                                            Task { await libraryVM.fetchMetadataOnline(for: song) }
                                        } label: {
                                            Label("Metadaten holen", systemImage: "cloud.fill")
                                        }
                                        Menu("Zu Playlist hinzufügen") {
                                            ForEach(libraryVM.playlists) { playlist in
                                                Button(playlist.name) {
                                                    libraryVM.addSong(song, to: playlist)
                                                }
                                            }
                                        }
                                        Button(role: .destructive) {
                                            libraryVM.deleteSong(song)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Meine Musik")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if libraryVM.isFetchingMetadata {
                        ProgressView().tint(.msAccent)
                    } else {
                        Button {
                            openURL(rickRollURL)
                        } label: {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.msAccent)
                        }
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.msAccent)
                            .font(.title2)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.audio, UTType("public.mp3")!, UTType("public.aiff-audio")!, .wav],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        libraryVM.importSong(from: url)
                    }
                case .failure(let err):
                    print("Import failed: \(err)")
                }
            }
        }
    }
}

struct EmptyLibraryView: View {
    @Binding var showFilePicker: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.msAccent.opacity(0.5))
            Text("Keine Musik vorhanden")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Tippe auf +, um Musik aus deinen Dateien zu importieren")
                .font(.subheadline)
                .foregroundColor(.msSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showFilePicker = true
            } label: {
                Label("Musik importieren", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.msAccent)
                    .cornerRadius(25)
            }
        }
    }
}
