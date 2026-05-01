import SwiftUI

struct HomeView: View {
    var onPlayCurrent: () -> Void
    var onOpenLevelMenu: () -> Void

    private var currentId: Int { GameProgress.currentLevelId }
    private var currentLevel: LevelDefinition { .level(currentId) }

    var body: some View {
        ZStack(alignment: .bottom) {
            NatureBackground(variant: .home)

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [NaturePalette.canopy.opacity(0.9), NaturePalette.deepForest],
                                center: .center,
                                startRadius: 8,
                                endRadius: 64
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(NaturePalette.luxuryStrokeGradient.opacity(0.85), lineWidth: 1.5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(NaturePalette.leaf.opacity(0.35), lineWidth: 3)
                                .blur(radius: 4)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 16, y: 8)
                        .shadow(color: NaturePalette.goldRing.opacity(0.35), radius: 22, y: 0)
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(NaturePalette.sunButtonGradient)
                        .shadow(color: NaturePalette.champagne.opacity(0.4), radius: 8)
                }
                .padding(.bottom, 16)

                Text("DUNA")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .kerning(3)
                    .foregroundStyle(NaturePalette.cream.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(NaturePalette.bark.opacity(0.85))
                            .overlay(Capsule().stroke(NaturePalette.mossLight.opacity(0.4), lineWidth: 1))
                    )
                    .padding(.bottom, 10)

                Text(String(localized: "splash_title"))
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NaturePalette.titleLuxuryGradient)
                    .shadow(color: NaturePalette.mossLight.opacity(0.4), radius: 16, y: 3)
                    .shadow(color: NaturePalette.goldRing.opacity(0.22), radius: 24, y: 0)
                    .padding(.horizontal, 16)

                Text(String(localized: "splash_tagline"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NaturePalette.cream.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                progressCapsule
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    Button(action: {
                        HapticsService.playMenuTap()
                        onPlayCurrent()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text(String(localized: "home_play_now"))
                        }
                    }
                    .buttonStyle(NaturePrimaryButtonStyle())

                    Button(action: {
                        HapticsService.playMenuTap()
                        onOpenLevelMenu()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "map.fill")
                            Text(String(localized: "home_level_menu"))
                        }
                    }
                    .buttonStyle(NatureSecondaryButtonStyle())
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)

                NatureSoilFooter()
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(NaturePalette.cream)
    }

    private var progressCapsule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(NaturePalette.leaf)
                Text(String(localized: "home_progress_label"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NaturePalette.cream.opacity(0.85))
            }
            Text(String(localized: String.LocalizationValue(currentLevel.titleKey)))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NaturePalette.sunlight)
                .lineLimit(2)
            Text(String(localized: String.LocalizationValue(currentLevel.subtitleKey)))
                .font(.caption2)
                .foregroundStyle(NaturePalette.cream.opacity(0.55))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.2))
                LuxuryGlassPanel(shape: RoundedRectangle(cornerRadius: 22, style: .continuous), lineWidth: 1.1)
            }
        )
    }
}
