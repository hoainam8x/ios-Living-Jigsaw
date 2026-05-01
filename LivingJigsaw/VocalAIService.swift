import AVFoundation
import Combine
import SwiftUI

@MainActor
final class VocalAIService: ObservableObject {
    private let synth = AVSpeechSynthesizer()

    func speak(_ key: String) {
        let utterance = AVSpeechUtterance(string: String(localized: String.LocalizationValue(key)))
        utterance.voice = AVSpeechSynthesisVoice(language: preferredVoiceLanguage())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    private func preferredVoiceLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.lowercased().hasPrefix("vi") { return "vi-VN" }
        return "en-US"
    }
}
