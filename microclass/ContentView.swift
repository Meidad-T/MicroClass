//
//  ContentView.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import SwiftUI
import PDFKit

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var showingPermissionAlert = false
    @State private var currentWelcomeText = ""
    @State private var isAnimatingText = false
    @State private var showRecordingUI = false
    @State private var showSettings = false
    @State private var showExportSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Solid background
                Color(hex: "2E2E2E")
                    .ignoresSafeArea()
                
                if speechManager.isLectureCompleted {
                    // Lecture completion screen
                    VStack(spacing: 30) {
                        // Header
                        HStack {
                            Button(action: {
                                speechManager.startNewLecture()
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Text("Lecture Complete")
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
                        
                        // Lecture text
                        ScrollView {
                            Text(speechManager.lectureText)
                                .font(.system(size: speechManager.fontSize, weight: .regular))
                                .foregroundColor(speechManager.textColor.color)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                        }
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        
                        // Export buttons
                        HStack(spacing: 20) {
                            Button(action: {
                                exportAsPDF()
                            }) {
                                VStack {
                                    Image(systemName: "doc.text")
                                        .font(.title)
                                        .foregroundColor(.white)
                                    Text("PDF")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.pink)
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                exportAsText()
                            }) {
                                VStack {
                                    Image(systemName: "doc.plaintext")
                                        .font(.title)
                                        .foregroundColor(.white)
                                    Text("Text")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.pink)
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showExportSheet = true
                            }) {
                                VStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title)
                                        .foregroundColor(.white)
                                    Text("Share")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.pink)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.bottom, 50)
                    }
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
                        
                        // Microphone button with expanded controls when recording
                        VStack(spacing: 20) {
                            if speechManager.isRecording {
                                // Expanded controls
                                HStack(spacing: 30) {
                                    Button(action: {
                                        speechManager.pauseRecording()
                                    }) {
                                        VStack {
                                            Image(systemName: "pause.fill")
                                                .font(.title)
                                                .foregroundColor(.white)
                                            Text("Pause")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 80, height: 60)
                                        .background(Color.orange)
                                        .cornerRadius(10)
                                    }
                                    
                                    Button(action: {
                                        speechManager.finishLecture()
                                    }) {
                                        VStack {
                                            Image(systemName: "stop.fill")
                                                .font(.title)
                                                .foregroundColor(.white)
                                            Text("Finish Lecture")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 80, height: 60)
                                        .background(Color.red)
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            
                            ZStack {
                                // Pink outline when recording
                                if speechManager.isRecording {
                                    Circle()
                                        .stroke(Color.pink, lineWidth: 4)
                                        .frame(width: 140, height: 140)
                                        .scaleEffect(1.2)
                                        .opacity(0.8)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: speechManager.isRecording)
                                }
                                
                                Button(action: {
                                    if speechManager.isAuthorized {
                                        if speechManager.isRecording {
                                            speechManager.stopRecording()
                                        } else {
                                            speechManager.startRecording()
                                        }
                                    } else {
                                        showingPermissionAlert = true
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(speechManager.isRecording ? Color.red : Color.white)
                                            .frame(width: 120, height: 120)
                                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                        
                                        Image(systemName: speechManager.isRecording ? "mic.fill" : "mic")
                                            .font(.system(size: 40, weight: .medium))
                                            .foregroundColor(speechManager.isRecording ? .white : .black)
                                    }
                                }
                                .scaleEffect(speechManager.isRecording ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: speechManager.isRecording)
                            }
                            
                            Text(speechManager.isRecording ? 
                                 (speechManager.selectedLanguage == .hebrew ? "לחץ לעצירה" : "Tap to Stop") : 
                                 (speechManager.selectedLanguage == .hebrew ? "לחץ להקלטה" : "Tap to Record"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                        .padding(.bottom, 50)
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
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showRecordingUI = true
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
                        .scaleEffect(showRecordingUI ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: showRecordingUI)
                        
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
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [speechManager.lectureText])
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
    
    private func exportAsPDF() {
        // Create a proper PDF document
        let pdfMetaData = [
            kCGPDFContextCreator: "MicroClass App",
            kCGPDFContextAuthor: "Y'aara",
            kCGPDFContextTitle: "Lecture Notes"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            let textRect = CGRect(x: 50, y: 50, width: pageWidth - 100, height: pageHeight - 100)
            let text = NSAttributedString(string: speechManager.lectureText, attributes: [
                .font: UIFont.systemFont(ofSize: speechManager.fontSize),
                .foregroundColor: UIColor(speechManager.textColor.color)
            ])
            
            text.draw(in: textRect)
        }
        
        // Share the PDF
        let activityVC = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
        
        // Fix popover presentation for iPad
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
    
    private func exportAsText() {
        let activityVC = UIActivityViewController(activityItems: [speechManager.lectureText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// Settings View
struct SettingsView: View {
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Font Size
                VStack(alignment: .leading) {
                    Text("Font Size")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Text("Small")
                            .foregroundColor(.gray)
                        Slider(value: $speechManager.fontSize, in: 12...32, step: 2)
                            .accentColor(.pink)
                        Text("Large")
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(Int(speechManager.fontSize))pt")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Text Color
                VStack(alignment: .leading) {
                    Text("Text Color")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                        ForEach(SpeechManager.TextColor.allCases, id: \.self) { color in
                            Button(action: {
                                speechManager.textColor = color
                            }) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: speechManager.textColor == color ? 3 : 0)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(hex: "2E2E2E"))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pink)
                }
            }
        }
    }
}

// Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}