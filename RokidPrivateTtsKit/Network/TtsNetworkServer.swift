import Foundation
import Network

// Mirrors ITtsServer AIDL over TCP (JSON+newline).
//
// Client → Server (incoming commands):
//   {"action":"speak","text":"Hello","uuid":"rokid-123"}
//   {"action":"stop","uuid":"rokid-123"}
//   {"action":"updateParam","rate":0.5,"pitch":1.0,"volume":1.0}
//
// Server → Client (state events):
//   {"event":"ttsStart","uuid":"rokid-123"}
//   {"event":"ttsStop","uuid":"rokid-123"}
//   {"event":"error","operation":"speak","message":"..."}
//   {"event":"serviceInfo","bound":true,"descriptor":"..."}

@MainActor
final class TtsNetworkServer: ObservableObject {
    @Published private(set) var clientCount: Int = 0
    @Published private(set) var localIP: String? = nil

    var onSpeak: ((String, String) -> Void)? = nil      // (text, uuid)
    var onStop: ((String) -> Void)? = nil               // (uuid)
    var onUpdateParam: ((Float?, Float?, Float?) -> Void)? = nil

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]
    private let port: NWEndpoint.Port = 8082

    func start() {
        localIP = resolveLocalIP()
        guard listener == nil else { return }
        guard let l = try? NWListener(using: .tcp, on: port) else { return }
        listener = l
        l.stateUpdateHandler = { _ in }
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.accept(conn) }
        }
        l.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        receiveBuffers.removeAll()
        clientCount = 0
    }

    // MARK: - Broadcast events to all clients

    func broadcastTtsStart(uuid: String) {
        broadcast(["event": "ttsStart", "uuid": uuid])
    }

    func broadcastTtsStop(uuid: String) {
        broadcast(["event": "ttsStop", "uuid": uuid])
    }

    func broadcastError(operation: String, message: String) {
        broadcast(["event": "error", "operation": operation, "message": message])
    }

    func broadcastServiceInfo(bound: Bool, descriptor: String) {
        broadcast(["event": "serviceInfo", "bound": bound, "descriptor": descriptor] as [String: Any])
    }

    // MARK: - Private

    private func broadcast(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let frame = (json + "\n").data(using: .utf8)!
        connections.forEach { $0.send(content: frame, completion: .idempotent) }
    }

    private func accept(_ conn: NWConnection) {
        connections.append(conn)
        receiveBuffers[ObjectIdentifier(conn)] = Data()
        clientCount = connections.count
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .cancelled, .failed: self?.remove(conn)
                default: break
                }
            }
        }
        conn.start(queue: .main)
        receiveNext(conn)
    }

    private func remove(_ conn: NWConnection) {
        connections.removeAll { $0 === conn }
        receiveBuffers.removeValue(forKey: ObjectIdentifier(conn))
        clientCount = connections.count
    }

    private func receiveNext(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.receiveBuffers[ObjectIdentifier(conn), default: Data()].append(data)
                    self.processBuffer(conn)
                }
                if isComplete || error != nil {
                    self.remove(conn)
                } else {
                    self.receiveNext(conn)
                }
            }
        }
    }

    private func processBuffer(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        guard var buf = receiveBuffers[key] else { return }
        while let idx = buf.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buf.prefix(upTo: idx)
            buf = buf.suffix(from: buf.index(after: idx))
            if let json = String(data: lineData, encoding: .utf8) {
                handleCommand(json)
            }
        }
        receiveBuffers[key] = buf
    }

    private func handleCommand(_ json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = obj["action"] as? String else { return }
        switch action {
        case "speak":
            let text = obj["text"] as? String ?? ""
            let uuid = obj["uuid"] as? String ?? TtsEngine.generateUuid()
            onSpeak?(text, uuid)
        case "stop":
            let uuid = obj["uuid"] as? String ?? ""
            onStop?(uuid)
        case "updateParam":
            let rate = obj["rate"].flatMap { ($0 as? NSNumber)?.floatValue }
            let pitch = obj["pitch"].flatMap { ($0 as? NSNumber)?.floatValue }
            let volume = obj["volume"].flatMap { ($0 as? NSNumber)?.floatValue }
            onUpdateParam?(rate, pitch, volume)
        default:
            break
        }
    }

    private func resolveLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let cur = ptr {
            let addr = cur.pointee
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: addr.ifa_name) == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                            &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                return String(cString: host)
            }
            ptr = addr.ifa_next
        }
        return nil
    }
}
