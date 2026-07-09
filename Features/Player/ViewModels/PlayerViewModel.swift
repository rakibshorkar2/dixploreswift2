import Foundation
import AVFoundation
import AVKit
import MediaPlayer
import UIKit
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.5
    @Published var playbackSpeed: Float = 1.0
    @Published var isPiPAvailable = false
    @Published var isPictureInPictureActive = false
    @Published var currentTitle = ""
    @Published var currentUrl = ""
    @Published var playlist: [PlaylistItem] = []
    @Published var currentIndex = 0
    @Published var isABRepeatEnabled = false
    @Published var abStart: TimeInterval = 0
    @Published var abEnd: TimeInterval = 0
    @Published var isHWDecoderEnabled = true
    @Published var subtitleTracks: [AVMediaSelectionOption] = []
    @Published var selectedSubtitle: AVMediaSelectionOption?
    @Published var availableAudioTracks: [AVMediaSelectionOption] = []
    @Published var selectedAudioTrack: AVMediaSelectionOption?
    @Published var videoGravity: AVLayerVideoGravity = .resizeAspect
    @Published var isLocked = false
    @Published var brightness: CGFloat = 0.5
    @Published var showOverlay = false
    @Published var overlayType: String?
    @Published var seekPosition: TimeInterval = 0
    @Published var isSeeking = false

    private var timeObserver: Any?
    private var itemObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?

    var pipControllerReference: AVPictureInPictureController? {
        pipController
    }

    struct PlaylistItem: Identifiable {
        let id = UUID()
        let url: String
        let title: String
    }

    func configure(with url: String, title: String, playlist: [(String, String)] = [], startIndex: Int = 0) {
        currentUrl = url
        currentTitle = title
        currentIndex = startIndex
        self.playlist = playlist.enumerated().map { PlaylistItem(url: $0.element.0, title: $0.element.1) }
        setupAudioSession()
        setupNowPlaying()
        setupRemoteCommands()
        loadMedia(url: url)
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
        try? session.setActive(true)
    }

    private func setupNowPlaying() {
        var nowPlaying = [String: Any]()
        nowPlaying[MPMediaItemPropertyTitle] = currentTitle
        nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] = playbackSpeed
        nowPlaying[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
        center.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            self?.setPlaybackSpeed(event.playbackRate)
            return .success
        }
    }

    func loadMedia(url: String) {
        guard let mediaURL = URL(string: url) else { return }
        removeObservers()

        let asset = AVURLAsset(url: mediaURL)
        let item = AVPlayerItem(asset: asset)

        itemObservation = item.observe(\.status) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.duration = item.duration.seconds
                    self.updateSubtitleAndAudioTracks()
                    self.setupNowPlaying()
                }
            }
        }

        player.replaceCurrentItem(with: item)
        player.rate = playbackSpeed
        player.volume = volume

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = time.seconds
                self.updateNowPlayingProgress()

                if self.isABRepeatEnabled && self.abEnd > 0 && time.seconds >= self.abEnd {
                    self.seek(to: self.abStart)
                }
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)
    }

    private func removeObservers() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        itemObservation?.invalidate()
        itemObservation = nil
        statusObservation?.invalidate()
        statusObservation = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }

    @objc private func itemDidPlayToEnd() {
        playNext()
    }

    private func updateSubtitleAndAudioTracks() {
        guard let asset = player.currentItem?.asset else { return }
        let group = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        subtitleTracks = group?.options ?? []

        let audioGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        availableAudioTracks = audioGroup?.options ?? []

        if let currentSub = player.currentItem?.currentMediaSelection.selectedMediaOption(in: .legible) {
            selectedSubtitle = currentSub
        }
        if let currentAudio = player.currentItem?.currentMediaSelection.selectedMediaOption(in: .audible) {
            selectedAudioTrack = currentAudio
        }
    }

    func play() {
        player.play()
        isPlaying = true
        updateNowPlayingPlaybackRate()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingPlaybackRate()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = time
                self?.updateNowPlayingProgress()
            }
        }
    }

    func seekForward(_ seconds: TimeInterval = 10) {
        let new = min(currentTime + seconds, duration)
        seek(to: new)
    }

    func seekBackward(_ seconds: TimeInterval = 10) {
        let new = max(currentTime - seconds, 0)
        seek(to: new)
    }

    func setVolume(_ vol: Float) {
        volume = max(0, min(1, vol))
        player.volume = volume
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        player.rate = speed
        updateNowPlayingPlaybackRate()
    }

    func setVideoGravity(_ gravity: AVLayerVideoGravity) {
        videoGravity = gravity
    }

    func playNext() {
        guard !playlist.isEmpty, currentIndex < playlist.count - 1 else { return }
        currentIndex += 1
        let item = playlist[currentIndex]
        currentUrl = item.url
        currentTitle = item.title
        loadMedia(url: item.url)
        play()
    }

    func playPrevious() {
        guard !playlist.isEmpty, currentIndex > 0 else { return }
        currentIndex -= 1
        let item = playlist[currentIndex]
        currentUrl = item.url
        currentTitle = item.title
        loadMedia(url: item.url)
        play()
    }

    func toggleABRepeat() {
        if !isABRepeatEnabled {
            isABRepeatEnabled = true
            abStart = currentTime
            abEnd = 0
            overlayType = "ab_start"
        } else if abEnd == 0 {
            abEnd = max(currentTime, abStart + 5)
            overlayType = "ab_repeat_on"
        } else {
            isABRepeatEnabled = false
            abStart = 0
            abEnd = 0
            overlayType = "ab_repeat_off"
        }
        showOverlay = true
        hideOverlayAfterDelay()
    }

    func setSubtitleTrack(_ option: AVMediaSelectionOption?) {
        guard let item = player.currentItem else { return }
        if let opt = option {
            item.select(opt, in: .legible)
            selectedSubtitle = opt
        } else {
            item.select(nil, in: .legible)
            selectedSubtitle = nil
        }
        overlayType = "subtitle"
        showOverlay = true
        hideOverlayAfterDelay()
    }

    func setAudioTrack(_ option: AVMediaSelectionOption?) {
        guard let item = player.currentItem else { return }
        if let opt = option {
            item.select(opt, in: .audible)
            selectedAudioTrack = opt
        } else {
            item.select(nil, in: .audible)
            selectedAudioTrack = nil
        }
        overlayType = "audio"
        showOverlay = true
        hideOverlayAfterDelay()
    }

    func toggleDecoder() {
        isHWDecoderEnabled.toggle()
    }

    func toggleLock() {
        isLocked.toggle()
        overlayType = isLocked ? "lock" : "unlock"
        showOverlay = true
        hideOverlayAfterDelay()
    }

    func cycleVideoGravity() {
        switch videoGravity {
        case .resizeAspect: videoGravity = .resizeAspectFill
        case .resizeAspectFill: videoGravity = .resize
        default: videoGravity = .resizeAspect
        }
        overlayType = "fit"
        showOverlay = true
        hideOverlayAfterDelay()
    }

    func configurePiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isPiPAvailable = false
            return
        }
        let controller = AVPictureInPictureController(contentSource: .init(playerLayer: AVPlayerLayer(player: player)))
        pipController = controller
        isPiPAvailable = true

        pipPossibleObservation = controller.observe(\.isPictureInPicturePossible) { [weak self] controller, _ in
            Task { @MainActor [weak self] in
                self?.isPiPAvailable = controller.isPictureInPicturePossible
            }
        }
    }

    func togglePiP() {
        guard let controller = pipController else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }

    func handleVerticalDrag(delta: CGFloat, isLeftSide: Bool) {
        let sensitivity: CGFloat = 200
        let change = delta / sensitivity
        if isLeftSide {
            brightness = max(0, min(1, brightness - change))
            UIScreen.main.brightness = brightness
            overlayType = "brightness"
        } else {
            setVolume(volume - Float(change))
            overlayType = "volume"
        }
        showOverlay = true
        hideOverlayAfterDelay()
    }

    func handleHorizontalDrag(translation: CGFloat, screenWidth: CGFloat) {
        guard duration > 0 else { return }
        let ratio = translation / screenWidth
        let seekDelta = duration * Double(ratio)
        if !isSeeking {
            isSeeking = true
            seekPosition = currentTime
        }
        seekPosition = max(0, min(duration, seekPosition + seekDelta))
        overlayType = "seek"
        showOverlay = true
    }

    func endHorizontalDrag() {
        guard isSeeking else { return }
        seek(to: seekPosition)
        isSeeking = false
    }

    func handleDoubleTap(isLeftSide: Bool) {
        if isLeftSide {
            seekBackward(10)
            overlayType = "seek_back"
        } else {
            seekForward(10)
            overlayType = "seek_forward"
        }
        showOverlay = true
        hideOverlayAfterDelay()
    }

    private func hideOverlayAfterDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showOverlay = false
        }
    }

    private func updateNowPlayingProgress() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = duration
    }

    private func updateNowPlayingPlaybackRate() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] = currentTitle
    }

    func cleanup() {
        removeObservers()
        player.pause()
        pipController?.stopPictureInPicture()
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, !time.isInfinite else { return "00:00" }
        let total = Int(time)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    func savePlaybackPosition() {
        guard currentTime > 0 else { return }
        UserDefaults.standard.set(currentTime, forKey: "playback_pos_\(currentUrl)")
    }

    func restorePlaybackPosition() {
        let saved = UserDefaults.standard.double(forKey: "playback_pos_\(currentUrl)")
        guard saved > 0 else { return }
        seek(to: saved)
    }
}
