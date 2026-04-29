import Foundation
import AVFoundation

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let timestamp = Date()
}

@MainActor
final class TtsViewModel: ObservableObject, TtsClientListener {
    @Published var messageText: String = ""
    @Published private(set) var serviceState: String = "disconnected"
    @Published private(set) var callbackState: String = "idle"
    @Published private(set) var lastUuid: String = "-"
    @Published private(set) var lastAction: String = "ready"
    @Published private(set) var log: [LogEntry] = []

    let engine = TtsEngine()
    let server = TtsNetworkServer()

    // Params
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published var pitch: Float = 1.0
    @Published var volume: Float = 1.0
    @Published var selectedVoiceId: String? = nil

    private var pendingSpeakText: String? = nil

    init() {
        engine.listener = self
        server.onSpeak = { [weak self] text, uuid in
            Task { @MainActor in self?.playNow(text: text, uuid: uuid) }
        }
        server.onStop = { [weak self] uuid in
            Task { @MainActor in
                let ok = self?.engine.stop(uuid: uuid) ?? false
                self?.appendLog("remote stop uuid=\(uuid) ok=\(ok)")
            }
        }
        server.onUpdateParam = { [weak self] rate, pitch, volume in
            Task { @MainActor in
                self?.engine.updateParam(rate: rate, pitch: pitch, volume: volume)
                self?.appendLog("remote updateParam rate=\(rate.map{"\($0)"} ?? "-") pitch=\(pitch.map{"\($0)"} ?? "-")")
            }
        }
    }

    // MARK: - UI actions (mirrors Android MainActivity)

    func bind() {
        engine.rate = rate
        engine.pitch = pitch
        engine.volume = volume
        engine.voiceIdentifier = selectedVoiceId
        engine.bind()
        lastAction = "bind requested"
        appendLog("bind requested")
    }

    func unbind() {
        engine.unbind()
        serviceState = "disconnected"
        lastAction = "unbind requested"
        server.broadcastServiceInfo(bound: false, descriptor: "-")
        appendLog("unbind requested")
    }

    func speak() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = text.isEmpty ? "Hello from Rokid Private TTS." : text
        if engine.isBound {
            playNow(text: spoken)
            return
        }
        pendingSpeakText = spoken
        bind()
        lastAction = "bind requested for speak"
        appendLog("bind requested for speak")
    }

    func stop() {
        guard lastUuid != "-" else {
            lastAction = "stop skipped (no uuid)"
            return
        }
        let ok = engine.stop(uuid: lastUuid)
        lastAction = ok ? "stop requested \(lastUuid)" : "stop failed \(lastUuid)"
        appendLog(lastAction)
    }

    func startServer() { server.start() }
    func stopServer() { server.stop() }

    // MARK: - TtsClientListener

    func onServiceConnected(info: TtsServiceInfo) {
        serviceState = info.bound ? "bound" : "binder null"
        lastAction = "bound \(info.descriptor)"
        server.broadcastServiceInfo(bound: info.bound, descriptor: info.descriptor)
        appendLog("service connected bound=\(info.bound)")
        if let pending = pendingSpeakText {
            pendingSpeakText = nil
            playNow(text: pending)
        }
    }

    func onUtteranceStart(uuid: String) {
        callbackState = "start"
        lastUuid = uuid
        lastAction = "tts start \(uuid)"
        server.broadcastTtsStart(uuid: uuid)
        appendLog("tts start uuid=\(uuid)")
    }

    func onUtteranceStop(uuid: String) {
        callbackState = "stop"
        lastUuid = uuid
        lastAction = "tts stop \(uuid)"
        server.broadcastTtsStop(uuid: uuid)
        appendLog("tts stop uuid=\(uuid)")
    }

    func onError(operation: String, message: String) {
        if !engine.isBound { serviceState = "error" }
        lastAction = "\(operation) error: \(message)"
        server.broadcastError(operation: operation, message: message)
        appendLog("error op=\(operation) \(message)")
    }

    // MARK: - Private

    private func playNow(text: String, uuid: String = TtsEngine.generateUuid()) {
        engine.rate = rate
        engine.pitch = pitch
        engine.volume = volume
        engine.voiceIdentifier = selectedVoiceId
        let resultUuid = engine.play(text: text, uuid: uuid)
        lastUuid = resultUuid ?? "-"
        lastAction = resultUuid != nil ? "speak requested \(lastUuid)" : "speak failed"
        appendLog(lastAction)
    }

    private func appendLog(_ message: String) {
        log.insert(LogEntry(message: message), at: 0)
        if log.count > 100 { log = Array(log.prefix(100)) }
    }
}
