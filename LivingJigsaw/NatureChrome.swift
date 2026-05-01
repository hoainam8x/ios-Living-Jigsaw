import SwiftUI

/// Bảng màu & khối UI dùng chung — thiên nhiên + accent luxury (champagne, viền vàng).
enum NaturePalette {
    static let deepForest = Color(red: 0.06, green: 0.12, blue: 0.08)
    static let canopy = Color(red: 0.11, green: 0.24, blue: 0.13)
    static let mossMid = Color(red: 0.20, green: 0.40, blue: 0.22)
    static let mossLight = Color(red: 0.30, green: 0.52, blue: 0.28)
    static let soil = Color(red: 0.24, green: 0.14, blue: 0.09)
    static let sunlight = Color(red: 0.98, green: 0.88, blue: 0.38)
    static let sunlightDeep = Color(red: 0.88, green: 0.52, blue: 0.16)
    static let leaf = Color(red: 0.48, green: 0.90, blue: 0.46)
    static let dew = Color(red: 0.52, green: 0.82, blue: 0.78)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let bark = Color(red: 0.10, green: 0.07, blue: 0.05)
    static let goldRing = Color(red: 0.92, green: 0.74, blue: 0.28)
    static let champagne = Color(red: 0.94, green: 0.90, blue: 0.78)
    static let platinum = Color(red: 0.72, green: 0.78, blue: 0.80)

    static let homeSkyGradient = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.08, blue: 0.09),
            Color(red: 0.06, green: 0.14, blue: 0.11),
            Color(red: 0.12, green: 0.28, blue: 0.16),
            Color(red: 0.18, green: 0.34, blue: 0.18),
            Color(red: 0.10, green: 0.20, blue: 0.12),
            Color(red: 0.05, green: 0.10, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunButtonGradient = LinearGradient(
        colors: [champagne, sunlight, sunlightDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let luxuryStrokeGradient = LinearGradient(
        colors: [champagne.opacity(0.95), goldRing, sunlightDeep.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gameplayBackdrop = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.08, blue: 0.06),
            Color(red: 0.02, green: 0.045, blue: 0.04),
            Color(red: 0.015, green: 0.03, blue: 0.028)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pathLine = LinearGradient(
        colors: [
            champagne.opacity(0.45),
            mossLight.opacity(0.5),
            dew.opacity(0.4),
            goldRing.opacity(0.35)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let titleLuxuryGradient = LinearGradient(
        colors: [cream, champagne, dew],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct NatureBackground: View {
    var variant: Variant = .home

    enum Variant {
        case home
        case menu
        case gameplayDim
    }

    var body: some View {
        ZStack {
            switch variant {
            case .home:
                NaturePalette.homeSkyGradient
                luxuryVignette(intensity: 0.38)
                leafMotes(opacity: 0.065)
            case .menu:
                NaturePalette.homeSkyGradient
                luxuryVignette(intensity: 0.34)
                leafMotes(opacity: 0.08)
            case .gameplayDim:
                NaturePalette.gameplayBackdrop
                luxuryVignette(intensity: 0.52)
                leafMotes(opacity: 0.035)
            }
        }
        .ignoresSafeArea()
    }

    private func luxuryVignette(intensity: Double) -> some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height) * 0.92
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(intensity * 0.35),
                    Color.black.opacity(intensity)
                ],
                center: .center,
                startRadius: geo.size.height * 0.12,
                endRadius: r
            )
        }
        .allowsHitTesting(false)
    }

    private func leafMotes(opacity: Double) -> some View {
        GeometryReader { geo in
            let pairs: [(CGFloat, CGFloat, CGFloat, Double)] = [
                (0.08, 0.12, 18, 0.25), (0.88, 0.08, 22, 0.35), (0.15, 0.38, 16, 0.2),
                (0.92, 0.42, 20, 0.3), (0.22, 0.62, 14, 0.18), (0.78, 0.68, 24, 0.28),
                (0.5, 0.18, 12, 0.15), (0.42, 0.88, 18, 0.22), (0.65, 0.48, 15, 0.2),
                (0.12, 0.82, 20, 0.25), (0.85, 0.88, 16, 0.2), (0.55, 0.72, 22, 0.26)
            ]
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, p in
                Image(systemName: "leaf.fill")
                    .font(.system(size: p.2))
                    .foregroundStyle(NaturePalette.cream.opacity(opacity * p.3))
                    .rotationEffect(.degrees(Double(p.0 * 400 + p.1 * 200)))
                    .position(x: p.0 * geo.size.width, y: p.1 * geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}

struct NaturePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let corner: CGFloat = 20
        return configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(NaturePalette.bark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(NaturePalette.sunButtonGradient)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(configuration.isPressed ? 0.12 : 0.28),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(NaturePalette.luxuryStrokeGradient, lineWidth: 1.25)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 10, y: 6)
            .shadow(color: NaturePalette.goldRing.opacity(configuration.isPressed ? 0.2 : 0.42), radius: 18, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct NatureSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let corner: CGFloat = 20
        return configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NaturePalette.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.05))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(NaturePalette.luxuryStrokeGradient.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

/// Khối kính mờ + viền vàng — card / hint.
struct LuxuryGlassPanel<S: Shape>: View {
    var shape: S
    var lineWidth: CGFloat = 1

    var body: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.stroke(NaturePalette.luxuryStrokeGradient.opacity(0.65), lineWidth: lineWidth)
        }
    }
}

struct NatureSoilFooter: View {
    var body: some View {
        LinearGradient(
            colors: [
                NaturePalette.mossMid.opacity(0.35),
                NaturePalette.soil.opacity(0.92),
                NaturePalette.bark.opacity(0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            LinearGradient(
                colors: [NaturePalette.goldRing.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8),
            alignment: .top
        )
        .frame(height: 28)
    }
}
