//
//  ContentView.swift
//  Verba
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Verba")
                .font(.largeTitle)
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
            Button(audioManager.isRecording ? "Stop Recording" : "Start Recording") {
                audioManager.isRecording ? audioManager.stopRecording() : audioManager.startRecording()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(audioManager.isRecording ? Color.red : Color.green)
            .foregroundColor(.white)
            .clipShape(Capsule())

            // Playback last recording
            Button("▶️ Play Last Recording") {
                audioManager.playRecording()
            }
            .disabled(!audioManager.canPlay)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding()
    }
}

