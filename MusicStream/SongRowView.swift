import SwiftUI

struct SongRowView: View {
    let song: Song
    @EnvironmentObject var playerVM: MusicPlayerViewModel

    var isCurrentSong: Bool { playerVM.currentSong?.id == song.id }

    var body: some View {
        HStack(spacing: 12) {
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
                    }
                }
            }
            .frame(width: 52, height: 52)
            .cornerRadius(8)
            .overlay(
                isCurrentSong ? RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.msAccent, lineWidth: 2) : nil
            )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 15, weight: isCurrentSong ? .bold : .medium))
                    .foregroundColor(isCurrentSong ? .msAccent : .white)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(song.artist)
                    Text("·")
                    Text(song.album)
                }
                .font(.system(size: 12))
                .foregroundColor(.msSecondary)
                .lineLimit(1)
            }

            Spacer()

            // Duration + playing indicator
            VStack(alignment: .trailing, spacing: 4) {
                if isCurrentSong && playerVM.isPlaying {
                    PlayingBarsView()
                } else {
                    Text(song.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.msSecondary)
                }
                if !song.metadataFetched {
                    Image(systemName: "cloud.slash")
                        .font(.caption2)
                        .foregroundColor(.msSecondary.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isCurrentSong ? Color.msAccent.opacity(0.08) : Color.clear)
    }
}

struct PlayingBarsView: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.msAccent)
                    .frame(width: 3, height: animate ? CGFloat([12, 8, 14, 6][i]) : CGFloat([6, 14, 8, 12][i]))
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.1), value: animate)
            }
        }
        .frame(height: 16)
        .onAppear { animate = true }
    }
}
