import PhotosUI
import SwiftUI

struct HomeView: View {
    var onPlayCurrent: () -> Void
    var onOpenLevelMenu: () -> Void
    var onPlayUserPickedVideo: (URL) -> Void

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isPreparingUserMedia = false
    @State private var userMediaError: String?
    @State private var shimmerOffset: CGFloat = -200

    private var currentId: Int { GameProgress.currentLevelId }
    private var currentLevel: LevelDefinition { .level(currentId) }

    var body: some View {
        ZStack {
            NatureBackground(variant: .home)

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                
                // Hero Section with animated logo
                heroSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                
                // Current Progress Card
                progressCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                
                // Action Cards Grid
                actionCardsGrid
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                
                Spacer(minLength: 20)
            }
        }
        .foregroundStyle(NaturePalette.cream)
        .overlay {
            if isPreparingUserMedia {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(NaturePalette.goldRing)
                        Text(String(localized: "home_pick_media_preparing"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NaturePalette.cream)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(NaturePalette.luxuryStrokeGradient, lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 30)
                    )
                }
            }
        }
        .alert(
            String(localized: "home_pick_media_failed_title"),
            isPresented: Binding(
                get: { userMediaError != nil },
                set: { if !$0 { userMediaError = nil } }
            )
        ) {
            Button(String(localized: "home_pick_media_ok")) { userMediaError = nil }
        } message: {
            Text(userMediaError ?? "")
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await handlePickedMedia(item) }
        }
        .onAppear {
            startShimmerAnimation()
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Animated Logo Container
            ZStack {
                // Glow rings
                Circle()
                    .stroke(NaturePalette.goldRing.opacity(0.15), lineWidth: 2)
                    .frame(width: 140, height: 140)
                Circle()
                    .stroke(NaturePalette.rosegold.opacity(0.12), lineWidth: 2)
                    .frame(width: 160, height: 160)
                
                // Main logo card
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                NaturePalette.canopy.opacity(0.95),
                                NaturePalette.deepForest.opacity(0.98)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 110, height: 110)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(NaturePalette.heroGradient, lineWidth: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(2)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 20, y: 10)
                    .shadow(color: NaturePalette.goldRing.opacity(0.4), radius: 30, y: 0)
                
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(NaturePalette.heroGradient)
                    .shadow(color: NaturePalette.champagne.opacity(0.6), radius: 12)
            }
            
            // Brand badge
            Text("DUNA")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .kerning(4)
                .foregroundStyle(NaturePalette.pearl)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    NaturePalette.obsidian.opacity(0.9),
                                    NaturePalette.bark.opacity(0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(NaturePalette.goldRing.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                )
            
            // Title
            Text(String(localized: "splash_title"))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(0.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [NaturePalette.pearl, NaturePalette.champagne, NaturePalette.rosegold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: NaturePalette.goldRing.opacity(0.5), radius: 20, y: 4)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
            
            // Tagline
            Text(String(localized: "splash_tagline"))
                .font(.callout.weight(.medium))
                .foregroundStyle(NaturePalette.champagne.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Progress Card
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(NaturePalette.emerald)
                Text(String(localized: "home_progress_label"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NaturePalette.cream.opacity(0.9))
                    .textCase(.uppercase)
                    .kerning(1)
                Spacer()
                Text("\(currentId)/10")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NaturePalette.goldRing)
            }
            
            Divider()
                .overlay(NaturePalette.luxuryStrokeGradient.opacity(0.3))
            
            Text(String(localized: String.LocalizationValue(currentLevel.titleKey)))
                .font(.title3.weight(.bold))
                .foregroundStyle(NaturePalette.pearl)
                .lineLimit(2)
            
            Text(String(localized: String.LocalizationValue(currentLevel.subtitleKey)))
                .font(.caption)
                .foregroundStyle(NaturePalette.cream.opacity(0.65))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NaturePalette.premiumCardBackground)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.3))
                LuxuryGlassPanel(
                    shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                    lineWidth: 1.5
                )
            }
        )
        .overlay(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NaturePalette.accentShimmer)
                    .frame(width: 100)
                    .offset(x: shimmerOffset)
                    .mask(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
            }
            .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .shadow(color: NaturePalette.goldRing.opacity(0.2), radius: 24)
    }
    
    // MARK: - Action Cards Grid
    private var actionCardsGrid: some View {
        VStack(spacing: 14) {
            // Primary action - Play Now
            ActionCard(
                icon: "play.fill",
                title: String(localized: "home_play_now"),
                gradient: NaturePalette.heroGradient,
                isPrimary: true
            ) {
                HapticsService.playMenuTap()
                onPlayCurrent()
            }
            
            HStack(spacing: 14) {
                // Level Menu
                ActionCard(
                    icon: "map.fill",
                    title: String(localized: "home_level_menu"),
                    gradient: LinearGradient(
                        colors: [NaturePalette.emerald, NaturePalette.leaf],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    isPrimary: false
                ) {
                    HapticsService.playMenuTap()
                    onOpenLevelMenu()
                }
                
                // Media Picker
                PhotosPicker(
                    selection: $photoPickerItem,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    ActionCardContent(
                        icon: "photo.on.rectangle.angled",
                        title: String(localized: "home_pick_media"),
                        gradient: LinearGradient(
                            colors: [NaturePalette.sapphire, NaturePalette.dew],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        isPrimary: false
                    )
                }
                .disabled(isPreparingUserMedia)
            }
        }
    }

    @MainActor
    private func handlePickedMedia(_ item: PhotosPickerItem) async {
        isPreparingUserMedia = true
        defer {
            isPreparingUserMedia = false
            photoPickerItem = nil
        }
        do {
            let url = try await LibraryPickedMediaExporter.exportToTempVideoURL(from: item)
            HapticsService.playMenuTap()
            onPlayUserPickedVideo(url)
        } catch {
            userMediaError = error.localizedDescription
        }
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            .linear(duration: 3)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = UIScreen.main.bounds.width + 200
        }
    }
}

// MARK: - Action Card Component
struct ActionCard: View {
    let icon: String
    let title: String
    let gradient: LinearGradient
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            ActionCardContent(
                icon: icon,
                title: title,
                gradient: gradient,
                isPrimary: isPrimary
            )
        }
        .buttonStyle(ActionCardButtonStyle(isPrimary: isPrimary))
    }
}

struct ActionCardContent: View {
    let icon: String
    let title: String
    let gradient: LinearGradient
    let isPrimary: Bool
    
    var body: some View {
        VStack(spacing: isPrimary ? 12 : 10) {
            ZStack {
                Circle()
                    .fill(gradient.opacity(0.2))
                    .frame(width: isPrimary ? 70 : 56, height: isPrimary ? 70 : 56)
                
                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 32 : 24, weight: .semibold))
                    .foregroundStyle(gradient)
                    .shadow(color: .white.opacity(0.3), radius: 8)
            }
            
            Text(title)
                .font(isPrimary ? .headline.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(NaturePalette.pearl)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isPrimary ? 24 : 20)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                if isPrimary {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(NaturePalette.premiumCardBackground)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    NaturePalette.obsidian.opacity(0.7),
                                    NaturePalette.deepForest.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.25))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(gradient.opacity(isPrimary ? 1.0 : 0.6), lineWidth: isPrimary ? 2 : 1.5)
                if isPrimary {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .padding(1.5)
                }
            }
        )
        .shadow(
            color: .black.opacity(isPrimary ? 0.5 : 0.35),
            radius: isPrimary ? 20 : 12,
            y: isPrimary ? 10 : 6
        )
        .shadow(
            color: isPrimary ? NaturePalette.goldRing.opacity(0.3) : Color.clear,
            radius: 24
        )
    }
}

struct ActionCardButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

