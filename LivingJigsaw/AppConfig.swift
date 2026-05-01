import Foundation

enum AppConfig {
    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif

    /// Replace via Remote Config / backend later; test IDs are safe placeholders.
    static var admobBannerUnitID: String {
        UserDefaults.standard.string(forKey: "admob_banner_unit_id")
            ?? "ca-app-pub-3940256099942544/2934735716"
    }

    static var admobInterstitialUnitID: String {
        UserDefaults.standard.string(forKey: "admob_interstitial_unit_id")
            ?? "ca-app-pub-3940256099942544/4411468910"
    }
}
