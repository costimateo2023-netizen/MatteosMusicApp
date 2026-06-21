import SwiftUI

struct SettingsView: View {
    @AppStorage("metadataProvider") private var provider = "musicbrainz"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                Form {
                    Section("Metadaten-Anbieter") {
                        Picker("Anbieter", selection: $provider) {
                            Text("MusicBrainz").tag("musicbrainz")
                            Text("iTunes").tag("itunes")
                        }
                        .pickerStyle(.menu)
                        Text("Wird beim Abrufen von Song-Metadaten und Album-Covern verwendet.")
                            .font(.caption)
                            .foregroundColor(.msSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Einstellungen")
        }
        .preferredColorScheme(.dark)
    }
}
