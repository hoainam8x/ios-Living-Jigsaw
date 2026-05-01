import AVFoundation
import Foundation

/// Âm thanh nhẹ (ambient): pan theo X, tiếng mảnh rơi, xoay, snap, màn bloom.
@MainActor
final class SpatialAmbientAudio: ObservableObject {
    private let engine = AVAudioEngine()
    private let left = AVAudioPlayerNode()
    private let right = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var settleBuffer: AVAudioPCMBuffer?
    private var tickBuffer: AVAudioPCMBuffer?
    private var bloomBuffer: AVAudioPCMBuffer?
    private var started = false

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        attachIfNeeded()
    }

    private func attachIfNeeded() {
        guard settleBuffer == nil else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        buffer = Self.makeSineBuffer(format: format, hz: 220, frameCount: 1_600, amplitude: 0.18)
        settleBuffer = Self.makeSineBuffer(format: format, hz: 292, frameCount: 2_400, amplitude: 0.12)
        tickBuffer = Self.makeSineBuffer(format: format, hz: 780, frameCount: 380, amplitude: 0.095)
        bloomBuffer = Self.makeBloomBuffer(format: format, frameCount: 14_000, amplitude: 0.13)
        guard buffer != nil else { return }

        engine.attach(left)
        engine.attach(right)
        let main = engine.mainMixerNode
        engine.connect(left, to: main, format: format)
        engine.connect(right, to: main, format: format)
        do {
            try engine.start()
            started = true
        } catch {
            started = false
        }
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
            let tone = 0.52 * sin(2 * .pi * hz1 * t) + 0.48 * sin(2 * .pi * hz2 * t)
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

    /// Mảnh vừa “chạm” bàn khi intro / nhẹ khi snap phụ.
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

    /// Tiếng gỗ / click khi xoay hoặc khớp sai hướng.
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

    /// Snap đúng — hợp âm + vang ngắn.
    func playSnapLayeredSuccess() {
        playHarmonicChord()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard self.started, let settleBuffer = self.settleBuffer else { return }
            self.left.volume = 0.22
            self.right.volume = 0.22
            self.left.stop()
            self.right.stop()
            self.left.scheduleBuffer(settleBuffer, at: nil, options: .interrupts, completionHandler: nil)
            self.right.scheduleBuffer(settleBuffer, at: nil, options: .interrupts, completionHandler: nil)
            self.left.play()
            self.right.play()
        }
    }

    /// Màn hoàn thành bloom.
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

    /// “Harmonic match” — snap chính.
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
