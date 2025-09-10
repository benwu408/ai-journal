//
//  HomeView.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @State private var currentDate = Date()
    
    // Core Data Manager
    @StateObject private var coreDataManager = CoreDataManager.shared
    
    // Hardcoded mood data for now
    @State private var recentMoodTrend: MoodTrend = .neutral
    @State private var userName: String = "Ben"
    
    // Mood Tracker States
    @State private var currentMoodValue: Double = 2.0 // 0-4 scale
    @State private var showWhyModal: Bool = false
    @State private var whyText: String = ""
    @State private var hasMoodInteraction: Bool = false // Track if user has interacted with mood slider
    
    // Q&A States (New)
    @State private var currentQuestion: String = "How are you feeling?"
    @State private var currentAnswer: String = ""
    @State private var savedQuestions: [QuestionAnswer] = []
    @State private var isAnswerSaved: Bool = false
    @State private var showAddQuestionModal: Bool = false
    @State private var newQuestion: String = ""
    
    // Today's entry from database
    @State private var todaysEntry: JournalEntry?
    
    let moodEmojis = ["😔", "😐", "🙂", "😄", "🤩"]
    let whyTags = ["Work", "School", "Friends", "Family", "Health", "Weather", "Sleep", "Exercise", "Money", "Goals"]
    
    // Predefined questions for variety
    let predefinedQuestions = [
        "How are you feeling?",
        "What's on your mind today?",
        "What are you grateful for right now?",
        "What challenged you today?",
        "What made you smile today?",
        "What are you looking forward to?",
        "How did you take care of yourself today?",
        "What did you learn about yourself today?",
        "What would you tell your past self from this morning?",
        "If today had a color, what would it be and why?"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Good \(getTimeOfDay()), \(userName)!")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text(currentDate, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Recent mood trend:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(recentMoodTrend.description)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(recentMoodTrend.color)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Streak Tracker
                    StreakTrackerCard(coreDataManager: coreDataManager)
                    
                    // Mood Tracker
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How are you feeling today?")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // Mood Slider with safe bounds
                            HStack {
                                Text("😔")
                                    .font(.title2)
                                
                                Slider(
                                    value: Binding(
                                        get: { 
                                            let value = currentMoodValue.isFinite ? currentMoodValue : 2.0
                                            return max(0, min(4, value))
                                        },
                                        set: { newValue in
                                            let safeValue = newValue.isFinite ? newValue : 2.0
                                            currentMoodValue = max(0, min(4, safeValue))
                                            hasMoodInteraction = true // Mark that user has interacted
                                            
                                            // Only auto-save if user has interacted with mood
                                            if hasMoodInteraction {
                                                saveMoodDataOnly()
                                            }
                                        }
                                    ),
                                    in: 0...4,
                                    step: 1
                                )
                                .accentColor(.orange)
                                
                                Text("🤩")
                                    .font(.title2)
                            }
                            .padding(.horizontal)
                            
                            // Current Mood Display
                            let safeIndex = Int(max(0, min(4, currentMoodValue)))
                            Text(moodEmojis[safeIndex])
                                .font(.system(size: 60))
                            
                            // Show AI-generated emotions if available
                            if let todaysEntry = todaysEntry, !todaysEntry.emotionTagsArray.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("AI detected emotions:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach(todaysEntry.emotionTagsArray, id: \.self) { emotion in
                                            Text(emotion)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(16)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Why Button
                            Button(action: {
                                showWhyModal = true
                            }) {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    Text("Why do you think you feel this way?")
                                    
                                    if !whyText.isEmpty {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Q&A Section (Replaces Journal Entry and Reflection)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Daily Questions")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: {
                                showAddQuestionModal = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Current Question & Answer
                        VStack(alignment: .leading, spacing: 12) {
                            Text(currentQuestion)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                            
                            TextEditor(text: $currentAnswer)
                                .frame(minHeight: 100, maxHeight: 150)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onChange(of: currentAnswer) { oldValue, newValue in
                                    isAnswerSaved = false
                                }
                            
                            // Save Answer Button
                            if !currentAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnswerSaved {
                                Button(action: saveCurrentAnswer) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save Answer")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Answer Saved Indicator
                            if isAnswerSaved {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Answer saved")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Saved Q&As for today
                        if !savedQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Answers")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal)
                                
                                ForEach(Array(savedQuestions.enumerated()), id: \.offset) { index, qa in
                                    SavedQuestionAnswerCard(qa: qa, index: index + 1)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Mood Timeline
                    MoodTimelineView(coreDataManager: coreDataManager)
                    
                    // Journal Activity Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Journal Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let totalEntries = coreDataManager.getAllEntries().count
                        
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.orange)
                                Text("Total Entries")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(totalEntries)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.orange)
                                Text("This Week")
                                    .font(.subheadline)
                                Spacer()
                                let weekEntries = coreDataManager.getEntriesForDateRange(
                                    from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                                    to: Date()
                                ).count
                                Text("\(weekEntries)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Motivational Message
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keep Going! 🌟")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(getMotivationalMessage(totalEntries: coreDataManager.getAllEntries().count))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("AI Journal")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadTodaysEntry()
        }
        .sheet(isPresented: $showWhyModal) {
            WhyModalView(
                whyText: $whyText,
                isPresented: $showWhyModal
            )
        }
        .sheet(isPresented: $showAddQuestionModal) {
            AddQuestionModal(
                newQuestion: $newQuestion,
                predefinedQuestions: predefinedQuestions,
                isPresented: $showAddQuestionModal,
                onQuestionSelected: { question in
                    currentQuestion = question
                    currentAnswer = ""
                    isAnswerSaved = false
                }
            )
        }
        .onChange(of: whyText) { oldValue, newValue in
            if oldValue != newValue {
                // Auto-save mood data when why text changes with debouncing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Only save if user has interacted with mood or has meaningful data
                    if hasMoodInteraction || !whyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        saveMoodDataOnly()
                    }
                }
            }
        }
    }
    
    // MARK: - Core Data Functions
    
    private func loadTodaysEntry() {
        todaysEntry = coreDataManager.getTodaysEntry()
        
        if let entry = todaysEntry {
            // Populate UI with existing data - ensure mood value is finite
            let loadedMoodValue = entry.moodValue.isFinite ? entry.moodValue : 2.0
            currentMoodValue = max(0, min(4, loadedMoodValue))
            
            whyText = entry.whyText ?? ""
            
            // Load Q&As
            savedQuestions = entry.questionsArray
            
            // Set interaction flag if there's existing mood data
            hasMoodInteraction = entry.moodValue > 0
            
            // Debug output to verify data loading
            print("📱 Loading today's entry:")
            print("   Mood: \(entry.moodEmoji ?? "No emoji") (\(currentMoodValue))")
            print("   AI Emotions: \(entry.emotionTagsArray)")
            print("   Why Text: \(whyText.isEmpty ? "Empty" : "Has content")")
            print("   Q&As: \(savedQuestions.count) questions")
            print("   Has Mood Interaction: \(hasMoodInteraction)")
        } else {
            print("📱 No existing entry found - starting fresh")
            // Reset to defaults
            whyText = ""
            savedQuestions = []
            currentAnswer = ""
            isAnswerSaved = false
            hasMoodInteraction = false // No interaction for new entries
        }
        
        // Generate a new question if we don't have one
        if currentQuestion.isEmpty || currentQuestion == "How are you feeling?" {
            generateNewQuestion()
        }
        
        // Calculate recent mood trend
        calculateRecentMoodTrend()
    }
    
    private func saveCurrentAnswer() {
        let moodEmoji = moodEmojis[Int(max(0, min(4, currentMoodValue)))]
        
        let success = coreDataManager.saveQuestionAnswer(
            question: currentQuestion,
            answer: currentAnswer,
            moodValue: hasMoodInteraction ? currentMoodValue : 0,
            moodEmoji: hasMoodInteraction ? moodEmoji : "",
            emotionTags: [], // Emotions will be generated by AI
            whyText: whyText,
            whyTags: [] // No category tags anymore
        )
        
        if success {
            print("✅ Q&A saved successfully!")
            print("Question: \(currentQuestion)")
            print("Answer: \(currentAnswer.prefix(50))...")
            print("Mood: \(hasMoodInteraction ? "\(moodEmoji) (\(currentMoodValue))" : "Not set")")
            print("Why Text: \(whyText.isEmpty ? "None" : whyText.prefix(50))...")
            
            // Mark as saved and clear current answer
            isAnswerSaved = true
            currentAnswer = ""
            
            // Generate new question
            generateNewQuestion()
            
            // Reload today's entry to get updated data
            loadTodaysEntry()
            
            // Recalculate mood trend after saving
            calculateRecentMoodTrend()
            
            // Notify insights view to refresh
            NotificationCenter.default.post(name: NSNotification.Name("JournalDataUpdated"), object: nil)
        } else {
            print("❌ Failed to save Q&A")
        }
    }
    
    private func saveMoodDataOnly() {
        let moodEmoji = moodEmojis[Int(max(0, min(4, currentMoodValue)))]
        
        let success = coreDataManager.updateMoodData(
            moodValue: currentMoodValue,
            moodEmoji: moodEmoji,
            emotionTags: [], // Emotions will be generated by AI
            whyText: whyText,
            whyTags: [] // No category tags anymore
        )
        
        if success {
            print("✅ Mood data saved successfully!")
            print("Date: \(Date())")
            print("Mood: \(moodEmoji) (\(currentMoodValue))")
            print("Why Text: \(whyText.isEmpty ? "None" : whyText.prefix(50))...")
            
            // Recalculate mood trend after saving mood data
            calculateRecentMoodTrend()
            
            // Notify insights view to refresh
            NotificationCenter.default.post(name: NSNotification.Name("JournalDataUpdated"), object: nil)
        } else {
            print("❌ Failed to save mood data")
        }
    }
    
    private func getTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 5..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<21:
            return "evening"
        default:
            return "night"
        }
    }
    
    private func generateNewQuestion() {
        // Reset the answer saved state when generating a new question
        isAnswerSaved = false
        
        // Select a random question from predefined questions
        currentQuestion = predefinedQuestions.randomElement() ?? "What's on your mind today?"
        
        print("🎲 Generated new question: \(currentQuestion)")
    }
    
    private func calculateRecentMoodTrend() {
        let calendar = Calendar.current
        let today = Date()
        
        // Get mood data for the past 14 days (split into two 7-day periods)
        let past7Days = getAverageMoodForPeriod(from: calendar.date(byAdding: .day, value: -7, to: today)!, to: today)
        let previous7Days = getAverageMoodForPeriod(from: calendar.date(byAdding: .day, value: -14, to: today)!, to: calendar.date(byAdding: .day, value: -7, to: today)!)
        
        // Calculate the difference
        let moodDifference = past7Days - previous7Days
        
        // Get mood variability for the past 7 days to detect mixed patterns
        let moodVariability = getMoodVariability(days: 7)
        
        // Determine trend based on difference and variability
        if moodVariability > 1.5 { // High variability indicates mixed mood
            recentMoodTrend = .mixed
        } else if moodDifference >= 0.5 { // Significant improvement
            recentMoodTrend = .positive
        } else if moodDifference <= -0.5 { // Significant decline
            recentMoodTrend = .challenging
        } else { // Stable mood (small changes)
            recentMoodTrend = .neutral
        }
        
        print("📊 Mood Trend Analysis:")
        print("   Past 7 days average: \(String(format: "%.2f", past7Days))")
        print("   Previous 7 days average: \(String(format: "%.2f", previous7Days))")
        print("   Difference: \(String(format: "%.2f", moodDifference))")
        print("   Variability: \(String(format: "%.2f", moodVariability))")
        print("   Trend: \(recentMoodTrend.description)")
    }
    
    private func getAverageMoodForPeriod(from startDate: Date, to endDate: Date) -> Double {
        let entries = coreDataManager.getEntriesForDateRange(from: startDate, to: endDate)
        let moodEntries = entries.filter { $0.moodValue > 0 && $0.moodValue.isFinite } // Only include entries with valid mood data
        
        guard !moodEntries.isEmpty else { return 2.0 } // Default neutral mood if no data
        
        let totalMood = moodEntries.reduce(0.0) { $0 + $1.moodValue }
        guard totalMood.isFinite else { return 2.0 }
        
        let result = totalMood / Double(moodEntries.count)
        return result.isFinite ? result : 2.0
    }
    
    private func getMoodVariability(days: Int) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else { return 0.0 }
        
        let entries = coreDataManager.getEntriesForDateRange(from: startDate, to: endDate)
        let moodValues = entries.filter { $0.moodValue > 0 && $0.moodValue.isFinite }.map { $0.moodValue }
        
        guard moodValues.count > 1 else { return 0.0 }
        
        // Calculate standard deviation as a measure of variability
        let total = moodValues.reduce(0.0, +)
        guard total.isFinite else { return 0.0 }
        
        let average = total / Double(moodValues.count)
        guard average.isFinite else { return 0.0 }
        
        let squaredDifferences = moodValues.compactMap { value -> Double? in
            let diff = value - average
            let squared = pow(diff, 2)
            return squared.isFinite ? squared : nil
        }
        
        guard !squaredDifferences.isEmpty else { return 0.0 }
        
        let varianceTotal = squaredDifferences.reduce(0.0, +)
        guard varianceTotal.isFinite else { return 0.0 }
        
        let variance = varianceTotal / Double(squaredDifferences.count)
        guard variance.isFinite && variance >= 0 else { return 0.0 }
        
        let result = sqrt(variance)
        return result.isFinite ? result : 0.0
    }
    
    private func getMotivationalMessage(totalEntries: Int) -> String {
        switch totalEntries {
        case 0:
            return "Welcome to your journaling journey! Start by answering your first question today."
        case 1...3:
            return "Great start! You're building a healthy habit. Keep answering questions to unlock deeper insights."
        case 4...10:
            return "You're on a roll! Your consistency is paying off. Notice any patterns in your responses?"
        case 11...30:
            return "Impressive dedication! You're developing real self-awareness through your reflections."
        default:
            return "You're a journaling champion! Your commitment to self-reflection is truly inspiring."
        }
    }
}
