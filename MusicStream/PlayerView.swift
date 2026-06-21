import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var playerVM: MusicPlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Background gradient from artwork
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.25), Color.msBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Jetzt läuft")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button {} label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Artwork
                if let song = playerVM.currentSong, let artwork = song.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
                        .scaleEffect(playerVM.isPlaying ? 1.0 : 0.85)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: playerVM.isPlaying)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.msCard)
                            .frame(width: 280, height: 280)
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.msAccent.opacity(0.5))
                    }
                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
                }

                Spacer()

                // Song info
                if let song = playerVM.currentSong {
                    VStack(spacing: 6) {
                        Text(song.title)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(song.artist) · \(song.album)")
                            .font(.subheadline)
                            .foregroundColor(.msSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 32)
                }

                // Seek bar
                VStack(spacing: 4) {
                    Slider(value: Binding(
                        get: { playerVM.currentTime },
                        set: { playerVM.seek(to: $0) }
                    ), in: 0...max(playerVM.duration, 1))
                    .accentColor(.white)

                    HStack {
                        Text(playerVM.currentTime.formattedMMSS)
                        Spacer()
                        Text(playerVM.duration.formattedMMSS)
                    }
                    .font(.caption)
                    .foregroundColor(.msSecondary)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                // Controls
                HStack(spacing: 40) {
                    // Shuffle
                    Button { playerVM.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            .font(.title2)
                            .foregroundColor(playerVM.isShuffle ? .msAccent : .white.opacity(0.6))
                    }

                    // Previous
                    Button { playerVM.playPrevious() } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }

                    // Play/Pause
                    Button { playerVM.togglePlayPause() } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.black)
                        }
                    }

                    // Next
                    Button { playerVM.playNext() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }

                    // Repeat
                    Button { playerVM.toggleRepeat() } label: {
                        Image(systemName: playerVM.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.title2)
                            .foregroundColor(playerVM.repeatMode == .none ? .white.opacity(0.6) : .msAccent)
                    }
                }
                .padding(.top, 24)

                // Nonstop toggle
                HStack {
                    Image(systemName: "infinity")
                        .foregroundColor(playerVM.isNonstop ? .msAccent : .msSecondary)
                    Text("Nonstop")
                        .font(.subheadline)
                        .foregroundColor(playerVM.isNonstop ? .white : .msSecondary)
                    Toggle("", isOn: $playerVM.isNonstop)
                        .labelsHidden()
                        .tint(.msAccent)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                // Volume
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill").foregroundColor(.msSecondary)
                    Slider(value: Binding(
                        get: { Double(AudioPlayerService.shared.volume) },
                        set: { playerVM.setVolume(Float($0)) }
                    ), in: 0...1)
                    .accentColor(.msSecondary)
                    Image(systemName: "speaker.wave.3.fill").foregroundColor(.msSecondary)
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)

                Spacer()
            }
        }
    }
}
