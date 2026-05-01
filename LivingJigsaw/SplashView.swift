import SwiftUI

struct SplashView: View {
    var onContinue: () -> Void
    @EnvironmentObject private var vocal: VocalAIService

    var body: some View {
        ZStack {
            NatureBackground(variant: .home)
            VStack(spacing: 24) {
                Text("DUNA")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .kerning(6)
                    .foregroundStyle(NaturePalette.sunButtonGradient)
                    .shadow(color: NaturePalette.goldRing.opacity(0.45), radius: 20, y: 0)
                Text(String(localized: "splash_sub"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NaturePalette.platinum.opacity(0.72))
                Text(String(localized: "splash_title"))
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(NaturePalette.titleLuxuryGradient)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Text(String(localized: "splash_tagline"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(NaturePalette.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                Spacer()
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text(String(localized: "continue_action"))
                    }
                }
                .buttonStyle(NaturePrimaryButtonStyle())
                .padding(.horizontal, 26)
                .padding(.bottom, 36)
            }
            .foregroundStyle(NaturePalette.cream)
        }
        .onAppear { vocal.speak("splash_vocal") }
    }
}
