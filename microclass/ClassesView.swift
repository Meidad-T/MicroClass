//
//  ClassesView.swift
//  microclass
//
//  Created by Meidad Troper on 10/24/25.
//

import SwiftUI

struct ClassesView: View {
    @ObservedObject var dataManager: DataManager
    @State private var showAddClassDialog = false
    @State private var newClassName = ""
    @State private var selectedColor: StudyClass.ClassColor = .pink
    @State private var editingClass: StudyClass? = nil
    @State private var showEditDialog = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "2E2E2E")
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("My Classes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            showAddClassDialog = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(.pink)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Classes Grid
                    if dataManager.classes.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "folder")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Classes Yet")
                                .font(.title2)
                                .foregroundColor(.gray)
                            
                            Text("Tap the + button to create your first class")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 20) {
                                ForEach(dataManager.classes) { studyClass in
                                    ZStack(alignment: .topTrailing) {
                                        NavigationLink(destination: ClassDetailView(studyClass: studyClass, dataManager: dataManager)) {
                                            ClassCardView(studyClass: studyClass)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // Edit button (pencil)
                                        Button(action: {
                                            // Present edit dialog with a copy of the class
                                            editingClass = studyClass
                                            showEditDialog = true
                                        }) {
                                            Image(systemName: "pencil.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .padding(8)
                                        }
                                        .offset(x: -6, y: 6)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showAddClassDialog) {
            AddClassView(dataManager: dataManager)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingClass) { classToEdit in
            EditClassView(dataManager: dataManager, studyClass: classToEdit)
                .preferredColorScheme(.dark)
        }
    }
}

struct ClassCardView: View {
    let studyClass: StudyClass
    
    var body: some View {
        VStack(spacing: 15) {
            // Color rectangle
            RoundedRectangle(cornerRadius: 15)
                // Make class card colors more vivid by using a small gradient and opacity for depth
                .fill(
                    LinearGradient(colors: [studyClass.color.color, studyClass.color.color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(height: 120)
                .overlay(
                    VStack {
                        Text(studyClass.name.prefix(2).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(studyClass.lectures.count) lectures")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
            
            // Class name
            Text(studyClass.name)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(20)
    }
}

struct AddClassView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var className = ""
    @State private var selectedColor: StudyClass.ClassColor = .pink
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Create New Class")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Class Name:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter class name", text: $className)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Choose Color:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 15) {
                        ForEach(StudyClass.ClassColor.allCases, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                    
                    Button("Create") {
                        dataManager.addClass(name: className, color: selectedColor)
                        dismiss()
                    }
                    .foregroundColor(.pink)
                    .disabled(className.isEmpty)
                }
            }
            .padding()
            .background(Color(hex: "2E2E2E"))
        }
    }
}

// MARK: - Edit Class View
struct EditClassView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let studyClass: StudyClass

    @State private var className: String
    @State private var selectedColor: StudyClass.ClassColor
    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""

    init(dataManager: DataManager, studyClass: StudyClass) {
        self.dataManager = dataManager
        self.studyClass = studyClass
        _className = State(initialValue: studyClass.name)
        _selectedColor = State(initialValue: studyClass.color)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Top bar: back/cancel
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    Spacer()
                }

                VStack(spacing: 12) {
                    Text("Edit Class")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Class Name:")
                            .foregroundColor(.white)
                        TextField("Name", text: $className)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color:")
                            .foregroundColor(.white)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(StudyClass.ClassColor.allCases, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0))
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Action row: Delete (small) | Save (big)
                HStack(spacing: 12) {
                    // smaller delete button (approx 1/3 width)
                    Button(role: .destructive) {
                        if !studyClass.lectures.isEmpty {
                            showDeleteConfirm = true
                        } else {
                            dataManager.deleteClass(studyClass)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 120)
                        .background(Color.red)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        var updated = studyClass
                        updated.name = className
                        updated.color = selectedColor
                        dataManager.updateClass(updated)
                        dismiss()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                            Text("Save")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .disabled(className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.bottom, 8)

            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "1F1F1F").opacity(0.85))
                    .background(.ultraThinMaterial)
            )
            .padding()
            .sheet(isPresented: $showDeleteConfirm) {
                // Confirmation sheet with typed "remove"
                VStack(spacing: 16) {
                    Text("Warning")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Deleting this class will remove all lectures in it. Type 'remove' to confirm.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)

                    TextField("Type 'remove' to confirm", text: $deleteConfirmText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    HStack(spacing: 16) {
                        Button("Cancel") { showDeleteConfirm = false }
                            .foregroundColor(.gray)

                        Button("Confirm", role: .destructive) {
                            dataManager.deleteClass(studyClass)
                            showDeleteConfirm = false
                            dismiss()
                        }
                        .disabled(deleteConfirmText.lowercased() != "remove")
                    }
                    .padding()
                }
                .padding()
                .background(Color(hex: "1F1F1F"))
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    ClassesView(dataManager: DataManager())
}

