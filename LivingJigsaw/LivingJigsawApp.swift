import SwiftUI

@main
struct LivingJigsawApp: App {
    @StateObject private var vocal = VocalAIService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vocal)
                .preferredColorScheme(.dark)
                .tint(NaturePalette.sunlight)
                .onAppear {
                    AdManager.shared.prepareOnLaunch()
                }
        }
    }
}
