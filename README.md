
📱 Verba.ai – Audio Transcription iOS App

Verba.ai is a production-ready iOS audio recording and transcription application. It supports real-time waveform visualization, background-safe recording, intelligent segmentation, cloud + offline transcription, and large-scale session management using SwiftData.


✅ Features

🎙 High-quality audio recording  using `AVAudioEngine`
🧠 Automated 30-second segmentation and transcription (AssemblyAI + Apple fallback)
🔊 Real-time waveform animation
📂 Session browser with date grouping, inline transcription previews, and export
🛠 Customizable audio quality and dark/light mode toggle
 🔁 Offline fallback using Apple’s speech recognition
🔐 SwiftData-backed local persistence
⚙️ Full support for route changes, interruptions, and background recording


📦 Requirements

•	Xcode 15+
•	iOS 17+
•	Swift 5.9+

🛠 Setup Instructions

1.	Clone the repository
First you need to clone this repository into your desired folder,

   ```
   git clone https://github.com/your-username/verba-ai.git
   cd verba-ai
   ```

2. Open the Xcode project

   ```bash
   open Verba.xcodeproj
   ```

5. Build and run on a real device 

 You can connect to a real ios device and run it to see the execution or you can even use a simulator.
(Note : Recording and speech recognition don’t work on the simulator.)


🧪 Testing

This project includes a full suite of unit, integration, and performance tests.

 ✅ Types of Tests Included

1. Unit Tests 
   Validate core business logic and SwiftData models.

2. Integration Tests
   Ensure end-to-end functionality with AssemblyAI transcription.

3. Error & Interruption Handling  
   Simulate poor network, audio route changes, app backgrounding.

4. Performance Testing
   Simulate large datasets (1,000+ sessions, 10,000+ segments).

 ▶️ How to Run Tests in Xcode

1. Open the project in Xcode:

   ```bash
   open Verba.xcodeproj
  

2. Select a real device  or simulator (some tests may require device).

3. Open the Test Navigator  
   Press `⌘ + 6` or go to `View > Navigators > Show Test Navigator`.

4. Run individual tests  
   Click the play icon next to any test case or test method.

5. Run all tests 
   Press `⌘ + U` or go to `Product > Test`.

 🧪 Test Targets

 `VerbaTests`: Unit tests for SwiftData and audio logic
 `VerbaUITests`: UI-level testing for flows and navigation
`VerbaPerformanceTests`: Optional stress tests for large data loads

 💡 Tip: Use "Profile" (⌘ + I) to inspect memory, disk, and energy use under real workloads.






⚙️ Configuration

Use the Settings screen in the app to:
•	Toggle audio quality (high/normal)
•	Enable/disable fallback to local transcription
•	Manually switch between light/dark/system themes



📝 Folder Structure


├── Controllers/
│   ├── AudioManager.swift
│   ├── TranscriptionService.swift
│
├── Models/
│   ├── RecordingSession.swift
│   ├── RecordingSegment.swift
│
├── Views/
│   ├── ContentView.swift
│   ├── SessionListView.swift
│   ├── SettingsView.swift
│   ├── AboutView.swift
│   └── WaveformBar.swift



📤 Exporting Sessions

You can long-press a session to select it, then tap Export & Share to save the full CSV transcription (session + segments).


  Bonus Features Implemented

•	Noise reduction + reverb (custom audio processing)
•	FTS-based advanced search to search by transcriptions as well
•	Offline fallback transcription
•	Export to `.csv`
•	Dark/light mode override
•	Settings screen
•	Swipe left on session to delete it
  Widget support for the app


## FAQ

Can I test without a real API key?
  Yes, but transcription will fail and fallback to Apple’s speech recognition after 5 retries.

Can I use this with Whisper or another model? 
  Yes, just swap the TranscriptionService logic.


## Documentation
 📄 [View Full Documentation (PDF)](verba/Docs/Verba.pdf)

 
## Contributors

 Chandu Korubilli – Developer & Architect
 




