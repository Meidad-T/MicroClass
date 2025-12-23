//
//  RecordView.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import SwiftUI
import AVFoundation // Already imported, which is good for AVURLAsset

struct RecordView: View {
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var dataManager: DataManager
    @State private var showingPermissionAlert = false
    @State private var currentWelcomeText = ""
    @State private var isAnimatingText = false
    @State private var showRecordingUI = false
    @State private var showSettings = false
    @State private var showSaveDialog = false
    @State private var showClassSelection = false
    @State private var selectedClass: StudyClass?
    @State private var lectureTitle = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid background
                Color(hex: "2E2E2E")
                    .ignoresSafeArea()
                
                if speechManager.isLectureCompleted {
                    // Dim background and present a centered save card
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            Text("Save Lecture")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            TextField("Lecture title", text: $lectureTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Text("Select class")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(dataManager.classes) { studyClass in
                                        Button(action: { selectedClass = studyClass }) {
                                            VStack(spacing: 6) {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(studyClass.color.color)
                                                    .frame(width: 56, height: 56)
                                                    .overlay(Text(studyClass.name.prefix(2).uppercased()).foregroundColor(.white))

                                                Text(studyClass.name)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                            .padding(6)
                                            .background(selectedClass?.id == studyClass.id ? Color.white.opacity(0.08) : Color.clear)
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()

                        HStack(spacing: 14) {
                            Button("Cancel") {
                                speechManager.startNewLecture()
                            }
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(10)

                            Button(action: saveLecture) {
                                Text("Save Lecture")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(lectureTitle.isEmpty || selectedClass == nil ? Color.gray : Color.pink)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(lectureTitle.isEmpty || selectedClass == nil)
                        }
                        .padding([.horizontal, .bottom])
                    }
                    .frame(maxWidth: 560)
                    .background(Color(hex: "1F1F1F"))
                    .cornerRadius(16)
                    .padding()
                } else if showRecordingUI {
                    // Recording UI
                    VStack(spacing: 0) {
                        // Header with settings
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showRecordingUI = false
                                }
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Text("Recording")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // Audio level visualization
                        if speechManager.isRecording {
                            HStack(spacing: 3) {
                                ForEach(0..<20, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(speechManager.textColor.color)
                                        .frame(width: 4, height: max(4, CGFloat(speechManager.audioLevel) * 30 + CGFloat.random(in: -5...5)))
                                        .animation(.easeInOut(duration: 0.1), value: speechManager.audioLevel)
                                }
                            }
                            .frame(height: 30)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                            // Small silence timer (shows seconds since last detected speech)
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "timer")
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(String(format: "%0.1fs", speechManager.silenceDuration))
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .padding(.trailing, 20)
                            }
                        }
                        
                        // Text area
                        ScrollView {
                            ScrollViewReader { proxy in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(speechManager.recognizedText.isEmpty ?
                                         (speechManager.selectedLanguage == .hebrew ? "לחץ על המיקרופון כדי להתחיל להקליט..." : "Tap the microphone to start recording...") :
                                            speechManager.recognizedText)
                                    .font(.system(size: speechManager.fontSize, weight: .regular))
                                    .foregroundColor(speechManager.textColor.color)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 15)
                                    .id("textContent")
                                }
                                .onChange(of: speechManager.recognizedText) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo("textContent", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        // Bottom controls: pause centered, finish to the right. Pause color reflects text color.
                        ZStack {
                            // Finish button aligned to trailing
                            HStack {
                                Spacer()
                                Button(action: { speechManager.finishLecture() }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                        Text("Finish Lecture")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(height: 52)
                                    .background(Color.green)
                                    .cornerRadius(12)
                                }
                                .padding(.trailing, 20)
                            }

                            // Centered pause/start control
                            HStack {
                                Spacer()
                                Button(action: {
                                    if speechManager.isRecording {
                                        speechManager.pauseRecording()
                                    } else {
                                        if speechManager.isAuthorized {
                                            speechManager.startRecording()
                                        } else {
                                            showingPermissionAlert = true
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(speechManager.textColor.color)
                                            .frame(width: 104, height: 104)
                                            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 5)

                                        if speechManager.isRecording {
                                            Image(systemName: speechManager.isPaused ? "play.fill" : "pause.fill")
                                                .font(.system(size: 36, weight: .semibold))
                                                .foregroundColor(.white)
                                        } else {
                                            Image(systemName: "mic")
                                                .font(.system(size: 36, weight: .semibold))
                                                .foregroundColor(.black)
                                        }
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(.bottom, 40)
                    }
                } else {
                    // Welcome screen
                    VStack(spacing: 40) {
                        Spacer()
                        
                        // Animated welcome text
                        Text(currentWelcomeText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(isAnimatingText ? 1 : 0)
                            .scaleEffect(isAnimatingText ? 1 : 0.8)
                            .animation(.easeInOut(duration: 0.5), value: isAnimatingText)
                        
                        Spacer()
                        
                        // Microphone button
                        Button(action: {
                            // Open recording UI and start recording immediately so user doesn't need a second tap
                            // Keep layout stable (no scale animation) so button doesn't move unexpectedly.
                            if speechManager.isAuthorized {
                                showRecordingUI = true
                                speechManager.startRecording()
                            } else {
                                showRecordingUI = true
                                showingPermissionAlert = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "mic")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.black)
                            }
                        }
                        // removed scale animation to avoid moving the mic button when entering recording UI
                        
                        // Language selection buttons
                        HStack(spacing: 20) {
                            Button(action: {
                                speechManager.changeLanguage(to: .hebrew)
                            }) {
                                Text("עברית")
                                    .font(.headline)
                                    .foregroundColor(speechManager.selectedLanguage == .hebrew ? .white : .gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(speechManager.selectedLanguage == .hebrew ? Color.pink : Color.clear)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.pink, lineWidth: speechManager.selectedLanguage == .hebrew ? 0 : 2)
                                    )
                            }
                            
                            Button(action: {
                                speechManager.changeLanguage(to: .english)
                            }) {
                                Text("English")
                                    .font(.headline)
                                    .foregroundColor(speechManager.selectedLanguage == .english ? .white : .gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(speechManager.selectedLanguage == .english ? Color.pink : Color.clear)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.pink, lineWidth: speechManager.selectedLanguage == .english ? 0 : 2)
                                    )
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            startWelcomeAnimation()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(speechManager: speechManager)
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in Settings to use speech recognition.")
        }
    }
    
    private func startWelcomeAnimation() {
        animateWelcomeText()
    }
    
    private func animateWelcomeText() {
        // English text
        currentWelcomeText = "Welcome Y'aara"
        isAnimatingText = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isAnimatingText = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Hebrew text
                currentWelcomeText = "שלום יערה"
                isAnimatingText = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    isAnimatingText = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Repeat if not recording
                        if !showRecordingUI && !speechManager.isLectureCompleted {
                            animateWelcomeText()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - FIX: Pass the audio duration to the DataManager
    private func saveLecture() {
        // 1. Ensure we have a selected class and the temporary audio file URL from the SpeechManager
        guard let selectedClass = selectedClass,
              let tempAudioURL = speechManager.audioFileURL else {
            // If the user tried to save without selecting a class or if audio recording somehow failed, stop.
            return
        }
        
        // 2. Load the recorded audio data from the temporary file path
        guard let audioData = try? Data(contentsOf: tempAudioURL) else {
            print("Error: Could not load audio data from temp URL: \(tempAudioURL.path)")
            // If data cannot be loaded, stop the save process.
            return
        }
        
        // ✨ NEW CODE: Calculate the duration of the recorded audio file.
        let asset = AVURLAsset(url: tempAudioURL)
        let duration = asset.duration.seconds
        
        // 3. Save the lecture using the actual audio data and the calculated duration.
        // The DataManager now correctly receives the 'duration' argument.
        let _ = dataManager.addLecture(
            to: selectedClass,
            title: lectureTitle,
            transcript: speechManager.lectureText,
            audioData: audioData,
            duration: duration // 👈 Corrected: Passing the calculated duration
        )
        
        // 4. Clean up the temporary audio file now that the data has been saved
        try? FileManager.default.removeItem(at: tempAudioURL)
        
        // 5. Reset for next recording
        speechManager.startNewLecture()
        lectureTitle = ""
        self.selectedClass = nil
    }
}

#Preview {
    RecordView(speechManager: SpeechManager(), dataManager: DataManager())
}
