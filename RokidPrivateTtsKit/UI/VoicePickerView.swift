import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    @ObservedObject var vm: TtsViewModel
    @State private var voices: [VoiceOption] = []

    var body: some View {
        NavigationStack {
            Form {
                paramsSection
                voicesSection
            }
            .navigationTitle("Voice & Params")
            .onAppear { voices = VoiceRegistry.availableVoices() }
        }
    }

    private var paramsSection: some View {
        Section("Speech Parameters") {
            VStack(alignment: .leading) {
                Text("Rate: \(String(format: "%.2f", vm.rate))")
                Slider(value: $vm.rate, in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
            }
            VStack(alignment: .leading) {
                Text("Pitch: \(String(format: "%.2f", vm.pitch))")
                Slider(value: $vm.pitch, in: 0.5...2.0, step: 0.05)
            }
            VStack(alignment: .leading) {
                Text("Volume: \(String(format: "%.2f", vm.volume))")
                Slider(value: $vm.volume, in: 0...1, step: 0.05)
            }
        }
    }

    private var voicesSection: some View {
        Section("Voice") {
            Button("System default") { vm.selectedVoiceId = nil }
                .foregroundStyle(vm.selectedVoiceId == nil ? .blue : .primary)

            ForEach(voices) { voice in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.name).font(.body)
                        Text("\(voice.language) · \(voice.quality)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if vm.selectedVoiceId == voice.id {
                        Image(systemName: "checkmark").foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { vm.selectedVoiceId = voice.id }
            }
        }
    }
}
