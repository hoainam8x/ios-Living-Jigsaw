import SwiftUI

struct RootView: View {
    enum Phase: Hashable {
        case home
        case levelMenu
        case play(LevelDefinition)
        case bloom(LevelDefinition)
    }

    @State private var phase: Phase = .home
    @StateObject private var gameAudio = SpatialAmbientAudio()

    var body: some View {
        Group {
            switch phase {
            case .home:
                HomeView(
                    onPlayCurrent: { phase = .play(.level(GameProgress.currentLevelId)) },
                    onOpenLevelMenu: { phase = .levelMenu }
                )
            case .levelMenu:
                LevelMenuView(
                    onPickLevel: { level in
                        phase = .play(level)
                    },
                    onClose: { phase = .home }
                )
            case .play(let level):
                NavigationStack {
                    GameplayView(
                        level: level,
                        onComplete: { phase = .bloom(level) },
                        onLeave: { phase = .home }
                    )
                    .environmentObject(gameAudio)
                    .toolbarBackground(NaturePalette.deepForest.opacity(0.92), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .tint(NaturePalette.sunlight)
                }
            case .bloom(let level):
                BloomCompletionView(level: level) {
                    GameProgress.markCompleted(levelId: level.id)
                    phase = .home
                }
                .environmentObject(gameAudio)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: phase)
    }
}
