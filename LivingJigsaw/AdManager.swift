import Foundation

/// Zero‑footprint hook: wire `GoogleMobileAds` + Remote Config IDs in a future change set.
final class AdManager {
    static let shared = AdManager()

    func prepareOnLaunch() {
        _ = AppConfig.admobBannerUnitID
        _ = AppConfig.admobInterstitialUnitID
    }

    func presentInterstitialAfterPuzzleIfAllowed() {
        guard !AppConfig.isDebugBuild else { return }
        // GADInterstitialAd.load(withAdUnitID: AppConfig.admobInterstitialUnitID, ...)
    }
}
