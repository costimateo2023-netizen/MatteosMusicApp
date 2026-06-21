import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: MusicPlayerViewModel

    var body: some View {
        guard let song = playerVM.currentSong else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.15))
                        Rectangle()
                            .fill(Color.msAccent)
                            .frame(width: geo.size.width * (playerVM.duration > 0 ? playerVM.currentTime / playerVM.duration : 0))
                    }
                }
                .frame(height: 2)

                HStack(spacing: 14) {
                    // Artwork
                    Group {
                        if let artwork = song.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Color.msCard
                                Image(systemName: "music.note")
                                    .foregroundColor(.msSecondary)
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)

                    // Title
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundColor(.msSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Controls
                    HStack(spacing: 20) {
                        Button { playerVM.togglePlayPause() } label: {
                            Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Button { playerVM.playNext() } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(12, corners: [.topLeft, .topRight])
        )
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
