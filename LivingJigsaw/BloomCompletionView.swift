import SwiftUI

struct BloomCompletionView: View {
    let level: LevelDefinition
    var onFinished: () -> Void
    @EnvironmentObject private var spatial: SpatialAmbientAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            NatureBackground(variant: .home)
            Color.black.opacity(0.42).ignoresSafeArea()

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

            VStack(spacing: 18) {
                Spacer()
                Text(String(localized: "bloom_title"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NaturePalette.titleLuxuryGradient)
                    .shadow(color: NaturePalette.goldRing.opacity(0.35), radius: 18, y: 2)
                    .padding(.horizontal, 18)
                Capsule()
                    .fill(NaturePalette.luxuryStrokeGradient.opacity(0.55))
                    .frame(width: 200, height: 2)
                    .shadow(color: NaturePalette.champagne.opacity(0.4), radius: 6)
                Text(String(localized: "splash_tagline"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(NaturePalette.cream.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                Button(action: {
                    HapticsService.playMenuTap()
                    onFinished()
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
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = 1.06
            }
        }
    }
}
