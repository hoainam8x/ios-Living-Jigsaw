import CoreHaptics
import UIKit

enum HapticsService {
    private static var engine: CHHapticEngine?

    static func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    /// Near‑match while dragging (soft / light).
    static func playProximitySoft() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [intensity, sharpness],
                    relativeTime: 0
                )
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
            }
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        }
    }

    /// Mỗi lần xoay mảnh (nhẹ).
    static func playPieceRotate() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.65)
    }

    /// Mảnh chạm bàn khi intro rơi.
    static func playPieceSettle() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.26)
    }

    /// Gần đúng nhưng sai hướng / khớp từ chối nhẹ.
    static func playSnapReject() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.34)
    }

    /// Nút menu / chọn level.
    static func playMenuTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.42)
    }

    /// Màn bloom mở.
    static func playBloomReveal() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.48)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.52)
        }
    }

    /// Successful snap (rigid / decisive).
    static func playSnapRigid() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95)
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [intensity, sharpness],
                    relativeTime: 0
                )
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
            }
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
    }
}
