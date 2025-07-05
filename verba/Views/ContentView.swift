//
//  ContentView.swift
//  Verba
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioManager = AudioManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Verba")
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)

            // Real-time waveform visualization
            WaveformBar(level: audioManager.currentInputLevel)
                .frame(height: 20)
                .padding(.horizontal)

            // Transcription status or recording status message
            Text(audioManager.transcriptionStatus)
                .font(.caption)
                .foregroundColor(.gray)

            // Start / Stop Recording Button

            Button(audioManager.isRecording ? " Stop Recording" : " Start Recording") {
                if audioManager.isRecording {
                    audioManager.stopRecording()
                } else {
                    audioManager.startRecording(with: modelContext)
                }


            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(audioManager.isRecording ? Color.red : Color.green)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .accessibilityLabel(audioManager.isRecording ? "Stop Recording" : "Start Recording")

            // Playback last recording
            Button(" Play Last Recording") {

                audioManager.playRecording()
            }
            .disabled(!audioManager.canPlay)
            .padding()
            .frame(maxWidth: .infinity)

            .background(audioManager.canPlay ? Color.blue : Color.gray)

            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding()

        .navigationTitle("Audio Recorder")

    }
}

