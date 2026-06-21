import SwiftUI

struct OnlineSearchView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @State private var searchQuery = ""
    @State private var results: [iTunesResult] = []
    @State private var isSearching = false
    @State private var downloadingIDs = Set<Int>()

    private let metadata = MetadataService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.msSecondary)
                        TextField("Song oder K\u{00FC}nstler suchen", text: $searchQuery)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit { search() }
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                results = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.msSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.msCard)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if isSearching {
                        Spacer()
                        ProgressView()
                            .tint(.msAccent)
                        Spacer()
                    } else if results.isEmpty && !searchQuery.isEmpty {
                        Spacer()
                        Text("Keine Ergebnisse")
                            .foregroundColor(.msSecondary)
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 50))
                                .foregroundColor(.msAccent.opacity(0.4))
                            Text("Suche nach Songs aus dem iTunes-Store")
                                .foregroundColor(.msSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(results, id: \.trackId) { track in
                                    OnlineTrackRow(track: track, isDownloading: downloadingIDs.contains(track.trackId ?? 0)) {
                                        download(track)
                                    }
                                }
                            }
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
            .navigationTitle("Entdecken")
        }
    }

    private func search() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        results = []
        Task {
            let tracks = await metadata.searchTracks(query: searchQuery)
            await MainActor.run {
                results = tracks
                isSearching = false
            }
        }
    }

    private func download(_ track: iTunesResult) {
        guard let tid = track.trackId, let previewUrl = track.previewUrl else { return }
        downloadingIDs.insert(tid)
        Task {
            let audioData = await metadata.downloadPreview(url: previewUrl)
            let artworkData: Data?
            if let artUrl = track.artworkUrl100 {
                let highRes = artUrl.replacingOccurrences(of: "100x100", with: "600x600")
                artworkData = try? await URLSession.shared.data(from: URL(string: highRes)!).0
            } else {
                artworkData = nil
            }
            await MainActor.run {
                libraryVM.importOnlineTrack(
                    title: track.trackName ?? "Unbekannt",
                    artist: track.artistName ?? "Unbekannt",
                    album: track.collectionName ?? "Unbekannt",
                    audioData: audioData,
                    artworkData: artworkData
                )
                downloadingIDs.remove(tid)
            }
        }
    }
}

struct OnlineTrackRow: View {
    let track: iTunesResult
    let isDownloading: Bool
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if
                    let url = track.artworkUrl100,
                    let urlStr = URL(string: url)
                {
                    AsyncImage(url: urlStr) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            ZStack {
                                Color.msCard
                                Image(systemName: "music.note")
                                    .foregroundColor(.msSecondary)
                            }
                        }
                    }
                } else {
                    ZStack {
                        Color.msCard
                        Image(systemName: "music.note")
                            .foregroundColor(.msSecondary)
                    }
                }
            }
            .frame(width: 52, height: 52)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.trackName ?? "Unbekannt")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artistName ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.msSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if isDownloading {
                ProgressView()
                    .tint(.msAccent)
            } else {
                Button(action: onDownload) {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundColor(.msAccent)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
