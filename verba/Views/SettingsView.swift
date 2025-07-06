import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    @State private var apiKeyInput: String = KeychainService.load() ?? ""
    @State private var showSavedAlert = false

    var body: some View {
        Form {
            // Audio configuration
            Section(header: Text("Audio")) {
                Toggle("High-Quality Recording", isOn: $settings.useHighQualityAudio)
                    .accessibilityLabel("Toggle high quality audio recording")
            }

            // Transcription engine fallback
            Section(header: Text("Transcription")) {
                Toggle("Use Local Fallback (Apple)", isOn: $settings.useLocalTranscriptionFallback)
                    .accessibilityLabel("Toggle Apple speech fallback")
            }

            // Secure API Key Management
            Section(header: Text("API Key (AssemblyAI)")) {
                SecureField("Enter your API key", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack {
                    Button("Save Key") {
                        let saved = KeychainService.save(apiKeyInput)
                        showSavedAlert = saved
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button("Clear") {
                        KeychainService.delete()
                        apiKeyInput = ""
                    }
                    .foregroundColor(.red)
                }
            }

            // Manual theme toggle
            Section(header: Text("Theme")) {
                Picker("App Theme", selection: $settings.themeMode) {
                    ForEach(AppSettings.ThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            //  Auto-load dev API key during debug builds
            #if DEBUG
            if apiKeyInput.isEmpty, let devKey = ProcessInfo.processInfo.environment["DEV_ASSEMBLY_API_KEY"] {
                _ = KeychainService.save(devKey)
                apiKeyInput = devKey
                print(" Auto-loaded dev API key")
            }
            #endif
        }
        .alert("API Key Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

