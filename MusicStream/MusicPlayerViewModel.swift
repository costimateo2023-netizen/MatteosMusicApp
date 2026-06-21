import Foundation
import Combine

class MusicPlayerViewModel: ObservableObject {
    @Published var currentSong: Song?
    @Published var queue: [Song] = []
    @Published var currentIndex: Int = 0
    @Published var isNonstop: Bool = true
    @Published var isShuffle: Bool = false
    @Published var repeatMode: RepeatMode = .none
    @Published var isPlayerExpanded: Bool = false

    private let audioService = AudioPlayerService.shared
    private var cancellables = Set<AnyCancellable>()

    enum RepeatMode { case none, one, all }

    var isPlaying: Bool { audioService.isPlaying }
    var currentTime: TimeInterval { audioService.currentTime }
    var duration: TimeInterval { audioService.duration }

    init() {
        audioService.onSongFinished = { [weak self] in
            DispatchQueue.main.async { self?.playNext() }
        }
        audioService.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        audioService.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func play(song: Song, in songs: [Song]) {
        queue = isShuffle ? songs.shuffled() : songs
        currentIndex = queue.firstIndex(where: { $0.id == song.id }) ?? 0
        currentSong = queue[currentIndex]
        audioService.play(song: queue[currentIndex])
    }

    func playSong(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        currentSong = queue[currentIndex]
        audioService.play(song: queue[currentIndex])
    }

    func togglePlayPause() {
        audioService.togglePlayPause()
    }

    func playNext() {
        switch repeatMode {
        case .one:
            audioService.play(song: queue[currentIndex])
        case .all:
            currentIndex = (currentIndex + 1) % queue.count
            playSong(at: currentIndex)
        case .none:
            let next = currentIndex + 1
            if next < queue.count {
                playSong(at: next)
            } else if isNonstop && !queue.isEmpty {
                // Nonstop: restart from beginning
                playSong(at: 0)
            }
        }
    }

    func playPrevious() {
        if audioService.currentTime > 3 {
            audioService.seek(to: 0)
            return
        }
        let prev = max(0, currentIndex - 1)
        playSong(at: prev)
    }

    func seek(to time: TimeInterval) {
        audioService.seek(to: time)
    }

    func setVolume(_ vol: Float) {
        audioService.setVolume(vol)
    }

    func toggleShuffle() {
        isShuffle.toggle()
        if isShuffle {
            let current = queue[currentIndex]
            var rest = queue
            rest.remove(at: currentIndex)
            queue = [current] + rest.shuffled()
            currentIndex = 0
        }
    }

    func toggleRepeat() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .none
        }
    }
}
