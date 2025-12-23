//
//  DataModels.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Class Model
struct StudyClass: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: ClassColor
    var lectures: [Lecture] = []
    var createdAt: Date = Date()
    
    init(name: String, color: ClassColor) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
    
    enum ClassColor: String, CaseIterable, Codable {
        case pink = "pink"
        case blue = "blue"
        case green = "green"
        case orange = "orange"
        case yellow = "yellow"
        case red = "red"
        case purple = "purple"
        case teal = "teal"
        
        var color: Color {
            switch self {
            case .pink: return .pink
            case .blue: return .blue
            case .green: return .green
            case .orange: return .orange
            case .yellow: return .yellow
            case .red: return .red
            case .purple: return .purple
            case .teal: return .teal
            }
        }
        
        var displayName: String {
            return self.rawValue.capitalized
        }
    }
}

// MARK: - Lecture Model
struct Lecture: Identifiable, Codable {
    let id: UUID
    var title: String
    var transcript: String
    var audioFileName: String
    var createdAt: Date = Date()
    var duration: TimeInterval = 0
    var summary: String? // ✨ ADDED: Optional field for a lecture summary.
    
    init(title: String, transcript: String, audioFileName: String) {
        self.id = UUID()
        self.title = title
        self.transcript = transcript
        self.audioFileName = audioFileName
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Data Manager
class DataManager: ObservableObject {
    @Published var classes: [StudyClass] = []
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let classesFileName = "classes.json"
    
    init() {
        loadClasses()
    }
    
    // MARK: - Class Management
    func addClass(name: String, color: StudyClass.ClassColor) {
        let newClass = StudyClass(name: name, color: color)
        classes.append(newClass)
        saveClasses()
    }
    
    func deleteClass(_ studyClass: StudyClass) {
        // Delete audio files for all lectures in this class
        for lecture in studyClass.lectures {
            let audioURL = documentsDirectory.appendingPathComponent(lecture.audioFileName)
            try? FileManager.default.removeItem(at: audioURL)
        }

        classes.removeAll { $0.id == studyClass.id }
        saveClasses()
    }
    
    func updateClass(_ studyClass: StudyClass) {
        if let index = classes.firstIndex(where: { $0.id == studyClass.id }) {
            classes[index] = studyClass
            saveClasses()
        }
    }
    
    // MARK: - Lecture Management
    // 💡 UPDATED: Added 'duration' parameter
    func addLecture(to studyClass: StudyClass, title: String, transcript: String, audioData: Data, duration: TimeInterval) -> Lecture {
        let audioFileName = "\(UUID().uuidString).m4a"
        let audioURL = documentsDirectory.appendingPathComponent(audioFileName)
        
        do {
            try audioData.write(to: audioURL)
        } catch {
            print("Failed to save audio: \(error)")
        }
        
        var lecture = Lecture(title: title, transcript: transcript, audioFileName: audioFileName)
        lecture.duration = duration // Set the actual duration
        
        if let index = classes.firstIndex(where: { $0.id == studyClass.id }) {
            classes[index].lectures.append(lecture)
            saveClasses()
        }
        
        return lecture
    }
    
    func deleteLecture(_ lecture: Lecture, from studyClass: StudyClass) {
        if let classIndex = classes.firstIndex(where: { $0.id == studyClass.id }) {
            classes[classIndex].lectures.removeAll { $0.id == lecture.id }
            
            // Delete audio file
            let audioURL = documentsDirectory.appendingPathComponent(lecture.audioFileName)
            try? FileManager.default.removeItem(at: audioURL)
            
            saveClasses()
        }
    }
    
    // ✨ ADDED: Function to update the summary after generation
    func updateLectureSummary(for lecture: Lecture, in studyClass: StudyClass, summary: String) {
        if let classIndex = classes.firstIndex(where: { $0.id == studyClass.id }),
           let lectureIndex = classes[classIndex].lectures.firstIndex(where: { $0.id == lecture.id }) {
            classes[classIndex].lectures[lectureIndex].summary = summary
            saveClasses()
        }
    }
    
    func getAudioURL(for lecture: Lecture) -> URL {
        return documentsDirectory.appendingPathComponent(lecture.audioFileName)
    }
    
    // MARK: - Persistence
    private func saveClasses() {
        let url = documentsDirectory.appendingPathComponent(classesFileName)
        do {
            let data = try JSONEncoder().encode(classes)
            try data.write(to: url)
        } catch {
            print("Failed to save classes: \(error)")
        }
    }
    
    private func loadClasses() {
        let url = documentsDirectory.appendingPathComponent(classesFileName)
        do {
            let data = try Data(contentsOf: url)
            classes = try JSONDecoder().decode([StudyClass].self, from: data)
        } catch {
            print("Failed to load classes: \(error)")
            classes = []
        }
    }
}
