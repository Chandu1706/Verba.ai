//
//  SettingsView.swift
//  verba
//
//  Created by Chandu Korubilli on 7/6/25.
//
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(header: Text("Audio")) {
                Toggle("High-Quality Recording", isOn: $settings.useHighQualityAudio)
                    .accessibilityLabel("Toggle high quality audio recording")
            }

            Section(header: Text("Transcription")) {
                Toggle("Use Local Fallback (Apple)", isOn: $settings.useLocalTranscriptionFallback)
            }

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
    }
}

