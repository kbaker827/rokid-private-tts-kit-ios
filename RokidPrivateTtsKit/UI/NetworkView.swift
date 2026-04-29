import SwiftUI

struct NetworkView: View {
    @ObservedObject var vm: TtsViewModel

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                protocolSection
                logSection
            }
            .navigationTitle("Network Server")
        }
    }

    private var serverSection: some View {
        Section("TCP Server") {
            HStack {
                Label("IP", systemImage: "wifi")
                Spacer()
                Text(vm.server.localIP ?? "Not available")
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            HStack {
                Label("Port", systemImage: "network")
                Spacer()
                Text("8082")
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            HStack {
                Label("Clients", systemImage: "laptopcomputer.and.iphone")
                Spacer()
                Text("\(vm.server.clientCount)")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Mirrors the Android ITtsServer AIDL interface over TCP. Connect on \(vm.server.localIP ?? "phone IP"):8082.")
        }
    }

    private var protocolSection: some View {
        Section("Wire Protocol") {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    protocolBlock(title: "Incoming commands (client → server):",
                        lines: [
                            #"{"action":"speak","text":"Hello","uuid":"rokid-123"}"#,
                            #"{"action":"stop","uuid":"rokid-123"}"#,
                            #"{"action":"updateParam","rate":0.5,"pitch":1.0,"volume":1.0}"#,
                        ])
                    protocolBlock(title: "Outgoing events (server → client):",
                        lines: [
                            #"{"event":"ttsStart","uuid":"rokid-123"}"#,
                            #"{"event":"ttsStop","uuid":"rokid-123"}"#,
                            #"{"event":"error","operation":"speak","message":"..."}"#,
                            #"{"event":"serviceInfo","bound":true,"descriptor":"..."}"#,
                        ])
                }
                .padding(.vertical, 4)
            }
        } footer: {
            Text("All messages are newline-delimited JSON.")
        }
    }

    private func protocolBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(4)
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var logSection: some View {
        Section("Activity Log") {
            if vm.log.isEmpty {
                Text("No activity yet.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(vm.log.prefix(20)) { entry in
                    Text(entry.message)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Activity Log")
        } footer: {
            Text("Last 20 events shown.")
        }
    }
}
