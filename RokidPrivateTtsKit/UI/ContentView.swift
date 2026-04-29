import SwiftUI

struct ContentView: View {
    @StateObject private var vm = TtsViewModel()

    var body: some View {
        TabView {
            TtsView(vm: vm)
                .tabItem { Label("TTS", systemImage: "speaker.wave.2") }

            VoicePickerView(vm: vm)
                .tabItem { Label("Voice", systemImage: "waveform") }

            NetworkView(vm: vm)
                .tabItem { Label("Network", systemImage: "network") }
        }
        .onAppear {
            vm.startServer()
        }
        .onDisappear {
            vm.unbind()
            vm.stopServer()
        }
    }
}
