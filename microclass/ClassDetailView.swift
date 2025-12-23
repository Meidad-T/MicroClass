//
//  ClassDetailView.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import SwiftUI
import AVFoundation

struct ClassDetailView: View {
    let studyClass: StudyClass
    @ObservedObject var dataManager: DataManager
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentlyPlayingLecture: Lecture?
    
    var body: some View {
        ZStack {
            Color(hex: "2E2E2E")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text(studyClass.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(studyClass.lectures.count) lectures")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Lectures List
                if studyClass.lectures.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "mic.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Lectures Yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Record your first lecture to see it here")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(studyClass.lectures) { lecture in
                                LectureRowView(
                                    lecture: lecture,
                                    isPlaying: isPlaying && currentlyPlayingLecture?.id == lecture.id,
                                    onPlay: { playLecture(lecture) },
                                    onStop: { stopPlaying() },
                                    onDelete: { deleteLecture(lecture) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopPlaying()
        }
    }
    
    private func playLecture(_ lecture: Lecture) {
        if currentlyPlayingLecture?.id == lecture.id && isPlaying {
            stopPlaying()
            return
        }
        
        stopPlaying()
        
        let audioURL = dataManager.getAudioURL(for: lecture)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = AudioPlayerDelegate { [self] in
                DispatchQueue.main.async {
                    stopPlaying()
                }
            }
            audioPlayer?.play()
            isPlaying = true
            currentlyPlayingLecture = lecture
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    private func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingLecture = nil
    }
    
    private func deleteLecture(_ lecture: Lecture) {
        dataManager.deleteLecture(lecture, from: studyClass)
    }
}

struct LectureRowView: View {
    let lecture: Lecture
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void
    
    @State private var showTranscript = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lecture.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(lecture.formattedDate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    // Play/Stop button
                    Button(action: {
                        if isPlaying {
                            onStop()
                        } else {
                            onPlay()
                        }
                    }) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.pink)
                    }
                    
                    // Transcript button
                    Button(action: {
                        showTranscript.toggle()
                    }) {
                        Image(systemName: showTranscript ? "eye.slash.fill" : "eye.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    // Export button
                    Button(action: {
                        exportLecture()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                    
                    // Delete button
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Duration
            Text("Duration: \(lecture.formattedDuration)")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Transcript (collapsible)
            if showTranscript {
                ScrollView {
                    Text(lecture.transcript)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding()
                .background(Color.black.opacity(0.2))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(15)
        .alert("Delete Lecture", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this lecture? This action cannot be undone.")
        }
    }
    
    private func exportLecture() {
        let activityVC = UIActivityViewController(activityItems: [lecture.transcript], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

#Preview {
    ClassDetailView(studyClass: StudyClass(name: "Math", color: .blue), dataManager: DataManager())
}

