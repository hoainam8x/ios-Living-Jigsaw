import SwiftUI
import UIKit

/// The Astral Path — bản đồ level: UICollectionView + Compositional Layout, parallax, preview video tại tâm, nền nội suy màu, Glow Path (UIKit).
struct LevelSelectionView: View {
    var onPickLevel: (LevelDefinition) -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AstralLevelSelectionRepresentable(onPickLevel: onPickLevel)
                    .ignoresSafeArea(edges: .bottom)
            }
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
}

private struct AstralLevelSelectionRepresentable: UIViewControllerRepresentable {
    var onPickLevel: (LevelDefinition) -> Void

    func makeUIViewController(context: Context) -> AstralLevelSelectionViewController {
        let vc = AstralLevelSelectionViewController()
        vc.onPickLevel = onPickLevel
        return vc
    }

    func updateUIViewController(_ uiViewController: AstralLevelSelectionViewController, context: Context) {}
}

/// Giữ tên cũ cho call site nếu cần.
typealias LevelMenuView = LevelSelectionView
