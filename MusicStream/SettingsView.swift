import SwiftUI

struct SettingsView: View {
    @AppStorage("metadataProvider") private var provider = "musicbrainz"
    @AppStorage("appLanguage") private var language = "de"

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

                    Section("Sprache") {
                        Picker("App-Sprache", selection: $language) {
                            Text("Deutsch").tag("de")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.menu)
                        Text("Starte die App neu, damit die Änderung wirkt.")
                            .font(.caption)
                            .foregroundColor(.msSecondary)
                    }

                    Section("Info") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0")
                                .foregroundColor(.msSecondary)
                        }
                        HStack {
                            Text("Entwickler")
                            Spacer()
                            Text("Matteo")
                                .foregroundColor(.msSecondary)
                        }
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
