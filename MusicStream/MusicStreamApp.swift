import SwiftUI

@main
struct MusicStreamApp: App {
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var playerVM = MusicPlayerViewModel()
    @AppStorage("appLanguage") private var language = "de"

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .environmentObject(libraryVM)
                .environmentObject(playerVM)
                .environment(\.locale, Locale(identifier: language))
        }
    }
}
