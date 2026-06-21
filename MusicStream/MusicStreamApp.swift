import SwiftUI

@main
struct MusicStreamApp: App {
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var playerVM = MusicPlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryVM)
                .environmentObject(playerVM)
                .preferredColorScheme(.dark)
        }
    }
}
