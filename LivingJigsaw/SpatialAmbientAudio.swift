import AVFoundation
import Foundation

/// Ambient: BGM tĩnh + lớp proximity (low-pass theo khoảng cách ô đúng) + lớp hòa âm theo tiến độ + SFX ngắn (pan, snap, bloom).
@MainActor
final class SpatialAmbientAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let mainMixer = AVAudioMixerNode()
    private let left = AVAudioPlayerNode()
    private let right = AVAudioPlayerNode()

    private let ambientMixer = AVAudioMixerNode()
    private let bgmNode = AVAudioPlayerNode()
    private let proximityNode = AVAudioPlayerNode()
    private let proximityEQ = AVAudioUnitEQ(numberOfBands: 1)
    private let dragShimmerNode = AVAudioPlayerNode()
    private let layerNodes: [AVAudioPlayerNode] = (0..<4).map { _ in AVAudioPlayerNode() }

    private var buffer: AVAudioPCMBuffer?
    private var settleBuffer: AVAudioPCMBuffer?
    private var tickBuffer: AVAudioPCMBuffer?
    private var bloomBuffer: AVAudioPCMBuffer?
    private var bgmLoopBuffer: AVAudioPCMBuffer?
    private var proximityLoopBuffer: AVAudioPCMBuffer?
    private var shimmerLoopBuffer: AVAudioPCMBuffer?
    private var layerLoopBuffers: [AVAudioPCMBuffer?] = [nil, nil, nil, nil]

    private var monoFormat: AVAudioFormat?
    private var started = false
    private var coreAttached = false
    private var gameplayAmbientAttached = false
    private var gameplayLoopsScheduled = false

    private var targetProximityVol: Float = 0
    private var currentProximityVol: Float = 0
    private var targetShimmerVol: Float = 0
    private var currentShimmerVol: Float = 0
    private var targetLayerVols: [Float] = [0, 0, 0, 0]
    private var currentLayerVols: [Float] = [0, 0, 0, 0]
    private var targetLowPassHz: Float = 520
    private var currentLowPassHz: Float = 520

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        attachCoreIfNeeded()
    }

    private func attachCoreIfNeeded() {
        guard !coreAttached else { return }
        coreAttached = true
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        monoFormat = format
        buffer = Self.makeSineBuffer(format: format, hz: 220, frameCount: 1_600, amplitude: 0.18)
        settleBuffer = Self.makeSineBuffer(format: format, hz: 292, frameCount: 2_400, amplitude: 0.12)
        tickBuffer = Self.makeSineBuffer(format: format, hz: 780, frameCount: 380, amplitude: 0.095)
        bloomBuffer = Self.makeBloomBuffer(format: format, frameCount: 14_000, amplitude: 0.13)
        guard buffer != nil else { return }

        engine.attach(mainMixer)
        engine.attach(left)
        engine.attach(right)
        let out = engine.outputNode
        engine.connect(mainMixer, to: out, format: out.inputFormat(forBus: 0))
        engine.connect(left, to: mainMixer, format: format)
        engine.connect(right, to: mainMixer, format: format)
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
    }

    private func attachGameplayAmbientIfNeeded() {
        guard started, let format = monoFormat, !gameplayAmbientAttached else { return }
        gameplayAmbientAttached = true

        if let b = proximityEQ.bands.first {
            b.filterType = .lowPass
            b.frequency = 620
            b.bandwidth = 0.85
            b.bypass = false
        }

        bgmLoopBuffer = Self.makePadLoopBuffer(format: format, frameCount: 88_200)
        proximityLoopBuffer = Self.makeProximityTextureBuffer(format: format, frameCount: 176_400, rootHz: 198)
        shimmerLoopBuffer = Self.makeShimmerLoopBuffer(format: format, frameCount: 88_200)
        let roots: [Float] = [174.62, 220, 261.63, 329.63]
        for i in 0..<4 {
            layerLoopBuffers[i] = Self.makeLayerPadLoop(format: format, frameCount: 110_250, rootHz: roots[i])
        }

        engine.attach(ambientMixer)
        engine.attach(bgmNode)
        engine.attach(proximityNode)
        engine.attach(proximityEQ)
        engine.attach(dragShimmerNode)
        for n in layerNodes { engine.attach(n) }

        engine.connect(ambientMixer, to: mainMixer, format: format)
        engine.connect(bgmNode, to: ambientMixer, format: format)
        engine.connect(proximityNode, to: proximityEQ, format: format)
        engine.connect(proximityEQ, to: ambientMixer, format: format)
        engine.connect(dragShimmerNode, to: ambientMixer, format: format)
        for n in layerNodes {
            engine.connect(n, to: ambientMixer, format: format)
        }

        bgmNode.volume = 0
        proximityNode.volume = 0
        dragShimmerNode.volume = 0
        ambientMixer.volume = 0.92
        for n in layerNodes { n.volume = 0 }
    }

    // MARK: - Gameplay session (layering + proximity)

    func beginGameplaySession(level: LevelDefinition, placedCount: Int) {
        attachCoreIfNeeded()
        attachGameplayAmbientIfNeeded()
        guard let format = monoFormat,
              let bgmB = bgmLoopBuffer,
              let proxB = proximityLoopBuffer,
              let shimB = shimmerLoopBuffer
        else { return }

        let root = Self.proximityRootHz(for: level)
        if abs(root - lastProximityRootHz) > 0.5 {
            lastProximityRootHz = root
            proximityLoopBuffer = Self.makeProximityTextureBuffer(format: format, frameCount: 176_400, rootHz: root)
        }
        let proxBuffer = proximityLoopBuffer ?? proxB

        if !gameplayLoopsScheduled {
            gameplayLoopsScheduled = true
            bgmNode.scheduleBuffer(bgmB, at: nil, options: [.loops], completionHandler: nil)
            proximityNode.scheduleBuffer(proxBuffer, at: nil, options: [.loops], completionHandler: nil)
            dragShimmerNode.scheduleBuffer(shimB, at: nil, options: [.loops], completionHandler: nil)
            for i in 0..<4 {
                if let lb = layerLoopBuffers[i] {
                    layerNodes[i].scheduleBuffer(lb, at: nil, options: [.loops], completionHandler: nil)
                }
            }
            bgmNode.play()
            proximityNode.play()
            dragShimmerNode.play()
            for n in layerNodes { n.play() }
        }

        symphonyTotalPieces = max(1, level.puzzleColumns * level.puzzleRows)
        syncSymphonyLayers(placedCount: placedCount, total: symphonyTotalPieces)
        bgmNode.volume = 0.11
    }

    func endGameplaySession() {
        gameplayLoopsScheduled = false
        targetProximityVol = 0
        currentProximityVol = 0
        targetShimmerVol = 0
        currentShimmerVol = 0
        targetLayerVols = [0, 0, 0, 0]
        currentLayerVols = [0, 0, 0, 0]
        bgmNode.stop()
        proximityNode.stop()
        dragShimmerNode.stop()
        for n in layerNodes { n.stop() }
        bgmNode.volume = 0
        proximityNode.volume = 0
        dragShimmerNode.volume = 0
        for n in layerNodes { n.volume = 0 }
    }

    private var lastProximityRootHz: Float = -1
    private var symphonyTotalPieces: Int = 4

    func syncSymphonyLayers(placedCount: Int, total: Int) {
        let t = max(1, total)
        let f = Float(placedCount) / Float(t)
        let stack = Float(layerNodes.count)
        for i in layerNodes.indices {
            let edge = Float(i) / stack
            let v = max(0, min(1, (f * stack) - edge))
            targetLayerVols[i] = v * 0.24
        }
        smoothGameplayMixStep()
    }

    func celebrateSymphonyFull() {
        for i in layerNodes.indices {
            targetLayerVols[i] = min(0.3, targetLayerVols[i] + 0.06)
        }
        smoothGameplayMixStep()
    }

    /// `focus01`: 1 = sát ô đúng, 0 = xa; `stereoPan` −1…+1.
    func updateDragProximityFocus(focus01: Float, stereoPan: Float, reduceMotion: Bool) {
        let f = reduceMotion ? max(0, focus01) * 0.55 : max(0, min(1, focus01))
        targetProximityVol = powf(f, 1.15) * 0.44
        let lpClosed: Float = 420
        let lpOpen: Float = 14_200
        targetLowPassHz = lpClosed + (lpOpen - lpClosed) * f
        let pan = max(-1, min(1, stereoPan))
        proximityNode.pan = pan * 0.72
        dragShimmerNode.pan = pan * 0.55
        smoothGameplayMixStep()
    }

    func setDragShimmerActive(_ active: Bool, reduceMotion: Bool) {
        targetShimmerVol = (active && !reduceMotion) ? 0.1 : 0
        smoothGameplayMixStep()
    }

    private func smoothGameplayMixStep() {
        let k: Float = 0.38
        currentProximityVol += (targetProximityVol - currentProximityVol) * k
        currentShimmerVol += (targetShimmerVol - currentShimmerVol) * k
        currentLowPassHz += (targetLowPassHz - currentLowPassHz) * k
        proximityNode.volume = currentProximityVol
        dragShimmerNode.volume = currentShimmerVol
        if let b = proximityEQ.bands.first {
            b.frequency = max(200, min(18_000, currentLowPassHz))
        }
        for i in layerNodes.indices {
            currentLayerVols[i] += (targetLayerVols[i] - currentLayerVols[i]) * k
            layerNodes[i].volume = currentLayerVols[i]
        }
    }

    private static func proximityRootHz(for level: LevelDefinition) -> Float {
        switch level.stage {
        case .healingNature: return 185
        case .zenUrban: return 228
        case .cosmicBeyond: return 275
        }
    }

    private static func makePadLoopBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        let sr = Float(format.sampleRate)
        let f1: Float = 82.4
        let f2: Float = 123.47
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let ph = Float(i) / Float(frameCount) * 2 * Float.pi
            let breathe = 0.55 + 0.45 * sin(ph)
            let wobble = sin(2 * Float.pi * 0.07 * t)
            let s = 0.5 * sin(2 * Float.pi * f1 * t) + 0.5 * sin(2 * Float.pi * f2 * t)
            ch[i] = 0.045 * s * breathe * (0.88 + 0.12 * wobble)
        }
        return buf
    }

    private static func makeProximityTextureBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount, rootHz: Float) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        let sr = Float(format.sampleRate)
        let h2 = rootHz * 1.5
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let am = 0.55 + 0.45 * sin(2 * Float.pi * 0.42 * t)
            let wave = sin(2 * Float.pi * rootHz * t) * 0.62 + sin(2 * Float.pi * h2 * t) * 0.28
            let foam = sin(2 * Float.pi * (rootHz * 3.1) * t) * 0.1 * sin(2 * Float.pi * 2.2 * t)
            ch[i] = Float(0.085) * wave * am + foam * 0.04
        }
        return buf
    }

    private static func makeShimmerLoopBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        let sr = Float(format.sampleRate)
        let a: Float = 880
        let b: Float = 1046.5
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let env = 0.5 + 0.5 * sin(2 * Float.pi * Float(i) / Float(frameCount))
            ch[i] = 0.018 * env * (sin(2 * Float.pi * a * t) * 0.55 + sin(2 * Float.pi * b * t) * 0.45)
        }
        return buf
    }

    private static func makeLayerPadLoop(format: AVAudioFormat, frameCount: AVAudioFrameCount, rootHz: Float) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        let sr = Float(format.sampleRate)
        let fifth = rootHz * 1.25
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let ph = Float(i) / Float(frameCount)
            let w = sin(Float.pi * ph)
            let s = 0.58 * sin(2 * Float.pi * rootHz * t) + 0.42 * sin(2 * Float.pi * fifth * t)
            ch[i] = 0.05 * s * w * w
        }
        return buf
    }

    private static func makeSineBuffer(
        format: AVAudioFormat,
        hz: Float,
        frameCount: AVAudioFrameCount,
        amplitude: Float
    ) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        let sr = Float(format.sampleRate)
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let env = Float(i) / Float(frameCount)
            let w = env * (1 - env) * 4
            ch[i] = amplitude * sin(2 * .pi * hz * t) * w
        }
        return buf
    }

    private static func makeBloomBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount, amplitude: Float) -> AVAudioPCMBuffer? {
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buf.frameLength = frameCount
        let ch = buf.floatChannelData![0]
        let sr = Float(format.sampleRate)
        let hz1: Float = 392
        let hz2: Float = 523.25
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sr
            let env = Float(i) / Float(frameCount)
            let w = Float(pow(Double(env * (1 - env) * 4), 1.15))
            let tone = 0.52 * sin(2 * Float.pi * hz1 * t) + 0.48 * sin(2 * Float.pi * hz2 * t)
            ch[i] = amplitude * tone * w
        }
        return buf
    }

    func playTactileAtPan(normalizedX: CGFloat) {
        guard started, let buffer else { return }
        let x = max(0, min(1, Double(normalizedX)))
        left.volume = Float(1 - x) * 0.95
        right.volume = Float(x) * 0.95
        left.stop()
        right.stop()
        left.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        right.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        left.play()
        right.play()
    }

    func playPieceSettleAtPan(normalizedX: CGFloat) {
        guard started, let settleBuffer else { return }
        let x = max(0, min(1, Double(normalizedX)))
        left.volume = Float(1 - x) * 0.38
        right.volume = Float(x) * 0.38
        left.stop()
        right.stop()
        left.scheduleBuffer(settleBuffer, at: nil, options: .interrupts, completionHandler: nil)
        right.scheduleBuffer(settleBuffer, at: nil, options: .interrupts, completionHandler: nil)
        left.play()
        right.play()
    }

    func playRotateClick() {
        guard started, let tickBuffer else { return }
        left.volume = 0.26
        right.volume = 0.26
        left.stop()
        right.stop()
        left.scheduleBuffer(tickBuffer, at: nil, options: .interrupts, completionHandler: nil)
        right.scheduleBuffer(tickBuffer, at: nil, options: .interrupts, completionHandler: nil)
        left.play()
        right.play()
    }

    private func playSnapSettleTail() {
        guard started, let settleBuffer else { return }
        left.volume = 0.22
        right.volume = 0.22
        left.stop()
        right.stop()
        left.scheduleBuffer(settleBuffer, at: nil, options: .interrupts, completionHandler: nil)
        right.scheduleBuffer(settleBuffer, at: nil, options: .interrupts, completionHandler: nil)
        left.play()
        right.play()
    }

    func playSnapLayeredSuccess() {
        playHarmonicChord()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            self.playSnapSettleTail()
        }
    }

    func playBloomChime() {
        guard started, let bloomBuffer else { return }
        left.volume = 0.48
        right.volume = 0.48
        left.stop()
        right.stop()
        left.scheduleBuffer(bloomBuffer, at: nil, options: .interrupts, completionHandler: nil)
        right.scheduleBuffer(bloomBuffer, at: nil, options: .interrupts, completionHandler: nil)
        left.play()
        right.play()
    }

    func playHarmonicChord() {
        guard started, let buffer else { return }
        left.volume = 0.58
        right.volume = 0.58
        left.stop()
        right.stop()
        left.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        right.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        left.play()
        right.play()
    }
}
