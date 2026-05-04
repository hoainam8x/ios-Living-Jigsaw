import CoreHaptics
import UIKit

enum HapticsService {
    private static var engine: CHHapticEngine?
    private static let magneticLight = UIImpactFeedbackGenerator(style: .light)
    private static let magneticSoft = UIImpactFeedbackGenerator(style: .soft)
    private static let snapHeavy = UIImpactFeedbackGenerator(style: .heavy)

    static func prepare() {
        magneticLight.prepare()
        magneticSoft.prepare()
        snapHeavy.prepare()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    /// Nhịp nam châm cực nhẹ / nhanh khi kéo trong vùng lân cận ô đúng (`UIImpactFeedbackGenerator`).
    static func playMagneticMicroPulse(intensity: CGFloat) {
        let u = max(0.06, min(0.42, intensity))
        magneticLight.prepare()
        magneticLight.impactOccurred(intensity: u)
    }

    /// Near‑match while dragging (soft / light) — một nhịp vào vùng nóng (tùy chọn).
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
                magneticSoft.impactOccurred(intensity: 0.55)
            }
        } else {
            magneticSoft.impactOccurred(intensity: 0.55)
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

    /// Khớp mảnh — một nhịp mạnh, dứt khoát (`.heavy`).
    static func playSnapMatchHeavy() {
        snapHeavy.prepare()
        snapHeavy.impactOccurred(intensity: 1.0)
    }

    /// Successful snap (legacy rigid — giữ làm lớp phụ nếu Core Haptics có).
    static func playSnapRigid() {
        playSnapMatchHeavy()
    }
}
