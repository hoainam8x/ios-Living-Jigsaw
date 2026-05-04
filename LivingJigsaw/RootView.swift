import QuartzCore
import SwiftUI
import UIKit

struct RootView: View {
    enum Phase: Hashable {
        case home
        case levelMenu
        /// `userLibraryVideoURL`: file temp từ ảnh thư viện / video đã chọn.
        case play(level: LevelDefinition, userLibraryVideoURL: URL?)
    }

    @State private var phase: Phase = .home
    @StateObject private var gameAudio = SpatialAmbientAudio()

    var body: some View {
        RootCATransitionHost(phase: $phase, gameAudio: gameAudio)
            .ignoresSafeArea()
    }
}

// MARK: - CATransition (fade 0.4s)

private struct RootCATransitionHost: UIViewControllerRepresentable {
    @Binding var phase: RootView.Phase
    @ObservedObject var gameAudio: SpatialAmbientAudio

    func makeUIViewController(context: Context) -> RootTransitionViewController {
        let vc = RootTransitionViewController()
        vc.applyPhase(phase, gameAudio: gameAudio, binding: $phase, animated: false)
        return vc
    }

    func updateUIViewController(_ uiView: RootTransitionViewController, context: Context) {
        uiView.applyPhase(phase, gameAudio: gameAudio, binding: $phase, animated: true)
    }
}

private final class RootTransitionViewController: UIViewController {
    private var hosting: UIHostingController<AnyView>?
    private var lastPhase: RootView.Phase?

    func applyPhase(
        _ phase: RootView.Phase,
        gameAudio: SpatialAmbientAudio,
        binding: Binding<RootView.Phase>,
        animated: Bool
    ) {
        let content = AnyView(
            RootPhaseSwitch(phase: binding, gameAudio: gameAudio)
        )
        if hosting == nil {
            lastPhase = phase
            let hc = UIHostingController(rootView: content)
            hc.view.backgroundColor = .clear
            addChild(hc)
            view.addSubview(hc.view)
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hc.view.topAnchor.constraint(equalTo: view.topAnchor),
                hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hc.didMove(toParent: self)
            hosting = hc
            return
        }
        guard lastPhase != phase else { return }
        lastPhase = phase
        let next = UIHostingController(rootView: content)
        next.view.backgroundColor = .clear
        if animated {
            let t = CATransition()
            t.duration = 0.4
            t.type = .fade
            t.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer.add(t, forKey: "root_phase_fade")
        }
        if let old = hosting {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        addChild(next)
        view.addSubview(next.view)
        next.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            next.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            next.view.topAnchor.constraint(equalTo: view.topAnchor),
            next.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        next.didMove(toParent: self)
        hosting = next
    }
}

private struct RootPhaseSwitch: View {
    @Binding var phase: RootView.Phase
    @ObservedObject var gameAudio: SpatialAmbientAudio

    var body: some View {
        switch phase {
        case .home:
            HomeView(
                onPlayCurrent: { phase = .play(level: .level(GameProgress.currentLevelId), userLibraryVideoURL: nil) },
                onOpenLevelMenu: { phase = .levelMenu },
                onPlayUserPickedVideo: { url in
                    phase = .play(level: .level(GameProgress.currentLevelId), userLibraryVideoURL: url)
                }
            )
        case .levelMenu:
            LevelSelectionView(
                onPickLevel: { level in
                    phase = .play(level: level, userLibraryVideoURL: nil)
                },
                onClose: { phase = .home }
            )
        case .play(let level, let userLibraryVideoURL):
            NavigationStack {
                GameplayView(
                    level: level,
                    userPickedLibraryVideoURL: userLibraryVideoURL,
                    advanceProgressWhenCompleted: userLibraryVideoURL == nil,
                    onComplete: { phase = .home },
                    onLeave: { phase = .home }
                )
                .environmentObject(gameAudio)
                .toolbarBackground(NaturePalette.deepForest.opacity(0.92), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .tint(NaturePalette.sunlight)
            }
        }
    }
}
