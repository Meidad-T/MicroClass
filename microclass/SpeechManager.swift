//
//  SpeechManager.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import Foundation
import Speech
import AVFoundation
import Combine
import SwiftUI

class SpeechManager: ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var selectedLanguage: Language = .hebrew
    @Published var fontSize: CGFloat = 18
    @Published var textColor: TextColor = .white
    @Published var isLectureCompleted = false
    @Published var lectureText = ""
    @Published var audioLevel: Float = 0.0
    @Published var isPaused = false
    @Published var lastSpeechTime = Date()
    @Published var silenceDuration: TimeInterval = 0
    // For Hebrew-specific pause/resume punctuation behavior
    @Published var waitingForHebrewResume = false
    
    // MARK: - New Audio Recording Properties
    var audioRecorder: AVAudioRecorder? // Handles the actual audio recording
    var audioFileURL: URL? // Stores the temporary file path of the recording

    enum Language: String, CaseIterable {
        case english = "en-US"
        case hebrew = "he-IL"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .hebrew: return "עברית"
            }
        }
        
        var locale: Locale {
            Locale(identifier: self.rawValue)
        }
    }
    
    enum TextColor: String, CaseIterable {
        case pink = "pink"
        case blue = "blue"
        case green = "green"
        case orange = "orange"
        case yellow = "yellow"
        case red = "red"
        case white = "white"
        case black = "black"
        
        var color: Color {
            switch self {
            case .pink: return .pink
            case .blue: return .blue
            case .green: return .green
            case .orange: return .orange
            case .yellow: return .yellow
            case .red: return .red
            case .white: return .white
            case .black: return .black
            }
        }
        
        var displayName: String {
            return self.rawValue.capitalized
        }
    }
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    // Simple append-only behavior: we append the newest transcription segment
    
    init() {
        requestPermissions()
        updateSpeechRecognizer()
    }
    
    func updateSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: selectedLanguage.locale)
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
        
        #if os(iOS)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                // Ensure both speech and microphone are authorized
                self?.isAuthorized = self?.isAuthorized == true && granted
            }
        }
        #endif
    }
    
    func startRecording() {
        guard isAuthorized else { return }
        
        // Stop any existing recording first
        if isRecording {
            stopRecording()
        }
        
    // Cancel any previous recognition task
    recognitionTask?.cancel()
    recognitionTask = nil
    // Do not clear recognizedText here — preserve existing transcript so resume appends to it
        
        // MARK: - NEW AUDIO RECORDING SETUP
        // 1. Define the output file URL (using a temporary file)
        let fileName = UUID().uuidString + ".m4a"
        let tempDir = FileManager.default.temporaryDirectory
        self.audioFileURL = tempDir.appendingPathComponent(fileName)

        // 2. Define the recording settings (MPEG4AAC is common and efficient)
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ] as [String : Any]
        // END NEW AUDIO RECORDING SETUP
        
        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set session category for recording and measurement (for speech)
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 3. Initialize and start the Audio Recorder
            audioRecorder = try AVAudioRecorder(url: self.audioFileURL!, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
        } catch {
            print("Audio session or recorder setup failed: \(error.localizedDescription)")
            return
        }
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        recognitionRequest.taskHint = .dictation
        recognitionRequest.addsPunctuation = true
        
        // Configure audio engine (same as before for speech recognition)
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // MARK: - FIX: Corrected logic for installing the tap
        // To be safe, always remove the tap before installing a new one when starting recording.
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            
            // Monitor audio levels
            DispatchQueue.main.async {
                self?.updateAudioLevel(from: buffer)
            }
        }
        // END FIX
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start failed: \(error)")
            // If the engine fails, stop the recorder too for cleanup
            audioRecorder?.stop()
            audioRecorder = nil
            return
        }
        
        // Start recognition task with continuous listening
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    // Append only the newest segment (last segment) to keep behavior simple and append-only
                    if let lastSegment = result.bestTranscription.segments.last {
                        let newText = lastSegment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !newText.isEmpty {
                            // Avoid adding the same trailing text twice
                            let potentialSuffix = (self?.recognizedText.isEmpty == false) ? " \(newText)" : newText
                            if let existing = self?.recognizedText, existing.hasSuffix(potentialSuffix) {
                                // already appended
                            } else if let selfStrong = self, !selfStrong.recognizedText.isEmpty, let lastChar = selfStrong.recognizedText.last, !lastChar.isWhitespace {
                                selfStrong.recognizedText += " " + newText
                            } else {
                                self?.recognizedText += newText
                            }
                        }
                    }

                    // If this is the final result, start a new recognition task to continue listening
                    if result.isFinal {
                        self?.continueListening()
                    }
                }

                if let error = error {
                    print("Recognition error: \(error)")
                    // Don't stop recording on error, try to continue
                    self?.continueListening()
                }
            }
        }
        
        isRecording = true
        isPaused = false
    }
    
    private func continueListening() {
        guard isRecording && !isPaused else { return }
        
        // Create a new recognition request to continue listening
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = false
        newRequest.taskHint = .dictation
        newRequest.addsPunctuation = true
        
        recognitionRequest = newRequest
        
    // Start new recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: newRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    // Append only the newest segment (last segment)
                    if let lastSegment = result.bestTranscription.segments.last {
                        let newText = lastSegment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !newText.isEmpty {
                            let potentialSuffix = (self?.recognizedText.isEmpty == false) ? " \(newText)" : newText
                            if let existing = self?.recognizedText, existing.hasSuffix(potentialSuffix) {
                                // already appended
                            } else if let selfStrong = self, !selfStrong.recognizedText.isEmpty, let lastChar = selfStrong.recognizedText.last, !lastChar.isWhitespace {
                                selfStrong.recognizedText += " " + newText
                            } else {
                                self?.recognizedText += newText
                            }
                        }
                    }

                    // If this is the final result, continue listening
                    if result.isFinal {
                        self?.continueListening()
                    }
                }

                if let error = error {
                    print("Recognition error: \(error)")
                    // Try to continue listening
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.continueListening()
                    }
                }
            }
        }
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        let level = min(average * 10, 1.0) // Scale and cap at 1.0
        
        DispatchQueue.main.async {
            self.audioLevel = level

            // Update last speech time if we detect speech
            if level > 0.1 { // Threshold for speech detection
                // Speech detected -> if we were waiting for a Hebrew resume, insert punctuation
                if self.waitingForHebrewResume && self.selectedLanguage == .hebrew {
                    let trimmed = self.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if let lastChar = trimmed.last, !".?!־–—".contains(lastChar) {
                            self.recognizedText += "."
                        }
                        self.recognizedText += "\n\n"
                    }
                    self.waitingForHebrewResume = false
                }

                self.lastSpeechTime = Date()
                // reset silence duration
                self.silenceDuration = 0
            } else {
                // Update silence duration
                let timeSinceLastSpeech = Date().timeIntervalSince(self.lastSpeechTime)
                self.silenceDuration = timeSinceLastSpeech

                // For Hebrew: when quiet for >= 2s, set a waiting flag so punctuation is added when user resumes
                if self.selectedLanguage == .hebrew {
                    if timeSinceLastSpeech >= 2.0 && !self.recognizedText.isEmpty && !self.waitingForHebrewResume {
                        self.waitingForHebrewResume = true
                    }
                } else {
                    // For other languages, fallback: after 3s insert paragraph break if not already present
                    if timeSinceLastSpeech >= 3.0 && !self.recognizedText.isEmpty && !self.recognizedText.hasSuffix("\n\n") {
                        let trimmed = self.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let lastChar = trimmed.last, !".?!־–—".contains(lastChar) {
                            self.recognizedText += "."
                        }
                        self.recognizedText += "\n\n"
                    }
                }
            }
        }
    }
    
    func stopRecording() {
        // MARK: - NEW: Stop and clean up audio recorder
        audioRecorder?.stop()
        audioRecorder = nil

        audioEngine.stop()
        
        // Remove tap when stopping the engine
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
    recognitionRequest = nil
    recognitionTask = nil
        isRecording = false
    }
    
    func clearText() {
        recognizedText = ""
    }
    
    func changeLanguage(to language: Language) {
        selectedLanguage = language
        updateSpeechRecognizer()
    }
    
    func finishLecture() {
        lectureText = recognizedText
        isLectureCompleted = true
        // stopRecording() will stop the recorder and engine, leaving the file at audioFileURL
        stopRecording()
    }
    
    func startNewLecture() {
        recognizedText = ""
        lectureText = ""
        isLectureCompleted = false
    // MARK: - NEW: Clear the file URL
    audioFileURL = nil
    }
    
    func pauseRecording() {
        if isRecording && !isPaused {
            audioEngine.pause()
            audioRecorder?.pause() // MARK: - NEW: Pause the audio recorder
            isPaused = true
        } else if isRecording && isPaused {
            do {
                try audioEngine.start()
                audioRecorder?.record() // MARK: - NEW: Resume the audio recorder
                isPaused = false
                // Resume listening
                continueListening()
            } catch {
                print("Audio engine resume failed: \(error)")
            }
        }
    }
}
