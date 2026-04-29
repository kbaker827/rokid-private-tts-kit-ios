import AVFoundation

struct VoiceOption: Identifiable {
    let id: String       // AVSpeechSynthesisVoice.identifier
    let name: String
    let language: String
    let quality: String
}

enum VoiceRegistry {
    static func availableVoices() -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices().map { v in
            VoiceOption(
                id: v.identifier,
                name: v.name,
                language: v.language,
                quality: qualityLabel(v.quality)
            )
        }.sorted { $0.language < $1.language }
    }

    static func defaultVoice() -> VoiceOption? {
        availableVoices().first { $0.language.hasPrefix(Locale.current.language.languageCode?.identifier ?? "en") }
            ?? availableVoices().first { $0.language.hasPrefix("en") }
    }

    private static func qualityLabel(_ q: AVSpeechSynthesisVoiceQuality) -> String {
        switch q {
        case .enhanced: return "Enhanced"
        case .premium:  return "Premium"
        default:        return "Default"
        }
    }
}
