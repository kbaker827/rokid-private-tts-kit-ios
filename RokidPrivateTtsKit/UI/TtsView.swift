import SwiftUI

struct TtsView: View {
    @ObservedObject var vm: TtsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    messageSection
                    controlsSection
                    statusSection
                }
            }
            .navigationTitle("Rokid Private TTS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Message input

    private var messageSection: some View {
        Section("Message") {
            TextEditor(text: $vm.messageText)
                .frame(minHeight: 80)
            Text("Leave empty to use default demo text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls (mirrors Android bind/unbind/speak/stop buttons)

    private var controlsSection: some View {
        Section("Controls") {
            HStack(spacing: 12) {
                Button("Bind", action: vm.bind)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(vm.engine.isBound)

                Button("Unbind", action: vm.unbind)
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .disabled(!vm.engine.isBound)
            }
            HStack(spacing: 12) {
                Button(action: vm.speak) {
                    Label("Speak", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: vm.stop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(vm.lastUuid == "-")
            }
        }
    }

    // MARK: - Status (mirrors Android statusView TextView)

    private var statusSection: some View {
        Section("Status") {
            Group {
                statusRow("service", value: vm.serviceState, color: serviceColor)
                statusRow("callback", value: vm.callbackState)
                statusRow("last uuid", value: vm.lastUuid)
                statusRow("last action", value: vm.lastAction)
            }
            .font(.system(.caption, design: .monospaced))
        }
    }

    private func statusRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .foregroundStyle(color)
                .lineLimit(3)
            Spacer()
        }
    }

    private var serviceColor: Color {
        switch vm.serviceState {
        case "bound": return .green
        case "disconnected": return .secondary
        case "error": return .red
        default: return .orange
        }
    }
}
