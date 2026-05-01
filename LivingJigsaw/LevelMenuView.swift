import SwiftUI

struct LevelMenuView: View {
    var onPickLevel: (LevelDefinition) -> Void
    var onClose: () -> Void

    private let rowStride: CGFloat = 128
    private let zigOffset: CGFloat = 82

    var body: some View {
        NavigationStack {
            ZStack {
                NatureBackground(variant: .menu)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        Text(String(localized: "level_map_hint"))
                            .font(.caption)
                            .foregroundStyle(NaturePalette.cream.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 8)

                        GeometryReader { geo in
                            zigzagMap(width: max(geo.size.width, 280))
                                .frame(height: rowStride * CGFloat(LevelDefinition.all.count) + 72)
                        }
                        .frame(height: rowStride * CGFloat(LevelDefinition.all.count) + 72)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 28)
                }
            }
            .foregroundStyle(NaturePalette.cream)
            .navigationTitle(Text(String(localized: "home_level_menu")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(NaturePalette.sunlight)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "home_close_menu")) {
                        HapticsService.playMenuTap()
                        onClose()
                    }
                }
            }
        }
    }

    private func zigzagMap(width: CGFloat) -> some View {
        let levels = LevelDefinition.all.sorted { $0.id < $1.id }
        let centers = nodeCenters(levelCount: levels.count, width: width)
        return ZStack(alignment: .topLeading) {
            pathConnector(points: centers)
                .allowsHitTesting(false)

            ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                let unlocked = GameProgress.isLevelUnlocked(level.id)
                let cleared = GameProgress.isLevelCleared(level.id)
                let isCurrent = level.id == GameProgress.currentLevelId
                Button {
                    guard unlocked else { return }
                    HapticsService.playMenuTap()
                    GameProgress.currentLevelId = level.id
                    onPickLevel(level)
                } label: {
                    levelNodeView(
                        level: level,
                        unlocked: unlocked,
                        cleared: cleared,
                        isCurrent: isCurrent
                    )
                }
                .buttonStyle(.plain)
                .disabled(!unlocked)
                .position(centers[index])
            }
        }
        .frame(width: width, height: rowStride * CGFloat(levels.count) + 72)
    }

    private func nodeCenters(levelCount: Int, width: CGFloat) -> [CGPoint] {
        let midX = width * 0.5
        return (0..<levelCount).map { i in
            let x = midX + (i % 2 == 0 ? -zigOffset : zigOffset)
            let y = CGFloat(i) * rowStride + 58
            return CGPoint(x: x, y: y)
        }
    }

    private func pathConnector(points: [CGPoint]) -> some View {
        Path { p in
            guard points.count > 1 else { return }
            p.move(to: points[0])
            for pt in points.dropFirst() {
                p.addLine(to: pt)
            }
        }
        .stroke(
            NaturePalette.pathLine,
            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round, dash: [10, 8])
        )
    }

    @ViewBuilder
    private func levelNodeView(level: LevelDefinition, unlocked: Bool, cleared: Bool, isCurrent: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: unlocked
                                ? [NaturePalette.mossLight.opacity(0.95), NaturePalette.canopy]
                                : [Color.white.opacity(0.12), NaturePalette.bark.opacity(0.6)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 38
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle()
                            .stroke(
                                cleared ? NaturePalette.goldRing : (isCurrent ? NaturePalette.leaf : NaturePalette.dew.opacity(0.4)),
                                lineWidth: cleared || isCurrent ? 3 : 1.5
                            )
                    )
                    .shadow(color: (isCurrent && unlocked) ? NaturePalette.leaf.opacity(0.55) : .clear, radius: 14, y: 0)
                    .shadow(color: unlocked ? Color.black.opacity(0.35) : .clear, radius: 8, y: 4)

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NaturePalette.cream.opacity(0.35))
                } else if cleared {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(NaturePalette.sunlight, NaturePalette.mossMid)
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.title2)
                        .foregroundStyle(isCurrent ? NaturePalette.sunlight : NaturePalette.leaf)
                }
            }

            Text("\(level.id)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(NaturePalette.cream.opacity(0.5))

            Text(String(localized: String.LocalizationValue(level.titleKey)))
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(unlocked ? NaturePalette.cream.opacity(0.88) : NaturePalette.cream.opacity(0.35))
                .frame(width: 118)
        }
    }
}
