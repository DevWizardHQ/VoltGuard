import AppKit
import SwiftUI
import VoltGuardCore

struct VoiceSoundTab: View {
    @Environment(AppState.self) private var state

    private static let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Sound") {
                Picker(
                    "Default sound",
                    selection: Binding(
                        get: { state.settings.sound.defaultSoundName ?? "Submarine" },
                        set: { state.settings.sound.defaultSoundName = $0 }
                    )
                ) {
                    ForEach(Self.systemSounds, id: \.self) { Text($0).tag($0) }
                }

                LabeledContent("Custom sound") {
                    HStack {
                        Text(
                            state.settings.sound.customSoundPath.map {
                                URL(fileURLWithPath: $0).lastPathComponent
                            } ?? "None"
                        )
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        Button("Choose…") { chooseSound() }
                        Button("Clear") { state.settings.sound.customSoundPath = nil }
                            .disabled(state.settings.sound.customSoundPath == nil)
                    }
                }

                if let path = state.settings.sound.customSoundPath,
                    !FileManager.default.fileExists(atPath: path)
                {
                    Label(
                        "That sound file no longer exists. VoltGuard will use the default sound.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                }

                HStack {
                    Button("Preview Sound") {
                        state.previewSound(
                            named: state.settings.sound.defaultSoundName,
                            customPath: state.settings.sound.customSoundPath
                        )
                    }
                    Button("Reset to Default") { state.settings.sound = SoundConfiguration() }
                }
            }

            Section("Voice") {
                Picker(
                    "Voice",
                    selection: Binding(
                        get: { state.settings.voice.voiceIdentifier ?? "" },
                        set: { state.settings.voice.voiceIdentifier = $0.isEmpty ? nil : $0 }
                    )
                ) {
                    Text("System Default").tag("")
                    ForEach(state.voices) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.id)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Speech rate: \(Int(state.settings.voice.rate * 100))%")
                    Slider(value: $state.settings.voice.rate, in: 0...1)
                        .accessibilityLabel("Speech rate")
                        .accessibilityValue("\(Int(state.settings.voice.rate * 100)) percent")
                }

                VStack(alignment: .leading) {
                    Text("Volume: \(Int(state.settings.voice.volume * 100))%")
                    Slider(value: $state.settings.voice.volume, in: 0...1)
                        .accessibilityLabel("Speech volume")
                        .accessibilityValue("\(Int(state.settings.voice.volume * 100)) percent")
                }

                VStack(alignment: .leading) {
                    Text("Tone: \(toneDescription)")
                    Slider(value: $state.settings.voice.pitch, in: 0.5...2)
                        .accessibilityLabel("Speech tone")
                        .accessibilityValue(toneDescription)
                }

                HStack {
                    Button("Test Voice") { state.previewVoice() }
                    Button("Reset to Default") { state.settings.voice = VoiceConfiguration() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var automaticVoiceLabel: String {
        guard let name = state.automaticVoiceName else { return "Automatic" }
        return "Automatic — \(name)"
    }

    private var toneDescription: String {
        let pitch = state.settings.voice.pitch
        switch pitch {
        case ..<0.85: return "Deeper"
        case ..<1.15: return "Natural"
        case ..<1.6: return "Higher"
        default: return "Highest"
        }
    }

    private func chooseSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.settings.sound.customSoundPath = url.path
    }
}
