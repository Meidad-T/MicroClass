//
//  MainTabView.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var dataManager = DataManager()
    @StateObject private var speechManager = SpeechManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Record Tab
            RecordView(speechManager: speechManager, dataManager: dataManager)
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Record")
                }
                .tag(0)
            
            // Classes Tab
            ClassesView(dataManager: dataManager)
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Classes")
                }
                .tag(1)
        }
        .accentColor(.pink)
        .background(Color(hex: "2E2E2E"))
    }
}

#Preview {
    MainTabView()
}

