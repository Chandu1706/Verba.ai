import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioManager = AudioManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Verba")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)

                WaveformBar(level: audioManager.currentInputLevel)
                    .frame(height: 20)
                    .padding(.horizontal)

                if audioManager.isTranscribing {
                    ProgressView("Transcribing...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .foregroundColor(.gray)
                } else {
                    Text(audioManager.transcriptionStatus)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        if audioManager.isRecording {
                            audioManager.stopRecording()
                        } else {
                            audioManager.startRecording(with: modelContext)
                        }
                    }) {
                        Text(audioManager.isRecording ? "Stop" : "Start")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(audioManager.isRecording ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    Button(action: {
                        if audioManager.isPaused {
                            audioManager.resumeRecording()
                        } else {
                            audioManager.pauseRecording()
                        }
                    }) {
                        Text(audioManager.isPaused ? "Resume" : "Pause")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(audioManager.isRecording ? Color.orange : Color.gray)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(!audioManager.isRecording)
                }

                Button(action: {
                    audioManager.playRecording()
                }) {
                    Text("Play Last Recording")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(audioManager.canPlay ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(!audioManager.canPlay)

                NavigationLink(destination: SessionListView()) {
                    Text("View Sessions")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Audio Recorder")
        }
    }
}

