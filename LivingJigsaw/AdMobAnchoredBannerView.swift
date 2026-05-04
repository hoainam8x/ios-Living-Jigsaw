import GoogleMobileAds
import SwiftUI
import UIKit

extension UIApplication {
    /// `BannerView` cần `rootViewController` để tải / present quảng cáo.
    static var livingJigsawKeyRootViewController: UIViewController? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?
            .windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

/// Banner cố định **320×50** (chuẩn nhỏ — [fixed size](https://developers.google.com/admob/ios/banner/fixed-size)).
private struct AdMobAnchoredBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    private static var standardBannerAdSize: AdSize {
        adSizeFor(cgSize: CGSize(width: 320, height: 50))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.standardBannerAdSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.livingJigsawKeyRootViewController
        banner.clipsToBounds = true
        banner.isUserInteractionEnabled = true
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.rootViewController = UIApplication.livingJigsawKeyRootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("AdMob banner:", error.localizedDescription)
            #endif
        }
    }
}

/// Vùng đáy gameplay: banner thật hoặc placeholder khi chưa có unit ID.
struct GameplayAdBannerSlot: View {
    var body: some View {
        let unit = AppConfig.admobBannerUnitID.trimmingCharacters(in: .whitespacesAndNewlines)
        if unit.isEmpty {
            AccessibilityBannerSlot()
        } else {
            let adSize = adSizeFor(cgSize: CGSize(width: 320, height: 50))
            AdMobAnchoredBannerRepresentable(adUnitID: unit)
                .frame(width: adSize.size.width, height: adSize.size.height)
        }
    }
}
