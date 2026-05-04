import AVFoundation
import CoreVideo
import QuartzCore
import SwiftUI
import UIKit

/// Tiêu đề bloom + typewriter + zen + nút Tiếp tục. `immersiveBackground` = màn bloom đầy (nền + video riêng); `false` = phủ lên gameplay (chỉ scrim + hiệu ứng).
struct BloomCelebrationOverlayPanel: View {
    let level: LevelDefinition
    var immersiveBackground: Bool
    var onContinue: () -> Void

    @EnvironmentObject private var spatial: SpatialAmbientAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0
    @State private var typewriterVisibleCount = 0
    @State private var subtitleBlur: CGFloat = 7

    private var bundleVideoURL: URL? { LevelBundleVideoURL.url(forLevelId: level.id) }

    private var taglineFull: String { String(localized: "splash_tagline") }

    var body: some View {
        ZStack {
            if immersiveBackground {
                NatureBackground(variant: .home)
                Color.black.opacity(0.38).ignoresSafeArea()

                if let url = bundleVideoURL {
                    BloomFullscreenVideoRepresentable(url: url)
                        .scaleEffect(reduceMotion ? 1.0 : pulse)
                        .brightness(reduceMotion ? 0.0 : 0.06)
                        .ignoresSafeArea()
                        .blur(radius: reduceMotion ? 0 : 0.28)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        SyntheticLoopView(
                            palette: level.syntheticPalette,
                            globalTime: t,
                            col: 0,
                            row: 0
                        )
                        .scaleEffect(reduceMotion ? 1.0 : pulse)
                        .brightness(reduceMotion ? 0.0 : 0.08)
                        .ignoresSafeArea()
                        .blur(radius: reduceMotion ? 0 : 0.35)
                    }
                }

                Color.black.opacity(0.22).ignoresSafeArea()
            } else {
                Color.black.opacity(0.48).ignoresSafeArea()
            }

            if !reduceMotion {
                ZenCrystalEmitterRepresentable()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 18) {
                Spacer()
                BloomShimmerTitle(
                    text: String(localized: "bloom_title"),
                    reduceMotion: reduceMotion
                )
                .scaleEffect(!immersiveBackground && !reduceMotion ? pulse : 1.0)
                Capsule()
                    .fill(NaturePalette.luxuryStrokeGradient.opacity(0.55))
                    .frame(width: 200, height: 2)
                    .shadow(color: NaturePalette.champagne.opacity(0.4), radius: 6)
                BloomTypewriterSubtitle(
                    fullText: taglineFull,
                    visibleCount: typewriterVisibleCount,
                    blurRadius: subtitleBlur
                )
                .padding(.horizontal, 22)
                Button(action: {
                    HapticsService.playMenuTap()
                    onContinue()
                }) {
                    Text(String(localized: "continue_action"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NaturePrimaryButtonStyle())
                .padding(.horizontal, 26)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            AdManager.shared.presentInterstitialAfterPuzzleIfAllowed()
            spatial.playBloomChime()
            HapticsService.playBloomReveal()
            startTypographyAnimations()
            guard !reduceMotion else { return }
            let peak: CGFloat = immersiveBackground ? 1.05 : 1.03
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = peak
            }
        }
    }

    private func startTypographyAnimations() {
        typewriterVisibleCount = 0
        subtitleBlur = reduceMotion ? 0 : 7
        let full = taglineFull
        guard !full.isEmpty else { return }
        if reduceMotion {
            typewriterVisibleCount = full.count
            subtitleBlur = 0
            return
        }
        let charDelayNs: UInt64 = 48_000_000
        Task { @MainActor in
            for i in 0 ... full.count {
                typewriterVisibleCount = i
                let p = Double(i) / Double(max(1, full.count))
                subtitleBlur = CGFloat((1 - p) * 6.2)
                if i < full.count {
                    try? await Task.sleep(nanoseconds: charDelayNs)
                }
            }
            subtitleBlur = 0
        }
    }
}

/// Giữ cho preview / tái sử dụng — cùng nội dung với màn bloom cũ (nền đầy).
struct BloomCompletionView: View {
    let level: LevelDefinition
    var onFinished: () -> Void

    var body: some View {
        BloomCelebrationOverlayPanel(level: level, immersiveBackground: true, onContinue: onFinished)
    }
}

// MARK: - Shimmer title

private struct BloomShimmerTitle: View {
    let text: String
    var reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            Text(text)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(NaturePalette.titleLuxuryGradient)
                .shadow(color: NaturePalette.goldRing.opacity(0.35), radius: 18, y: 2)
                .padding(.horizontal, 18)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let sweep = (t.truncatingRemainder(dividingBy: 3.2)) / 3.2
                Text(text)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NaturePalette.titleLuxuryGradient)
                    .shadow(color: NaturePalette.goldRing.opacity(0.35), radius: 18, y: 2)
                    .overlay {
                        GeometryReader { geo in
                            let w = geo.size.width
                            let bandW = max(80, w * 0.42)
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    NaturePalette.champagne.opacity(0.95),
                                    Color.white.opacity(0.55),
                                    NaturePalette.goldRing.opacity(0.85),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: bandW)
                            .offset(x: -bandW + sweep * (w + bandW * 2))
                            .blendMode(.plusLighter)
                        }
                        .mask(
                            Text(text)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                        )
                    }
                    .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Typewriter + blur subtitle

private struct BloomTypewriterSubtitle: View {
    let fullText: String
    let visibleCount: Int
    let blurRadius: CGFloat

    var body: some View {
        let end = fullText.index(fullText.startIndex, offsetBy: min(visibleCount, fullText.count), limitedBy: fullText.endIndex) ?? fullText.endIndex
        let slice = String(fullText[..<end])
        Text(slice)
            .font(.title3.weight(.medium))
            .foregroundStyle(NaturePalette.cream.opacity(0.78))
            .multilineTextAlignment(.center)
            .blur(radius: blurRadius)
            .animation(.easeOut(duration: 0.12), value: visibleCount)
            .animation(.easeOut(duration: 0.22), value: blurRadius)
    }
}

// MARK: - Looping fullscreen video

private struct BloomFullscreenVideoRepresentable: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> VideoFullBoardUIView {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1.5
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        if #available(iOS 15.0, *) {
            item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
        }
        let pixAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        let out = AVPlayerItemVideoOutput(pixelBufferAttributes: pixAttrs)
        let qp = AVQueuePlayer()
        qp.isMuted = true
        let looper = AVPlayerLooper(player: qp, templateItem: item)
        context.coordinator.currentItemObservation = PlayerLooperVideoOutputBinding.observeCurrentItem(player: qp, output: out)
        context.coordinator.looper = looper
        context.coordinator.videoOutput = out
        context.coordinator.player = qp
        context.coordinator.loadedURL = url
        qp.play()
        DispatchQueue.main.async { qp.lj_rehomeVideoOutput(out) }
        return VideoFullBoardUIView(player: qp, itemVideoOutput: out)
    }

    func updateUIView(_ uiView: VideoFullBoardUIView, context: Context) {
        if context.coordinator.loadedURL != url {
            context.coordinator.tearDown()
            context.coordinator.loadedURL = url
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 1.5
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
            if #available(iOS 15.0, *) {
                item.preferredMaximumResolution = CGSize(width: 1280, height: 720)
            }
            let pixAttrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferMetalCompatibilityKey as String: true,
            ]
            let out = AVPlayerItemVideoOutput(pixelBufferAttributes: pixAttrs)
            let qp = AVQueuePlayer()
            qp.isMuted = true
            let looper = AVPlayerLooper(player: qp, templateItem: item)
            context.coordinator.currentItemObservation = PlayerLooperVideoOutputBinding.observeCurrentItem(player: qp, output: out)
            context.coordinator.looper = looper
            context.coordinator.videoOutput = out
            context.coordinator.player = qp
            uiView.replacePlayer(qp, itemVideoOutput: out)
            qp.play()
            DispatchQueue.main.async { qp.lj_rehomeVideoOutput(out) }
        }
    }

    static func dismantleUIView(_ uiView: VideoFullBoardUIView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    final class Coordinator: NSObject {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var videoOutput: AVPlayerItemVideoOutput?
        var loadedURL: URL?
        var currentItemObservation: NSKeyValueObservation?

        func tearDown() {
            currentItemObservation?.invalidate()
            currentItemObservation = nil
            if let p = player {
                PuzzleVideoFrameHub.shared.unregisterPlayer(p)
            }
            looper?.disableLooping()
            looper = nil
            player?.pause()
            player = nil
            videoOutput = nil
        }
    }
}

// MARK: - Zen crystal particles (CAEmitterLayer)

private enum ZenCrystalEmitterArt {
    static let shard: UIImage = {
        let s: CGFloat = 10
        let r = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        return r.image { ctx in
            let cg = ctx.cgContext
            cg.setAllowsAntialiasing(true)
            let colors = [
                UIColor(white: 1, alpha: 0.95).cgColor,
                UIColor(red: 0.92, green: 0.88, blue: 0.72, alpha: 0.35).cgColor,
                UIColor.clear.cgColor
            ]
            if let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.45, 1]
            ) {
                cg.drawRadialGradient(
                    grad,
                    startCenter: CGPoint(x: s * 0.5, y: s * 0.5),
                    startRadius: 0,
                    endCenter: CGPoint(x: s * 0.5, y: s * 0.5),
                    endRadius: s * 0.52,
                    options: []
                )
            }
        }
    }()
}

private final class ZenCrystalEmitterUIView: UIView {
    private let emitter = CAEmitterLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        emitter.emitterShape = .circle
        emitter.emitterMode = .outline
        emitter.renderMode = .additive
        emitter.emitterSize = CGSize(width: 28, height: 28)

        let cell = CAEmitterCell()
        cell.contents = ZenCrystalEmitterArt.shard.cgImage
        cell.birthRate = 48
        cell.lifetime = 5.2
        cell.lifetimeRange = 1.2
        cell.velocity = 26
        cell.velocityRange = 38
        cell.emissionRange = .pi * 2
        cell.scale = 0.045
        cell.scaleRange = 0.028
        cell.scaleSpeed = -0.004
        cell.alphaSpeed = -0.12
        cell.alphaRange = 0.25
        cell.spin = 0.15
        cell.spinRange = 0.4
        cell.color = UIColor(red: 0.92, green: 0.9, blue: 0.78, alpha: 0.55).cgColor
        cell.yAcceleration = -4

        let drift = CAEmitterCell()
        drift.contents = ZenCrystalEmitterArt.shard.cgImage
        drift.birthRate = 14
        drift.lifetime = 8
        drift.velocity = 12
        drift.velocityRange = 16
        drift.emissionRange = .pi * 2
        drift.scale = 0.028
        drift.scaleRange = 0.02
        drift.alphaSpeed = -0.07
        drift.color = UIColor(red: 0.75, green: 0.88, blue: 0.95, alpha: 0.28).cgColor

        emitter.emitterCells = [cell, drift]
        layer.addSublayer(emitter)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY * 0.92)
    }
}

private struct ZenCrystalEmitterRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ZenCrystalEmitterUIView {
        ZenCrystalEmitterUIView()
    }

    func updateUIView(_ uiView: ZenCrystalEmitterUIView, context: Context) {}
}
