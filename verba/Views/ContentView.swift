import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioManager = AudioManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Verba.ai")
                            .font(.system(size: 34, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text("Welcome to Verba.ai — an audio transcribing tool")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

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
                            Task {
                                if audioManager.isRecording {
                                    audioManager.stopRecording()
                                } else {
                                    await audioManager.startRecording(with: modelContext)
                                }
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

                    NavigationLink(destination: AboutView()) {
                        Text("About Verba.ai")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    NavigationLink(destination: SettingsView()) {
                        Text("Settings")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    if !audioManager.recentTranscriptions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent Transcriptions")
                                .font(.headline)
                            ForEach(audioManager.recentTranscriptions.prefix(5), id: \.self) { line in
                                Text("• \(line)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $audioManager.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(audioManager.errorMessage)
        }
    }
}

