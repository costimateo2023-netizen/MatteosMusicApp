import SwiftUI

struct ContentView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var playerVM: MusicPlayerViewModel
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Bibliothek", systemImage: "music.note.list")
                    }
                    .tag(0)

                PlaylistView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    .tag(1)

                OnlineSearchView()
                    .tabItem {
                        Label("Entdecken", systemImage: "magnifyingglass")
                    }
                    .tag(2)
            }
            .accentColor(.msAccent)

            // Mini player above tab bar
            if playerVM.currentSong != nil && !playerVM.isPlayerExpanded {
                VStack(spacing: 0) {
                    MiniPlayerView()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                playerVM.isPlayerExpanded = true
                            }
                        }
                    Color.clear.frame(height: 49) // Tab bar height
                }
            }
        }
        .background(Color.msBackground)
        .sheet(isPresented: $playerVM.isPlayerExpanded) {
            PlayerView()
        }
        .preferredColorScheme(.dark)
    }
}
