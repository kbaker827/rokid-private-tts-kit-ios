import Foundation
import AVFoundation

// Mirrors the Android RokidTtsClient contract:
//   play(text, uuid) -> onUtteranceStart(uuid) ... onUtteranceStop(uuid)
//   stop(uuid)
//   updateParam(rate:, pitch:, volume:)

struct TtsServiceInfo {
    let bound: Bool
    let descriptor: String
}

protocol TtsClientListener: AnyObject {
    func onServiceConnected(info: TtsServiceInfo)
    func onUtteranceStart(uuid: String)
    func onUtteranceStop(uuid: String)
    func onError(operation: String, message: String)
}

@MainActor
final class TtsEngine: NSObject, ObservableObject {
    @Published private(set) var isBound: Bool = false
    @Published private(set) var currentUuid: String? = nil
    @Published private(set) var isSpeaking: Bool = false

    weak var listener: TtsClientListener?

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingUuids: [String: AVSpeechUtterance] = [:]

    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var pitch: Float = 1.0
    var volume: Float = 1.0
    var voiceIdentifier: String? = nil

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func bind() {
        guard !isBound else {
            listener?.onServiceConnected(info: currentInfo())
            return
        }
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            isBound = true
            listener?.onServiceConnected(info: currentInfo())
        } catch {
            listener?.onError(operation: "bind", message: error.localizedDescription)
        }
    }

    func unbind() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingUuids.removeAll()
        isBound = false
        isSpeaking = false
        currentUuid = nil
    }

    @discardableResult
    func play(text: String, uuid: String = generateUuid()) -> String? {
        guard isBound else { return nil }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        if let id = voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: id)
        }
        pendingUuids[uuid] = utterance
        synthesizer.speak(utterance)
        return uuid
    }

    func stop(uuid: String) -> Bool {
        guard isBound else { return false }
        synthesizer.stopSpeaking(at: .immediate)
        pendingUuids.removeValue(forKey: uuid)
        return true
    }

    func updateParam(rate: Float? = nil, pitch: Float? = nil, volume: Float? = nil) {
        if let r = rate { self.rate = r }
        if let p = pitch { self.pitch = p }
        if let v = volume { self.volume = v }
    }

    func currentInfo() -> TtsServiceInfo {
        TtsServiceInfo(bound: isBound, descriptor: "io.github.bzerk.rokidprivatetts.ios.ITtsEngine")
    }

    static func generateUuid() -> String {
        "rokid-\(Int(Date().timeIntervalSince1970 * 1000))"
    }
}

extension TtsEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let uuid = pendingUuids.first { $0.value === utterance }?.key ?? "-"
            currentUuid = uuid
            isSpeaking = true
            listener?.onUtteranceStart(uuid: uuid)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let uuid = pendingUuids.first { $0.value === utterance }?.key ?? currentUuid ?? "-"
            pendingUuids.removeValue(forKey: uuid)
            if pendingUuids.isEmpty { isSpeaking = false; currentUuid = nil }
            listener?.onUtteranceStop(uuid: uuid)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let uuid = pendingUuids.first { $0.value === utterance }?.key ?? currentUuid ?? "-"
            pendingUuids.removeValue(forKey: uuid)
            isSpeaking = false
            currentUuid = nil
            listener?.onUtteranceStop(uuid: uuid)
        }
    }
}
