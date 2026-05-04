# Rokid Private TTS Kit iOS


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS equivalent of the [Rokid Private TTS Kit](https://github.com/bzerk/rokid-private-tts-kit) Android library.

## What the Android library does

The Android library binds to a **private AIDL service** (`ITtsServer`) running inside the Rokid glasses OS:

```
com.rokid.os.sprite.assistserver / .tts.TtsService
  playTtsMsg(text, uuid, ITtsListener)   → onTtsStart(uuid) / onTtsStop(uuid)
  stopTtsPlay(uuid)
  updateTtsParam(json)
```

This was necessary because standard Android `TextToSpeech` is absent on the tested Rokid glasses build.

## What this iOS version does

Since the Rokid glasses run Android (not iOS), the private binder cannot be called from iPhone. Instead this app provides:

1. **`TtsEngine`** — `AVSpeechSynthesizer` wrapper with the same logical API:
   - `bind()` / `unbind()`
   - `play(text:uuid:)` → `onUtteranceStart(uuid)` / `onUtteranceStop(uuid)`
   - `stop(uuid:)`
   - `updateParam(rate:pitch:volume:)`

2. **`TtsNetworkServer`** — `NWListener` TCP server on port **8082** that exposes the same interface over the network (JSON+newline), so any client (glasses companion app, automation tool) can drive TTS remotely:

```
Client → Server:
  {"action":"speak","text":"Hello","uuid":"rokid-123"}
  {"action":"stop","uuid":"rokid-123"}
  {"action":"updateParam","rate":0.5,"pitch":1.0,"volume":1.0}

Server → Client:
  {"event":"ttsStart","uuid":"rokid-123"}
  {"event":"ttsStop","uuid":"rokid-123"}
  {"event":"error","operation":"speak","message":"..."}
  {"event":"serviceInfo","bound":true,"descriptor":"..."}
```

3. **Demo UI** — identical in spirit to the Android demo app (Bind / Unbind / Speak / Stop + status log).

## File Reference

| File | Purpose |
|------|---------|
| `TTS/TtsEngine.swift` | `AVSpeechSynthesizer` wrapper; mirrors `RokidTtsClient` API and `ITtsServer` binder contract |
| `TTS/VoiceRegistry.swift` | Lists available `AVSpeechSynthesisVoice` options by language/quality |
| `Network/TtsNetworkServer.swift` | `NWListener` TCP server; accepts speak/stop/updateParam commands; broadcasts events |
| `ViewModel/TtsViewModel.swift` | Orchestrates `TtsEngine` + `TtsNetworkServer`; mirrors Android `MainActivity` logic |
| `UI/TtsView.swift` | Bind / Unbind / Speak / Stop UI + status log (mirrors Android layout) |
| `UI/VoicePickerView.swift` | Rate / pitch / volume sliders + voice selection |
| `UI/NetworkView.swift` | TCP server status, wire protocol documentation, activity log |

## Xcode Setup

1. Open `RokidPrivateTtsKit.xcodeproj` in Xcode 15+
2. Select your Team under **Signing & Capabilities**
3. Build & run on iPhone (iOS 16+)

No third-party dependencies:
- `AVFoundation` — `AVSpeechSynthesizer`, `AVAudioSession`
- `Network.framework` — `NWListener` TCP server

## Android vs iOS comparison

| Android | iOS |
|---------|-----|
| Binds `ITtsServer` AIDL binder | `AVSpeechSynthesizer` via `AVAudioSession.playback` |
| `playTtsMsg(text, uuid, listener)` | `engine.play(text:uuid:)` |
| `stopTtsPlay(uuid)` | `engine.stop(uuid:)` |
| `updateTtsParam(json)` | `engine.updateParam(rate:pitch:volume:)` |
| `ITtsListener.onTtsStart/Stop` | `TtsClientListener.onUtteranceStart/Stop` |
| No network server | TCP server on :8082 mirrors AIDL over network |
| `minSdk 28`, glasses-only | iOS 16+, runs on iPhone |
