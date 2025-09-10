//
//  HomeViewComponents.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import SwiftUI

// MARK: - Supporting Views for HomeView

struct SavedQuestionAnswerCard: View {
    let qa: QuestionAnswer
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Q\(index):")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text(qa.question)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Spacer()
                
                Text(qa.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(qa.answer)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

struct AddQuestionModal: View {
    @Binding var newQuestion: String
    let predefinedQuestions: [String]
    @Binding var isPresented: Bool
    let onQuestionSelected: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Custom Question Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Your Own Question")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $newQuestion)
                        .frame(minHeight: 100)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .placeholder(when: newQuestion.isEmpty) {
                            Text("Enter your custom question here...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                        }
                }
                
                // Predefined Questions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Or Choose from Suggestions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(predefinedQuestions, id: \.self) { question in
                                Button(action: {
                                    onQuestionSelected(question)
                                    isPresented = false
                                }) {
                                    HStack {
                                        Text(question)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundColor(.orange)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Done") {
                    if !newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onQuestionSelected(newQuestion)
                    }
                    isPresented = false
                }
                .fontWeight(.semibold)
                .disabled(newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
    }
}

struct StreakTrackerCard: View {
    let coreDataManager: CoreDataManager
    @State private var currentStreak: Int = 0
    @State private var streakMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Journaling Streak")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(currentStreak) days")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Text(streakMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .onAppear {
            updateStreakData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
            updateStreakData()
        }
    }
    
    private func updateStreakData() {
        currentStreak = coreDataManager.getCurrentStreak()
        
        switch currentStreak {
        case 0:
            streakMessage = "Start your journaling journey today!"
        case 1:
            streakMessage = "Great start! Keep it going!"
        case 2...6:
            streakMessage = "Building momentum! You're doing great!"
        case 7...13:
            streakMessage = "One week strong! Consistency is key!"
        case 14...29:
            streakMessage = "Two weeks! You're developing a powerful habit!"
        case 30...99:
            streakMessage = "One month! You're a journaling champion!"
        default:
            streakMessage = "Incredible dedication! You're inspiring!"
        }
    }
}

// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
