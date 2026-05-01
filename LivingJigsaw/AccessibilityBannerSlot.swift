import SwiftUI

/// Banner safe‑zone placeholder with accessibility advertising semantics.
struct AccessibilityBannerSlot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NaturePalette.bark.opacity(0.65))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NaturePalette.mossLight.opacity(0.35), lineWidth: 1)
            Text(String(localized: "ad_banner_label"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(NaturePalette.cream.opacity(0.55))
        }
        .frame(height: 50)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "ad_banner_label")))
        .accessibilityAddTraits(.isStaticText)
    }
}
