import Foundation
import GoogleMobileAds

/// Khởi tạo SDK; unit ID lấy từ `AppConfig` (Debug = test cố định, Release = plist / biến build `ADMOB_*`).
final class AdManager {
    static let shared = AdManager()

    func prepareOnLaunch() {
        #if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["GADSimulatorID"]
        #endif
        MobileAds.shared.start(completionHandler: { _ in
            _ = AppConfig.admobBannerUnitID
            _ = AppConfig.admobInterstitialUnitID
        })
    }

    func presentInterstitialAfterPuzzleIfAllowed() {
        // GADInterstitialAd.load(withAdUnitID: AppConfig.admobInterstitialUnitID, ...)
    }
}
