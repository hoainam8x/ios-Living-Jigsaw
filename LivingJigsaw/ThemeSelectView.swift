import SwiftUI

struct ThemeSelectView: View {
    var onPick: (PuzzleTheme) -> Void
    @EnvironmentObject private var vocal: VocalAIService

    var body: some View {
        ZStack {
            NatureBackground(variant: .menu)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(String(localized: "theme_select_title"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(NaturePalette.titleLuxuryGradient)
                        .shadow(color: NaturePalette.goldRing.opacity(0.2), radius: 16, y: 2)
                        .padding(.top, 20)
                    Text(String(localized: "theme_select_hint"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NaturePalette.cream.opacity(0.68))
                        .accessibilityHint(Text(String(localized: "theme_select_hint")))

                    ForEach(PuzzleTheme.all) { theme in
                        Button {
                            onPick(theme)
                        } label: {
                            ZStack {
                                LuxuryGlassPanel(shape: RoundedRectangle(cornerRadius: 22, style: .continuous), lineWidth: 1.05)
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.black.opacity(0.08))
                                    .padding(2)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(String(localized: String.LocalizationValue(theme.localizedNameKey())))
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(NaturePalette.cream)
                                    Text(String(localized: String.LocalizationValue(theme.localizedDescriptionKey())))
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(NaturePalette.platinum.opacity(0.75))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(20)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(String(localized: String.LocalizationValue(theme.localizedNameKey()))))
                        .accessibilityHint(Text(String(localized: String.LocalizationValue(theme.localizedDescriptionKey()))))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .foregroundStyle(NaturePalette.cream)
        .navigationTitle("")
        .onAppear { vocal.speak("theme_select_hint") }
    }
}
