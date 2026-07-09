import SwiftUI
import AVKit
import MediaPlayer

struct PlayerView: View {
    @StateObject private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss

    let url: String
    let title: String
    var playlist: [(String, String)] = []
    var initialIndex: Int = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                videoPlayerLayer

                if !viewModel.isLocked && viewModel.showOverlay {
                    topBar
                    sideControls
                    bottomBar
                }

                if viewModel.isLocked {
                    lockOverlay
                }

                if viewModel.showOverlay {
                    feedbackOverlay
                }
            }
            .ignoresSafeArea()
            .onAppear {
                viewModel.configure(with: url, title: title, playlist: playlist, startIndex: initialIndex)
            }
            .onDisappear {
                viewModel.savePlaybackPosition()
                viewModel.cleanup()
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
    }

    @ViewBuilder
    private var videoPlayerLayer: some View {
        ZStack {
            AVPlayerControllerRepresentable(player: viewModel.player, videoGravity: viewModel.videoGravity)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if abs(value.translation.height) > abs(value.translation.width) {
                                let isLeft = value.location.x < UIScreen.main.bounds.width / 2
                                viewModel.handleVerticalDrag(delta: value.translation.height, isLeftSide: isLeft)
                            } else {
                                viewModel.handleHorizontalDrag(translation: value.translation.width, screenWidth: UIScreen.main.bounds.width)
                            }
                        }
                        .onEnded { _ in
                            viewModel.endHorizontalDrag()
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            let center = UIScreen.main.bounds.width / 2
                            viewModel.handleDoubleTap(isLeftSide: true)
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            viewModel.showOverlay.toggle()
                            viewModel.overlayType = "controls"
                        }
                )
        }
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(Date(), style: .time)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Image(systemName: "battery.100")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                Button { } label: {
                    Image(systemName: "airplayaudio")
                        .foregroundColor(.white)
                }

                if !viewModel.playlist.isEmpty {
                    Button { showPlaylist() } label: {
                        Image(systemName: "list.triangle")
                            .foregroundColor(.white)
                    }
                }

                Button { showMediaInfo() } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                }

                Button { viewModel.toggleDecoder() } label: {
                    Text(viewModel.isHWDecoderEnabled ? "HW" : "SW")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.7)))
                }

                Button { showMoreMenu() } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            Spacer()
        }
    }

    private var sideControls: some View {
        HStack {
            VStack(spacing: 20) {
                Button { showPlaylist() } label: {
                    Image(systemName: "list.triangle")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                Button { viewModel.cycleVideoGravity() } label: {
                    Image(systemName: "rectangle.arrowtriangle.2.outward")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(.leading, 8)

            Spacer()

            VStack(spacing: 20) {
                Button { viewModel.toggleABRepeat() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "repeat.1")
                            .foregroundColor(viewModel.isABRepeatEnabled ? .orange : .white)
                            .font(.title3)
                        Text("AB")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(viewModel.isABRepeatEnabled ? .orange : .white)
                    }
                }
                Button { showSpeedSheet() } label: {
                    Image(systemName: "speedometer")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(.trailing, 8)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.formatTime(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                Slider(value: Binding(get: {
                    viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0
                }, set: { newValue in
                    viewModel.seek(to: newValue * viewModel.duration)
                }), in: 0...1)
                    .accentColor(.white)
                Text(viewModel.formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 0) {
                Button { viewModel.toggleLock() } label: {
                    Image(systemName: viewModel.isLocked ? "lock" : "lock.open")
                        .foregroundColor(.white)
                        .font(.body)
                }
                .frame(width: 44)

                Spacer()

                Button { viewModel.playPrevious() } label: {
                    Image(systemName: "backward.end.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .frame(width: 44)

                Button { viewModel.seekBackward(10) } label: {
                    Image(systemName: "gobackward.10")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .frame(width: 44)

                Button { viewModel.togglePlayPause() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 44))
                }
                .frame(width: 60)

                Button { viewModel.seekForward(10) } label: {
                    Image(systemName: "goforward.10")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .frame(width: 44)

                Button { viewModel.playNext() } label: {
                    Image(systemName: "forward.end.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .frame(width: 44)

                Spacer()

                Button { viewModel.togglePiP() } label: {
                    Image(systemName: "picture.inpicture")
                        .foregroundColor(viewModel.isPiPAvailable ? .white : .gray)
                        .font(.body)
                }
                .frame(width: 44)
                .disabled(!viewModel.isPiPAvailable)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private var lockOverlay: some View {
        VStack {
            Spacer()
            Button { viewModel.toggleLock() } label: {
                Image(systemName: "lock")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
    }

    private var feedbackOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: overlayIcon)
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                    overlayContent
                }
                .padding(24)
                .background(.black.opacity(0.6))
                .cornerRadius(16)
                Spacer()
            }
            Spacer()
        }
    }

    private var overlayIcon: String {
        switch viewModel.overlayType {
        case "brightness": return "sun.max"
        case "volume": return "speaker.wave.2"
        case "seek_forward": return "forward.frame"
        case "seek_back": return "backward.frame"
        case "seek": return "arrow.left.arrow.right"
        case "speed": return "speedometer"
        case "lock": return "lock"
        case "unlock": return "lock.open"
        case "fit": return "rectangle.arrowtriangle.2.outward"
        case "audio": return "music.note"
        case "subtitle": return "captions.bubble"
        case "ab_start": return "repeat.1"
        case "ab_repeat_on": return "repeat.1"
        case "ab_repeat_off": return "repeat"
        case "decoder": return "cpu"
        default: return "info.circle"
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        switch viewModel.overlayType {
        case "brightness":
            ProgressView(value: viewModel.brightness)
                .tint(.white)
                .frame(width: 100)
        case "volume":
            ProgressView(value: viewModel.volume)
                .tint(.white)
                .frame(width: 100)
        case "seek":
            Text("\(viewModel.formatTime(viewModel.seekPosition)) / \(viewModel.formatTime(viewModel.duration))")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        case "seek_forward", "seek_back":
            Text("10s")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
        case "speed":
            Text("\(viewModel.playbackSpeed, specifier: "%.2f")x")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
        case "lock":
            Text("Locked").font(.title2.weight(.bold)).foregroundColor(.white)
        case "unlock":
            Text("Unlocked").font(.title2.weight(.bold)).foregroundColor(.white)
        case "fit":
            Text(fitModeLabel).font(.title2.weight(.bold)).foregroundColor(.white)
        case "audio":
            Text("Audio Track Changed").font(.title2.weight(.bold)).foregroundColor(.white)
        case "subtitle":
            Text("Subtitle Track Changed").font(.title2.weight(.bold)).foregroundColor(.white)
        case "ab_start":
            Text("A Point Set").font(.title2.weight(.bold)).foregroundColor(.white)
        case "ab_repeat_on":
            Text("AB Repeat ON").font(.title2.weight(.bold)).foregroundColor(.orange)
        case "ab_repeat_off":
            Text("AB Repeat OFF").font(.title2.weight(.bold)).foregroundColor(.white)
        case "decoder":
            Text(viewModel.isHWDecoderEnabled ? "HW Decoder" : "SW Decoder")
                .font(.title2.weight(.bold)).foregroundColor(.white)
        default:
            EmptyView()
        }
    }

    private var fitModeLabel: String {
        switch viewModel.videoGravity {
        case .resizeAspect: return "Contain"
        case .resizeAspectFill: return "Cover"
        default: return "Fill"
        }
    }

    private func showSpeedSheet() {
        viewModel.overlayType = "speed"
        viewModel.showOverlay = true
    }

    private func showPlaylist() {}

    private func showMediaInfo() {}

    private func showMoreMenu() {}
}

struct AVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = videoGravity
        controller.showsPlaybackControls = false
        controller.updatesNowPlayingInfoCenter = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.videoGravity = videoGravity
    }
}
