import Foundation

/// AdMob: **Debug** luôn unit test Google. **Release** lấy từ Info.plist (điền qua biến build `ADMOB_*` trong Xcode → Target → Build Settings).
/// Khi lên App Store: chỉ sửa **Release** `ADMOB_APP_ID`, `ADMOB_BANNER_UNIT_ID`, `ADMOB_INTERSTITIAL_UNIT_ID` — không đổi Swift.
enum AppConfig {
    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif

    /// Unit test anchored adaptive (Google khuyến nghị cho dev).
    private static let admobTestBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    private static let admobTestInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    static var admobBannerUnitID: String {
        if let o = UserDefaults.standard.string(forKey: "admob_banner_unit_id"), !o.isEmpty { return o }
        #if DEBUG
        return admobTestBannerUnitID
        #else
        return (Bundle.main.object(forInfoDictionaryKey: "AdMobBannerUnitID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            .flatMap { $0.isEmpty ? nil : $0 } ?? ""
        #endif
    }

    static var admobInterstitialUnitID: String {
        if let o = UserDefaults.standard.string(forKey: "admob_interstitial_unit_id"), !o.isEmpty { return o }
        #if DEBUG
        return admobTestInterstitialUnitID
        #else
        return (Bundle.main.object(forInfoDictionaryKey: "AdMobInterstitialUnitID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            .flatMap { $0.isEmpty ? nil : $0 } ?? ""
        #endif
    }
}
