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

/// Vùng đáy gameplay: banner trong khối ultra‑thin material + nút ẩn tạm thời.
struct GameplayAdBannerSlot: View {
    @Binding var isSuppressed: Bool

    var body: some View {
        let unit = AppConfig.admobBannerUnitID.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSuppressed {
            Button {
                withAnimation(.easeInOut(duration: 0.28)) {
                    isSuppressed = false
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NaturePalette.champagne.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(NaturePalette.champagne.opacity(0.22), lineWidth: 0.75)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "gameplay_banner_show_a11y")))
        } else if unit.isEmpty {
            AccessibilityBannerSlot()
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NaturePalette.champagne.opacity(0.18), lineWidth: 0.75)
                }
        } else {
            let adSize = adSizeFor(cgSize: CGSize(width: 320, height: 50))
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NaturePalette.champagne.opacity(0.2), lineWidth: 0.75)
                    }
                VStack(spacing: 0) {
                    Color.clear.frame(height: 4)
                    AdMobAnchoredBannerRepresentable(adUnitID: unit)
                        .frame(width: adSize.size.width, height: adSize.size.height)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        isSuppressed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NaturePalette.cream.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .padding(.trailing, 4)
                .accessibilityLabel(Text(String(localized: "gameplay_banner_hide_a11y")))
            }
        }
    }
}
