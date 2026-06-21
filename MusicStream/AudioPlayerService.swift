import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 1.0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    var onSongFinished: (() -> Void)?

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func play(song: Song) {
        stop()
        guard FileManager.default.fileExists(atPath: song.fileURL.path) else {
            print("File not found: \(song.fileURL.path)")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: song.fileURL)
            player?.delegate = self
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
            duration = player?.duration ?? 0
            isPlaying = true
            startTimer()
            updateNowPlayingInfo(song: song)
        } catch {
            print("Player error: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func setVolume(_ vol: Float) {
        volume = vol
        player?.volume = vol
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.currentTime = self?.player?.currentTime ?? 0
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onSongFinished?()
            return .success
        }
    }

    private func updateNowPlayingInfo(song: Song) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = song.title
        info[MPMediaItemPropertyArtist] = song.artist
        info[MPMediaItemPropertyAlbumTitle] = song.album
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        if let artworkData = song.artworkData, let image = UIImage(data: artworkData) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        onSongFinished?()
    }
}
