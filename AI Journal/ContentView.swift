//
//  ContentView.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import SwiftUI
import CoreData

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            InsightsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Insights")
                }
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
            
            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
        }
        .accentColor(.orange)
    }
}

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

struct InsightsView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var refreshTrigger = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Average Mood Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Average Mood")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let averageMood = coreDataManager.getAverageMoodForPeriod(days: 7)
                        let moodEmoji = getMoodEmoji(for: averageMood)
                        
                        HStack {
                            Text(moodEmoji)
                                .font(.system(size: 50))
                            
                            VStack(alignment: .leading) {
                                Text(String(format: "%.1f", averageMood))
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("out of 4.0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Streak & Consistency Tracker
                    StreakInsightsCard(coreDataManager: coreDataManager)
                    
                    // Mood Timeline (replaces Weekly Mood Chart)
                    MoodTimelineView(coreDataManager: coreDataManager)
                    
                    // AI Weekly Summary
                    AISummaryCard(coreDataManager: coreDataManager)
                    
                    // AI Recommendations
                    AIRecommendationsCard(coreDataManager: coreDataManager)
                    
                    // Most Common Emotions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Most Common Emotions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let commonEmotions = coreDataManager.getMostCommonEmotionTags(limit: 5)
                        
                        if commonEmotions.isEmpty {
                            Text("No emotion data yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(Array(commonEmotions.enumerated()), id: \.offset) { index, emotion in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                        
                                        Text(emotion)
                                            .font(.caption)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Topic Clusters
                    TopicClusters(coreDataManager: coreDataManager)
                    
                    // Journal Streak
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
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshInsightsData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
                refreshTrigger.toggle()
                refreshInsightsData()
            }
            .id(refreshTrigger) // Force view refresh when data changes
        }
    }
    
    private func refreshInsightsData() {
        let totalEntries = coreDataManager.getAllEntries().count
        let weekEntries = coreDataManager.getEntriesForDateRange(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            to: Date()
        ).count
        let averageMood = coreDataManager.getAverageMoodForPeriod(days: 7)
        let commonEmotions = coreDataManager.getMostCommonEmotionTags(limit: 5)
        
        print("📊 Insights Data Refresh:")
        print("   Total Entries: \(totalEntries)")
        print("   This Week Entries: \(weekEntries)")
        print("   Average Mood (7 days): \(String(format: "%.1f", averageMood))")
        print("   Common Emotions: \(commonEmotions)")
    }
    
    private func getMoodEmoji(for mood: Double) -> String {
        let moodEmojis = ["😔", "😐", "🙂", "😄", "🤩"]
        let index = Int(max(0, min(4, mood)))
        return moodEmojis[index]
    }
    
    private func getMotivationalMessage(totalEntries: Int) -> String {
        switch totalEntries {
        case 0:
            return "Welcome to your journaling journey! Start by writing your first entry today."
        case 1...3:
            return "Great start! You're building a healthy habit. Keep writing to unlock deeper insights."
        case 4...10:
            return "You're on a roll! Your consistency is paying off. Notice any patterns in your mood?"
        case 11...30:
            return "Impressive dedication! You're developing real self-awareness through your entries."
        default:
            return "You're a journaling champion! Your commitment to self-reflection is truly inspiring."
        }
    }
}

struct AISummaryCard: View {
    let coreDataManager: CoreDataManager
    @State private var aiSummary: String = "Generating your weekly summary..."
    @State private var isLoading: Bool = true
    @State private var lastUpdated: Date = Date()
    @State private var hasError: Bool = false
    @State private var lastDataHash: String = ""
    @State private var hasInitiallyLoaded: Bool = false
    @StateObject private var openAIService = OpenAIService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                Text("AI Weekly Summary")
                    .font(.headline)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                if hasError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unable to generate AI summary at the moment. Here's what we can see from your week:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(getFallbackSummary())
                            .font(.subheadline)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text(aiSummary)
                        .font(.subheadline)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .redacted(reason: isLoading ? .placeholder : [])
                }
                
                HStack {
                    Spacer()
                    Text(getFormattedTimestamp())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
        }
        .onAppear {
            // Only generate on first load
            if !hasInitiallyLoaded {
                generateAISummary()
                hasInitiallyLoaded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
            // Check if data has actually changed before regenerating
            checkAndRegenerateIfNeeded()
        }
    }
    
    private func checkAndRegenerateIfNeeded() {
        let currentDataHash = generateDataHash()
        
        if currentDataHash != lastDataHash {
            print("📊 AI Summary: Data changed, regenerating...")
            lastDataHash = currentDataHash
            generateAISummary()
        } else {
            print("📊 AI Summary: Data unchanged, using cached result")
        }
    }
    
    private func generateDataHash() -> String {
        let entries = getRecentEntries()
        
        // Create a hash based on entry content that would affect the summary
        var hashComponents: [String] = []
        
        for entry in entries {
            var entryComponents: [String] = []
            
            // Include key data that affects summaries
            if let date = entry.date {
                entryComponents.append(DateFormatter().string(from: date))
            }
            entryComponents.append(String(entry.moodValue))
            entryComponents.append(entry.moodEmoji ?? "")
            entryComponents.append(entry.emotionTagsArray.joined(separator: ","))
            entryComponents.append(entry.whyText ?? "")
            entryComponents.append(entry.whyTagsArray.joined(separator: ","))
            entryComponents.append(entry.journalText ?? "")
            entryComponents.append(entry.reflectionResponse ?? "")
            
            // Include Q&A data
            for qa in entry.questionsArray {
                entryComponents.append(qa.question)
                entryComponents.append(qa.answer)
            }
            
            hashComponents.append(entryComponents.joined(separator: "|"))
        }
        
        return hashComponents.joined(separator: "||")
    }
    
    private func generateAISummary() {
        isLoading = true
        hasError = false
        
        Task {
            do {
                let entries = getRecentEntries()
                let summary = try await openAIService.generateWeeklySummary(entries: entries)
                
                await MainActor.run {
                    self.aiSummary = summary
                    self.isLoading = false
                    self.lastUpdated = Date()
                    self.hasError = false
                    
                    print("✅ AI Summary generated successfully")
                    print("Summary: \(summary.prefix(100))...")
                }
            } catch {
                print("❌ Failed to generate AI summary: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                    
                    // If it's an API key error, provide helpful message
                    if error.localizedDescription.contains("API key") {
                        self.aiSummary = "Please configure your OpenAI API key to enable AI summaries."
                    }
                }
            }
        }
    }
    
    private func getRecentEntries() -> [JournalEntry] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return coreDataManager.getEntriesForDateRange(from: startDate, to: endDate)
    }
    
    private func getFallbackSummary() -> String {
        let entries = getRecentEntries()
        let averageMood = calculateAverageMood(entries: entries)
        let totalEntries = entries.count
        
        // Generate a simple fallback summary
        if totalEntries == 0 {
            return "You haven't written any entries this week. Consider starting with how you're feeling right now!"
        } else if totalEntries == 1 {
            return "You wrote 1 entry this week. Your mood was \(String(format: "%.1f", averageMood))/4.0. Keep building this healthy habit!"
        } else {
            let moodDescription = averageMood >= 3.0 ? "positive" : averageMood >= 2.0 ? "balanced" : "challenging"
            return "You wrote \(totalEntries) entries this week with an average mood of \(String(format: "%.1f", averageMood))/4.0. Your week seems to have been \(moodDescription). Keep reflecting on your experiences!"
        }
    }
    
    private func calculateAverageMood(entries: [JournalEntry]) -> Double {
        let validEntries = entries.filter { $0.moodValue > 0 && $0.moodValue.isFinite }
        guard !validEntries.isEmpty else { return 2.0 }
        
        let totalMood = validEntries.reduce(0.0) { $0 + $1.moodValue }
        guard totalMood.isFinite else { return 2.0 }
        
        let result = totalMood / Double(validEntries.count)
        return result.isFinite ? result : 2.0
    }
    
    private func getFormattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE @ h:mm a"
        return "Last updated: \(formatter.string(from: lastUpdated))"
    }
}

struct AIRecommendationsCard: View {
    let coreDataManager: CoreDataManager
    @State private var recommendations: [AIRecommendation] = []
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var lastUpdated: Date = Date()
    @State private var lastDataHash: String = ""
    @State private var hasInitiallyLoaded: Bool = false
    @StateObject private var openAIService = OpenAIService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("AI Recommendations")
                    .font(.headline)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            
            if hasError {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unable to generate AI recommendations at the moment. Here are some general suggestions:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    let fallbackRecommendations = getFallbackRecommendations()
                    VStack(spacing: 16) {
                        ForEach(Array(fallbackRecommendations.enumerated()), id: \.offset) { index, recommendation in
                            AIRecommendationItem(
                                recommendation: recommendation,
                                index: index + 1
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                        AIRecommendationItem(
                            recommendation: recommendation,
                            index: index + 1
                        )
                        .redacted(reason: isLoading ? .placeholder : [])
                    }
                }
                .padding(.horizontal)
            }
            
            // Timestamp
            HStack {
                Spacer()
                Text(getFormattedTimestamp())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.horizontal)
            }
        }
        .onAppear {
            // Only generate on first load
            if !hasInitiallyLoaded {
                generateAIRecommendations()
                hasInitiallyLoaded = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
            // Check if data has actually changed before regenerating
            checkAndRegenerateIfNeeded()
        }
    }
    
    private func checkAndRegenerateIfNeeded() {
        let currentDataHash = generateDataHash()
        
        if currentDataHash != lastDataHash {
            print("🤖 AI Recommendations: Data changed, regenerating...")
            lastDataHash = currentDataHash
            generateAIRecommendations()
        } else {
            print("🤖 AI Recommendations: Data unchanged, using cached result")
        }
    }
    
    private func generateDataHash() -> String {
        let entries = getWeeklyEntries()
        
        // Create a hash based on entry content that would affect recommendations
        var hashComponents: [String] = []
        
        for entry in entries {
            var entryComponents: [String] = []
            
            // Include key data that affects recommendations
            if let date = entry.date {
                entryComponents.append(DateFormatter().string(from: date))
            }
            entryComponents.append(String(entry.moodValue))
            entryComponents.append(entry.moodEmoji ?? "")
            entryComponents.append(entry.emotionTagsArray.joined(separator: ","))
            entryComponents.append(entry.whyText ?? "")
            entryComponents.append(entry.whyTagsArray.joined(separator: ","))
            entryComponents.append(entry.journalText ?? "")
            entryComponents.append(entry.reflectionResponse ?? "")
            
            // Include Q&A data
            for qa in entry.questionsArray {
                entryComponents.append(qa.question)
                entryComponents.append(qa.answer)
            }
            
            hashComponents.append(entryComponents.joined(separator: "|"))
        }
        
        return hashComponents.joined(separator: "||")
    }
    
    private func generateAIRecommendations() {
        isLoading = true
        hasError = false
        
        Task {
            do {
                let entries = getWeeklyEntries()
                let aiRecommendations = try await openAIService.generatePersonalizedRecommendations(entries: entries)
                
                await MainActor.run {
                    self.recommendations = aiRecommendations
                    self.isLoading = false
                    self.lastUpdated = Date()
                    self.hasError = false
                    
                    print("✅ AI Recommendations generated successfully")
                    print("Generated \(aiRecommendations.count) recommendations")
                }
            } catch {
                print("❌ Failed to generate AI recommendations: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.hasError = true
                    self.isLoading = false
                    self.recommendations = getFallbackRecommendations()
                }
            }
        }
    }
    
    private func getWeeklyEntries() -> [JournalEntry] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return coreDataManager.getEntriesForDateRange(from: startDate, to: endDate)
    }
    
    private func getFallbackRecommendations() -> [AIRecommendation] {
        let weeklyEntries = getWeeklyEntries()
        let averageMood = calculateWeeklyAverageMood(entries: weeklyEntries)
        
        // Generate simple fallback recommendations based on mood
        if averageMood < 2.0 {
            return [
                AIRecommendation(
                    icon: "pencil.and.outline",
                    title: "Journal: Self-Compassion",
                    description: "Your recent entries suggest you're being hard on yourself. Let's explore self-kindness.",
                    actionText: "Write: 'What would I tell a good friend going through what I'm experiencing?'",
                    category: .growth,
                    priority: .high
                ),
                AIRecommendation(
                    icon: "pencil.and.outline",
                    title: "Journal: Small Wins",
                    description: "Focus on the positive moments, however small they might be.",
                    actionText: "Write about three small things that went well this week",
                    category: .growth,
                    priority: .medium
                ),
                AIRecommendation(
                    icon: "figure.walk",
                    title: "Gentle Movement",
                    description: "A short walk can help shift your energy and perspective.",
                    actionText: "Take a 10-minute walk outside and notice your surroundings",
                    category: .lifestyle,
                    priority: .medium
                )
            ]
        } else {
            return [
                AIRecommendation(
                    icon: "pencil.and.outline",
                    title: "Journal: Gratitude Reflection",
                    description: "Your mood has been stable. Let's explore what you're grateful for.",
                    actionText: "Write: 'Three things I'm genuinely grateful for right now are...'",
                    category: .growth,
                    priority: .medium
                ),
                AIRecommendation(
                    icon: "pencil.and.outline",
                    title: "Journal: Future Self",
                    description: "You're in a good headspace to think about your goals and aspirations.",
                    actionText: "Write a letter to yourself one month from now",
                    category: .growth,
                    priority: .medium
                ),
                AIRecommendation(
                    icon: "wind",
                    title: "Mindful Breathing",
                    description: "Take a moment to center yourself with conscious breathing.",
                    actionText: "Practice 4-7-8 breathing for 5 minutes",
                    category: .mindfulness,
                    priority: .low
                )
            ]
        }
    }
    
    private func calculateWeeklyAverageMood(entries: [JournalEntry]) -> Double {
        let validEntries = entries.filter { $0.moodValue > 0 && $0.moodValue.isFinite }
        guard !validEntries.isEmpty else { return 2.0 }
        
        let totalMood = validEntries.reduce(0.0) { $0 + $1.moodValue }
        guard totalMood.isFinite else { return 2.0 }
        
        let result = totalMood / Double(validEntries.count)
        return result.isFinite ? result : 2.0
    }
    
    private func getFormattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE @ h:mm a"
        return "Last updated: \(formatter.string(from: lastUpdated))"
    }
}

struct AIRecommendationItem: View {
    let recommendation: AIRecommendation
    let index: Int
    @State private var showJournalingModal = false
    @State private var journalAnswer = ""
    @StateObject private var coreDataManager = CoreDataManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Priority indicator and icon
                VStack(spacing: 4) {
                    Image(systemName: recommendation.icon)
                        .font(.title2)
                        .foregroundColor(recommendation.category.color)
                        .frame(width: 30, height: 30)
                    
                    Circle()
                        .fill(recommendation.priority.color)
                        .frame(width: 8, height: 8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title and category
                    HStack {
                        Text(recommendation.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Text(recommendation.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(recommendation.category.color.opacity(0.2))
                            .foregroundColor(recommendation.category.color)
                            .cornerRadius(8)
                    }
                    
                    // Description
                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Action button (moved outside and made full width)
            Button(action: {
                if isJournalingPrompt() {
                    showJournalingModal = true
                } else {
                    // For non-journaling activities, just log the action
                    print("🎯 Recommendation action: \(recommendation.actionText)")
                }
            }) {
                HStack {
                    Image(systemName: isJournalingPrompt() ? "pencil.circle.fill" : "arrow.right.circle.fill")
                        .font(.caption)
                    
                    Text(isJournalingPrompt() ? getPromptText() : recommendation.actionText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .foregroundColor(recommendation.category.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(recommendation.category.color.opacity(0.1))
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    recommendation.category.color.opacity(0.05),
                    recommendation.category.color.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(recommendation.category.color.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showJournalingModal) {
            JournalingPromptModal(
                question: extractQuestionFromActionText(),
                answer: $journalAnswer,
                isPresented: $showJournalingModal,
                onSave: saveJournalingAnswer
            )
        }
    }
    
    private func isJournalingPrompt() -> Bool {
        return recommendation.title.contains("Journal:") || 
               recommendation.actionText.contains("Write:") ||
               recommendation.actionText.contains("Write about") ||
               recommendation.actionText.contains("List:")
    }
    
    private func extractQuestionFromActionText() -> String {
        let actionText = recommendation.actionText
        
        // Handle different formats of journaling prompts
        if actionText.contains("Write: '") && actionText.contains("'") {
            // Format: "Write: 'Right now, I need...'"
            let components = actionText.components(separatedBy: "'")
            if components.count >= 2 {
                return components[1]
            }
        } else if actionText.contains("Write about ") {
            // Format: "Write about 3 things you did well recently"
            return actionText.replacingOccurrences(of: "Write about ", with: "Tell me about ")
        } else if actionText.contains("List: '") && actionText.contains("'") {
            // Format: "List: 'I can control... vs I cannot control...'"
            let components = actionText.components(separatedBy: "'")
            if components.count >= 2 {
                return "Make a list: " + components[1]
            }
        } else if actionText.contains("Write: ") {
            // Format: "Write: 'I feel good because...'"
            return actionText.replacingOccurrences(of: "Write: ", with: "")
                .replacingOccurrences(of: "'", with: "")
        }
        
        // Fallback to the recommendation title without "Journal:"
        return recommendation.title.replacingOccurrences(of: "Journal: ", with: "")
    }
    
    private func getPromptText() -> String {
        let actionText = recommendation.actionText
        
        // Handle different formats of journaling prompts for button display
        if actionText.contains("Write: '") && actionText.contains("'") {
            // Format: "Write: 'Right now, I need...'"
            let components = actionText.components(separatedBy: "'")
            if components.count >= 2 {
                return "Write: " + components[1]
            }
        } else if actionText.contains("Write about ") {
            // Format: "Write about 3 things you did well recently"
            return actionText
        } else if actionText.contains("List: '") && actionText.contains("'") {
            // Format: "List: 'I can control... vs I cannot control...'"
            let components = actionText.components(separatedBy: "'")
            if components.count >= 2 {
                return "List: " + components[1]
            }
        } else if actionText.contains("Write: ") {
            // Format: "Write: I feel good because..."
            return actionText
        }
        
        // Fallback to the full action text
        return actionText
    }
    
    private func saveJournalingAnswer() {
        let question = extractQuestionFromActionText()
        
        // Get today's entry or create mood data if needed
        let todaysEntry = coreDataManager.getTodaysEntry()
        let moodValue = todaysEntry?.moodValue ?? 2.0
        let moodEmoji = todaysEntry?.moodEmoji ?? "🙂"
        let emotionTags = todaysEntry?.emotionTagsArray ?? []
        let whyText = todaysEntry?.whyText ?? ""
        let whyTags = todaysEntry?.whyTagsArray ?? []
        
        let success = coreDataManager.saveQuestionAnswer(
            question: question,
            answer: journalAnswer,
            moodValue: moodValue,
            moodEmoji: moodEmoji,
            emotionTags: emotionTags,
            whyText: whyText,
            whyTags: whyTags
        )
        
        if success {
            print("✅ Journaling prompt answer saved!")
            print("Question: \(question)")
            print("Answer: \(journalAnswer.prefix(100))...")
            
            // Clear the answer for next time
            journalAnswer = ""
            
            // Notify other views to refresh
            NotificationCenter.default.post(name: NSNotification.Name("JournalDataUpdated"), object: nil)
        } else {
            print("❌ Failed to save journaling prompt answer")
        }
    }
}

struct JournalingPromptModal: View {
    let question: String
    @Binding var answer: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Question Display
                VStack(alignment: .leading, spacing: 12) {
                    Text("Journaling Prompt")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text(question)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // Answer Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Answer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextEditor(text: $answer)
                        .frame(minHeight: 200)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // Save Button
                if !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: {
                        onSave()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Answer")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationTitle("Answer Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct AIRecommendation {
    let icon: String
    let title: String
    let description: String
    let actionText: String
    let category: RecommendationCategory
    let priority: RecommendationPriority
}

enum RecommendationCategory: String, CaseIterable {
    case selfCare = "Self-Care"
    case lifestyle = "Lifestyle"
    case social = "Social"
    case growth = "Growth"
    case mindfulness = "Mindfulness"
    case productivity = "Productivity"
    
    var color: Color {
        switch self {
        case .selfCare: return .pink
        case .lifestyle: return .green
        case .social: return .blue
        case .growth: return .purple
        case .mindfulness: return .indigo
        case .productivity: return .orange
        }
    }
}

enum RecommendationPriority: CaseIterable {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
    
    static func from(string: String) -> RecommendationPriority {
        switch string.lowercased() {
        case "high":
            return .high
        case "low":
            return .low
        default:
            return .medium
        }
    }
}

struct TopicClusters: View {
    let coreDataManager: CoreDataManager
    @State private var expandedTopics: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurring Themes")
                .font(.headline)
                .padding(.horizontal)
            
            let topics = getTopicClusters()
            
            if topics.isEmpty {
                Text("Not enough entries to identify themes yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(topics, id: \.title) { topic in
                        TopicClusterCard(
                            topic: topic,
                            isExpanded: expandedTopics.contains(topic.title),
                            onToggle: {
                                if expandedTopics.contains(topic.title) {
                                    expandedTopics.remove(topic.title)
                                } else {
                                    expandedTopics.insert(topic.title)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func getTopicClusters() -> [TopicCluster] {
        let entries = coreDataManager.getAllEntries()
        guard entries.count >= 3 else { return [] } // Need at least 3 entries to identify themes
        
        // Define topic keywords and their associated terms
        let topicKeywords: [String: [String]] = [
            "Self-worth": ["confidence", "self", "worth", "value", "doubt", "insecure", "proud", "accomplished", "failure", "success", "achievement", "validation", "approval", "criticism", "judgment"],
            "Relationships": ["friend", "family", "love", "relationship", "partner", "boyfriend", "girlfriend", "husband", "wife", "parent", "mother", "father", "sibling", "conflict", "argument", "support", "connection", "lonely", "social", "together"],
            "Work & Career": ["work", "job", "career", "boss", "colleague", "meeting", "project", "deadline", "promotion", "salary", "office", "business", "professional", "interview", "performance", "stress", "burnout", "productivity"],
            "Health & Wellness": ["health", "exercise", "workout", "gym", "diet", "nutrition", "sleep", "tired", "energy", "sick", "doctor", "medicine", "therapy", "mental", "physical", "wellness", "self-care", "meditation", "yoga"],
            "Personal Growth": ["learn", "growth", "develop", "improve", "change", "goal", "habit", "progress", "challenge", "overcome", "resilience", "mindset", "perspective", "wisdom", "insight", "reflection", "journey", "transformation"],
            "Stress & Anxiety": ["stress", "anxiety", "worry", "nervous", "panic", "overwhelmed", "pressure", "tension", "fear", "anxious", "concerned", "troubled", "restless", "uneasy", "burden", "struggle"],
            "Gratitude & Joy": ["grateful", "thankful", "appreciate", "blessing", "joy", "happy", "celebration", "positive", "wonderful", "amazing", "beautiful", "love", "smile", "laugh", "content", "peaceful", "blessed"],
            "Future & Goals": ["future", "plan", "goal", "dream", "aspiration", "hope", "vision", "ambition", "tomorrow", "next", "upcoming", "potential", "possibility", "opportunity", "direction", "path", "purpose"]
        ]
        
        var topicMatches: [String: [JournalEntry]] = [:]
        
        // Analyze each entry for topic keywords
        for entry in entries {
            let entryText = "\(entry.journalText ?? "") \(entry.reflectionResponse ?? "") \(entry.whyText ?? "")".lowercased()
            
            for (topicName, keywords) in topicKeywords {
                let matchCount = keywords.filter { keyword in
                    entryText.contains(keyword.lowercased())
                }.count
                
                // If entry contains at least 2 keywords from this topic, consider it a match
                if matchCount >= 2 {
                    if topicMatches[topicName] == nil {
                        topicMatches[topicName] = []
                    }
                    topicMatches[topicName]?.append(entry)
                }
            }
        }
        
        // Convert to TopicCluster objects, filtering out topics with less than 2 entries
        let clusters = topicMatches.compactMap { (topicName, entries) -> TopicCluster? in
            guard entries.count >= 2 else { return nil }
            
            let uniqueEntries = Array(Set(entries)) // Remove duplicates
            return TopicCluster(
                title: topicName,
                entryCount: uniqueEntries.count,
                entries: uniqueEntries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) },
                tagline: "You wrote about this \(uniqueEntries.count) \(uniqueEntries.count == 1 ? "time" : "times")."
            )
        }
        
        // Sort by entry count (most frequent first)
        return clusters.sorted { $0.entryCount > $1.entryCount }
    }
}

struct TopicClusterCard: View {
    let topic: TopicCluster
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Topic Header
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(topic.tagline)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(topic.entryCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(getTopicColor(for: topic.title))
                            .cornerRadius(12)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(getTopicColor(for: topic.title))
                            .font(.caption)
                    }
                }
                .padding()
                .background(getTopicColor(for: topic.title).opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content - Entry List
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(topic.entries.prefix(5).enumerated()), id: \.offset) { index, entry in
                        TopicEntryPreview(entry: entry, index: index + 1)
                    }
                    
                    if topic.entries.count > 5 {
                        Text("+ \(topic.entries.count - 5) more entries")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
    
    private func getTopicColor(for topic: String) -> Color {
        switch topic {
        case "Self-worth": return .purple
        case "Relationships": return .pink
        case "Work & Career": return .blue
        case "Health & Wellness": return .green
        case "Personal Growth": return .orange
        case "Stress & Anxiety": return .red
        case "Gratitude & Joy": return .yellow
        case "Future & Goals": return .indigo
        default: return .gray
        }
    }
}

struct TopicEntryPreview: View {
    let entry: JournalEntry
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Entry number
            Text("\(index)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.gray.opacity(0.6))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Date
                if let date = entry.date {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Preview text
                let previewText = getPreviewText(from: entry)
                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Mood indicator
                if entry.moodValue > 0 {
                    HStack(spacing: 4) {
                        Text(entry.moodEmoji ?? "🙂")
                            .font(.caption2)
                        Text(String(format: "%.1f", entry.moodValue))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func getPreviewText(from entry: JournalEntry) -> String {
        let journalText = entry.journalText ?? ""
        let reflectionText = entry.reflectionResponse ?? ""
        let whyText = entry.whyText ?? ""
        
        // Prioritize journal text, then reflection, then why text
        let fullText = !journalText.isEmpty ? journalText : 
                      !reflectionText.isEmpty ? reflectionText : whyText
        
        // Return first 100 characters
        if fullText.count > 100 {
            return String(fullText.prefix(100)) + "..."
        }
        return fullText
    }
}

struct TopicCluster {
    let title: String
    let entryCount: Int
    let entries: [JournalEntry]
    let tagline: String
}

struct HistoryView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var expandedDates: Set<String> = []
    
    // Search and Filter States
    @State private var searchText: String = ""
    @State private var showFilterModal: Bool = false
    @State private var filteredEntries: [JournalEntry] = []
    @State private var allEntries: [JournalEntry] = []
    
    // Filter States
    @State private var selectedDateRange: DateRangeFilter = .all
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var moodRangeMin: Double = 0
    @State private var moodRangeMax: Double = 4
    @State private var selectedEmotionTags: Set<String> = []
    @State private var selectedTopics: Set<String> = []
    @State private var hasActiveFilters: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar (Sticky)
                VStack(spacing: 12) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            
                            TextField("Search journal entries...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button(action: {
                            showFilterModal = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .foregroundColor(hasActiveFilters ? .orange : .gray)
                                
                                if hasActiveFilters {
                                    Text("Filtered")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hasActiveFilters ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Active Filters Summary
                    if hasActiveFilters {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(getActiveFilterSummary(), id: \.self) { filter in
                                    Text(filter)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(6)
                                }
                                
                                Button("Clear All") {
                                    clearAllFilters()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                
                // Results
                ScrollView {
                    VStack(spacing: 16) {
                        let groupedEntries = getGroupedFilteredEntries()
                        
                        if groupedEntries.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: searchText.isEmpty && !hasActiveFilters ? "book.closed" : "magnifyingglass")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text(searchText.isEmpty && !hasActiveFilters ? "No Journal Entries Yet" : "No Matching Entries")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Text(searchText.isEmpty && !hasActiveFilters ? 
                                    "Start writing your first entry on the Home tab!" : 
                                    "Try adjusting your search or filters")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 100)
                        } else {
                            // Results count
                            HStack {
                                Text("\(filteredEntries.count) \(filteredEntries.count == 1 ? "entry" : "entries") found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(groupedEntries.keys.sorted(by: >), id: \.self) { dateKey in
                                if let entries = groupedEntries[dateKey] {
                                    HistoryDateSection(
                                        dateKey: dateKey,
                                        entries: entries,
                                        isExpanded: expandedDates.contains(dateKey),
                                        searchText: searchText,
                                        onToggle: {
                                            if expandedDates.contains(dateKey) {
                                                expandedDates.remove(dateKey)
                                            } else {
                                                expandedDates.insert(dateKey)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                refreshHistoryData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
                refreshHistoryData()
            }
            .onChange(of: searchText) { _, _ in
                applyFilters()
            }
            .sheet(isPresented: $showFilterModal) {
                HistoryFilterModal(
                    selectedDateRange: $selectedDateRange,
                    customStartDate: $customStartDate,
                    customEndDate: $customEndDate,
                    moodRangeMin: $moodRangeMin,
                    moodRangeMax: $moodRangeMax,
                    selectedEmotionTags: $selectedEmotionTags,
                    selectedTopics: $selectedTopics,
                    availableEmotionTags: getAvailableEmotionTags(),
                    availableTopics: getAvailableTopics(),
                    isPresented: $showFilterModal,
                    onApply: {
                        applyFilters()
                    }
                )
            }
        }
    }
    
    private func refreshHistoryData() {
        allEntries = coreDataManager.getAllEntries()
        applyFilters()
        print("📚 History Data Refresh: \(allEntries.count) total entries")
    }
    
    private func applyFilters() {
        var filtered = allEntries
        
        // Apply search text filter
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let searchTerms = searchText.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            
            filtered = filtered.filter { entry in
                let searchableText = [
                    entry.journalText ?? "",
                    entry.reflectionResponse ?? "",
                    entry.whyText ?? "",
                    entry.emotionTagsArray.joined(separator: " "),
                    entry.whyTagsArray.joined(separator: " "),
                    entry.questionsArray.map { $0.question + " " + $0.answer }.joined(separator: " ")
                ].joined(separator: " ").lowercased()
                
                return searchTerms.allSatisfy { term in
                    searchableText.contains(term)
                }
            }
        }
        
        // Apply date range filter
        if selectedDateRange != .all {
            let dateRange = getDateRange(for: selectedDateRange)
            filtered = filtered.filter { entry in
                guard let entryDate = entry.date else { return false }
                return entryDate >= dateRange.start && entryDate <= dateRange.end
            }
        }
        
        // Apply mood range filter
        if moodRangeMin > 0 || moodRangeMax < 4 {
            filtered = filtered.filter { entry in
                entry.moodValue >= moodRangeMin && entry.moodValue <= moodRangeMax
            }
        }
        
        // Apply emotion tags filter
        if !selectedEmotionTags.isEmpty {
            filtered = filtered.filter { entry in
                let entryEmotions = Set(entry.emotionTagsArray)
                return !selectedEmotionTags.isDisjoint(with: entryEmotions)
            }
        }
        
        // Apply topics filter using stored AI topics
        if !selectedTopics.isEmpty {
            filtered = filtered.filter { entry in
                let entryTopics = Set(entry.aiTopicsArray)
                return !selectedTopics.isDisjoint(with: entryTopics)
            }
        }
        
        filteredEntries = filtered
        updateActiveFiltersStatus()
    }
    
    private func updateActiveFiltersStatus() {
        hasActiveFilters = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          selectedDateRange != .all ||
                          moodRangeMin > 0 ||
                          moodRangeMax < 4 ||
                          !selectedEmotionTags.isEmpty ||
                          !selectedTopics.isEmpty
    }
    
    private func clearAllFilters() {
        searchText = ""
        selectedDateRange = .all
        moodRangeMin = 0
        moodRangeMax = 4
        selectedEmotionTags = []
        selectedTopics = []
        applyFilters()
    }
    
    private func getActiveFilterSummary() -> [String] {
        var summary: [String] = []
        
        if selectedDateRange != .all {
            summary.append(selectedDateRange.displayName)
        }
        
        if moodRangeMin > 0 || moodRangeMax < 4 {
            summary.append("Mood: \(String(format: "%.0f", moodRangeMin))-\(String(format: "%.0f", moodRangeMax))")
        }
        
        if !selectedEmotionTags.isEmpty {
            summary.append("\(selectedEmotionTags.count) emotion\(selectedEmotionTags.count == 1 ? "" : "s")")
        }
        
        if !selectedTopics.isEmpty {
            summary.append("\(selectedTopics.count) topic\(selectedTopics.count == 1 ? "" : "s")")
        }
        
        return summary
    }
    
    private func getGroupedFilteredEntries() -> [String: [JournalEntry]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        
        var grouped: [String: [JournalEntry]] = [:]
        
        for entry in filteredEntries {
            guard let date = entry.date else { continue }
            let dateKey = formatter.string(from: date)
            
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(entry)
        }
        
        return grouped
    }
    
    private func getDateRange(for filter: DateRangeFilter) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .all:
            return (Date.distantPast, Date.distantFuture)
        case .pastWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .pastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .custom:
            return (customStartDate, customEndDate)
        }
    }
    
    private func getAvailableEmotionTags() -> [String] {
        // Return all predefined emotion tags from the app
        return ["Anxiety", "Excitement", "Loneliness", "Focused", "Grateful", "Tired", "Stressed", "Peaceful", "Motivated", "Overwhelmed"]
    }
    
    private func getAvailableTopics() -> [String] {
        // Use the same topic detection logic from TopicClusters
        return ["Self-worth", "Relationships", "Work & Career", "Health & Wellness", 
                "Personal Growth", "Stress & Anxiety", "Gratitude & Joy", "Future & Goals"]
    }
}

struct HistoryDateSection: View {
    let dateKey: String
    let entries: [JournalEntry]
    let isExpanded: Bool
    let searchText: String
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateKey)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Entries
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(entries.sorted(by: { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }), id: \.self) { entry in
                        HistoryEntryCard(entry: entry, searchText: searchText)
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}

struct HistoryEntryCard: View {
    let entry: JournalEntry
    let searchText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Entry Header
            HStack {
                // Mood indicator
                if entry.moodValue > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .foregroundColor(getMoodColor(entry.moodValue))
                        
                        Text(String(format: "%.0f", entry.moodValue))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(getMoodColor(entry.moodValue))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getMoodColor(entry.moodValue).opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()
                
                // Time
                if let date = entry.date {
                    Text(DateFormatter.timeFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Journal Content
            if let journalText = entry.journalText, !journalText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Journal Entry")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HighlightedText(text: journalText, searchText: searchText)
                        .font(.body)
                        .lineLimit(3)
                }
            }
            
            // Reflection
            if let reflection = entry.reflectionResponse, !reflection.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reflection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HighlightedText(text: reflection, searchText: searchText)
                        .font(.body)
                        .lineLimit(2)
                }
            }
            
            // Why Text
            if let whyText = entry.whyText, !whyText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why I Feel This Way")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HighlightedText(text: whyText, searchText: searchText)
                        .font(.body)
                        .lineLimit(2)
                }
            }
            
            // Emotions
            if !entry.emotionTagsArray.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emotions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(entry.emotionTagsArray, id: \.self) { emotion in
                                Text(emotion)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // Q&A
            if !entry.questionsArray.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Q&A (\(entry.questionsArray.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entry.questionsArray.prefix(2).enumerated()), id: \.offset) { index, qa in
                            VStack(alignment: .leading, spacing: 4) {
                                HighlightedText(text: qa.question, searchText: searchText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                HighlightedText(text: qa.answer, searchText: searchText)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                        
                        if entry.questionsArray.count > 2 {
                            Text("+ \(entry.questionsArray.count - 2) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func getMoodColor(_ mood: Double) -> Color {
        switch mood {
        case 0...1: return .red
        case 1...2: return .orange
        case 2...3: return .yellow
        case 3...4: return .green
        default: return .gray
        }
    }
}

struct HighlightedText: View {
    let text: String
    let searchText: String
    
    var body: some View {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
        } else {
            let searchTerms = searchText.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let attributedString = highlightText(text, searchTerms: searchTerms)
            Text(AttributedString(attributedString))
        }
    }
    
    private func highlightText(_ text: String, searchTerms: [String]) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Set default attributes
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        
        // Highlight search terms
        for term in searchTerms {
            let searchRange = NSString(string: text.lowercased()).range(of: term.lowercased())
            if searchRange.location != NSNotFound {
                attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: searchRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: searchRange)
            }
        }
        
        return attributedString
    }
}

// MARK: - Supporting Types

enum MoodTrend {
    case positive
    case neutral
    case challenging
    case mixed
    
    var description: String {
        switch self {
        case .positive: return "Improving"
        case .neutral: return "Stable"
        case .challenging: return "Declining"
        case .mixed: return "Variable"
        }
    }
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .blue
        case .challenging: return .red
        case .mixed: return .orange
        }
    }
}

struct MoodTimelineView: View {
    let coreDataManager: CoreDataManager
    @State private var selectedEntry: JournalEntry?
    @State private var showEntryModal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Timeline")
                .font(.headline)
                .padding(.horizontal)
            
            let timelineData = getTimelineData()
            
            if timelineData.isEmpty {
                Text("No mood data for the past 14 days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(timelineData.enumerated()), id: \.offset) { index, dayData in
                                MoodTimelineCard(
                                    dayData: dayData,
                                    onTap: {
                                        if let entry = dayData.entry {
                                            selectedEntry = entry
                                            showEntryModal = true
                                        }
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        // Scroll to the rightmost item (today) when the view appears
                        if !timelineData.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo(timelineData.count - 1, anchor: .trailing)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEntryModal) {
            if let entry = selectedEntry {
                MoodTimelineEntryModal(entry: entry, isPresented: $showEntryModal)
            }
        }
    }
    
    private func getTimelineData() -> [MoodTimelineData] {
        let calendar = Calendar.current
        let today = Date()
        var timelineData: [MoodTimelineData] = []
        
        // Get last 14 days (including today) - reversed order so today is at the end
        for i in -13...0 {
            guard let date = calendar.date(byAdding: .day, value: i, to: today) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let entries = coreDataManager.getEntriesForDateRange(from: startOfDay, to: endOfDay)
            
            if let entry = entries.first {
                let toneTag = getPrimaryToneTag(from: entry)
                let dayData = MoodTimelineData(
                    date: date,
                    moodValue: entry.moodValue,
                    emoji: entry.moodEmoji ?? "🙂",
                    toneTag: toneTag,
                    dayLabel: getDayLabel(for: date),
                    entry: entry,
                    hasData: true
                )
                timelineData.append(dayData)
            } else {
                // No entry for this day
                let dayData = MoodTimelineData(
                    date: date,
                    moodValue: 0,
                    emoji: "⚪",
                    toneTag: "No data",
                    dayLabel: getDayLabel(for: date),
                    entry: nil,
                    hasData: false
                )
                timelineData.append(dayData)
            }
        }
        
        // Return in chronological order (oldest to newest), so today appears at the right
        return timelineData
    }
    
    private func getPrimaryToneTag(from entry: JournalEntry) -> String {
        let emotions = entry.emotionTagsArray
        
        // Priority order for tone tags based on emotional significance
        let tonePriority = [
            "Overwhelmed", "Anxiety", "Stressed", "Lonely", // High priority negative
            "Excited", "Grateful", "Motivated", "Peaceful", // High priority positive
            "Tired", "Focused", "Loneliness" // Medium priority
        ]
        
        // Find the highest priority emotion
        for tone in tonePriority {
            if emotions.contains(tone) {
                return tone
            }
        }
        
        // If no priority emotions, return the first one or a default
        return emotions.first ?? "Neutral"
    }
    
    private func getDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "E" // Mon, Tue, etc.
            return formatter.string(from: date)
        }
    }
}

struct MoodTimelineCard: View {
    let dayData: MoodTimelineData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Mood emoji
                Text(dayData.emoji)
                    .font(.title)
                    .frame(height: 40)
                
                // Tone tag
                Text(dayData.toneTag)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(dayData.hasData ? getToneColor(for: dayData.toneTag) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        dayData.hasData ? 
                        getToneColor(for: dayData.toneTag).opacity(0.2) : 
                        Color.gray.opacity(0.1)
                    )
                    .cornerRadius(8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Day label
                Text(dayData.dayLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(dayData.hasData ? .primary : .secondary)
                
                // Mood value indicator (small dot)
                if dayData.hasData {
                    Circle()
                        .fill(getMoodColor(for: dayData.moodValue))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 70)
            .padding(.vertical, 12)
            .background(
                dayData.hasData ? 
                Color.white : 
                Color.gray.opacity(0.05)
            )
            .cornerRadius(12)
            .shadow(
                color: dayData.hasData ? Color.black.opacity(0.1) : Color.clear,
                radius: dayData.hasData ? 2 : 0,
                x: 0,
                y: 1
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        dayData.hasData ? Color.clear : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!dayData.hasData)
    }
    
    private func getToneColor(for tone: String) -> Color {
        switch tone.lowercased() {
        case "anxiety", "anxious", "overwhelmed", "stressed":
            return .red
        case "lonely", "loneliness", "sad":
            return .blue
        case "tired", "exhausted":
            return .orange
        case "excited", "motivated", "focused":
            return .green
        case "grateful", "peaceful", "happy":
            return .purple
        case "calm", "content":
            return .indigo
        default:
            return .gray
        }
    }
    
    private func getMoodColor(for moodValue: Double) -> Color {
        let safeMoodValue = max(0, min(4, moodValue))
        
        switch safeMoodValue {
        case 0..<1:
            return .red
        case 1..<2:
            return .orange
        case 2..<3:
            return .yellow
        case 3..<4:
            return .green
        case 4...:
            return .blue
        default:
            return .gray
        }
    }
}

struct MoodTimelineEntryModal: View {
    let entry: JournalEntry
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with date and mood
                    VStack(alignment: .leading, spacing: 12) {
                        if let date = entry.date {
                            Text(date, style: .date)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        if entry.moodValue > 0 {
                            HStack {
                                Text(entry.moodEmoji ?? "🙂")
                                    .font(.title)
                                
                                VStack(alignment: .leading) {
                                    Text("Mood: \(String(format: "%.1f", entry.moodValue))/4.0")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(getMoodDescription(for: entry.moodValue))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Emotions
                    if !entry.emotionTagsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emotions")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(entry.emotionTagsArray, id: \.self) { emotion in
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
                    }
                    
                    // Why section
                    if let whyText = entry.whyText, !whyText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why I felt this way")
                                .font(.headline)
                            
                            Text(whyText)
                                .font(.subheadline)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            
                            if !entry.whyTagsArray.isEmpty {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                    ForEach(entry.whyTagsArray, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Q&A section (New)
                    if !entry.questionsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Questions & Answers")
                                .font(.headline)
                            
                            ForEach(Array(entry.questionsArray.enumerated()), id: \.offset) { index, qa in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Q\(index + 1):")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.purple)
                                        
                                        Text(qa.question)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.purple)
                                        
                                        Spacer()
                                        
                                        Text(qa.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(qa.answer)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .background(Color.purple.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Legacy journal entry (for backward compatibility)
                    if let journalText = entry.journalText, !journalText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal Entry")
                                .font(.headline)
                            
                            Text(journalText)
                                .font(.subheadline)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Legacy reflection (for backward compatibility)
                    if let reflectionPrompt = entry.reflectionPrompt, !reflectionPrompt.isEmpty,
                       let reflectionResponse = entry.reflectionResponse, !reflectionResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Daily Reflection")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Prompt:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(reflectionPrompt)
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.secondary)
                                
                                Text("Response:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(reflectionResponse)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func getMoodDescription(for moodValue: Double) -> String {
        switch moodValue {
        case 0..<1:
            return "Very Low"
        case 1..<2:
            return "Low"
        case 2..<3:
            return "Neutral"
        case 3..<4:
            return "Good"
        case 4...:
            return "Excellent"
        default:
            return "Unknown"
        }
    }
}

struct MoodTimelineData {
    let date: Date
    let moodValue: Double
    let emoji: String
    let toneTag: String
    let dayLabel: String
    let entry: JournalEntry?
    let hasData: Bool
}

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
                    
                    TextEditor(text: $newQuestion)
                        .frame(minHeight: 80)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    if !newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: {
                            onQuestionSelected(newQuestion)
                            newQuestion = ""
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Use This Question")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // Predefined Questions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose from Suggestions")
                        .font(.headline)
                    
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
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Streak Tracker Components

struct StreakTrackerCard: View {
    let coreDataManager: CoreDataManager
    @State private var currentStreak: Int = 0
    @State private var streakMessage: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Streak")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(currentStreak)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text(currentStreak == 1 ? "day" : "days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !streakMessage.isEmpty {
                Text(streakMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .onAppear {
            updateStreakData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
            updateStreakData()
        }
    }
    
    private func updateStreakData() {
        currentStreak = coreDataManager.getCurrentStreak()
        streakMessage = getStreakMessage(for: currentStreak)
    }
    
    private func getStreakMessage(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Start your journaling journey today! 🌱"
        case 1:
            return "Great start! Keep it going tomorrow. 💪"
        case 2...3:
            return "Nice! You're building a healthy habit. 🎯"
        case 4...6:
            return "Awesome consistency! You're on fire! 🔥"
        case 7...13:
            return "Amazing! Over a week of journaling. 🌟"
        case 14...29:
            return "Incredible dedication! You're a journaling champion! 🏆"
        case 30...99:
            return "Phenomenal! A month+ of consistent reflection! 🚀"
        default:
            return "Legendary streak! You're an inspiration! 👑"
        }
    }
}

struct StreakInsightsCard: View {
    let coreDataManager: CoreDataManager
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var monthlyDays: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency & Streaks")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                // Current Streak
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("Current Streak")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(currentStreak)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text(currentStreak == 1 ? "day" : "days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Visual streak indicator
                    HStack(spacing: 2) {
                        ForEach(0..<min(currentStreak, 7), id: \.self) { _ in
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                        }
                        
                        if currentStreak > 7 {
                            Text("+\(currentStreak - 7)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)
                
                // Stats Grid
                HStack(spacing: 16) {
                    // Longest Streak
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("Best Streak")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack(alignment: .bottom, spacing: 2) {
                            Text("\(longestStreak)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("days")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.yellow.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Monthly Days
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("This Month")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack(alignment: .bottom, spacing: 2) {
                            Text("\(monthlyDays)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("days")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            updateStreakInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
            updateStreakInsights()
        }
    }
    
    private func updateStreakInsights() {
        currentStreak = coreDataManager.getCurrentStreak()
        longestStreak = coreDataManager.getLongestStreak()
        monthlyDays = coreDataManager.getJournalingDaysThisMonth()
    }
}

// MARK: - History Filter Types
enum DateRangeFilter: CaseIterable {
    case all
    case pastWeek
    case pastMonth
    case custom
    
    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .pastWeek: return "Past Week"
        case .pastMonth: return "Past Month"
        case .custom: return "Custom Range"
        }
    }
}

// MARK: - History Filter Modal
struct HistoryFilterModal: View {
    @Binding var selectedDateRange: DateRangeFilter
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    @Binding var moodRangeMin: Double
    @Binding var moodRangeMax: Double
    @Binding var selectedEmotionTags: Set<String>
    @Binding var selectedTopics: Set<String>
    
    let availableEmotionTags: [String]
    let availableTopics: [String]
    @Binding var isPresented: Bool
    let onApply: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date Range Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date Range")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            ForEach(DateRangeFilter.allCases, id: \.self) { range in
                                HStack {
                                    Button(action: {
                                        selectedDateRange = range
                                    }) {
                                        HStack {
                                            Image(systemName: selectedDateRange == range ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedDateRange == range ? .blue : .gray)
                                            
                                            Text(range.displayName)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        if selectedDateRange == .custom {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("From:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $customStartDate, displayedComponents: .date)
                                        .labelsHidden()
                                }
                                
                                HStack {
                                    Text("To:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $customEndDate, displayedComponents: .date)
                                        .labelsHidden()
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Mood Range Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood Range")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Text("From: \(String(format: "%.0f", moodRangeMin))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("To: \(String(format: "%.0f", moodRangeMax))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 16) {
                                Text("0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    Slider(value: $moodRangeMin, in: 0...4, step: 1)
                                        .accentColor(.blue)
                                    
                                    Slider(value: $moodRangeMax, in: 0...4, step: 1)
                                        .accentColor(.blue)
                                }
                                
                                Text("4")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Emotion Tags Filter
                    if !availableEmotionTags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emotions")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(availableEmotionTags, id: \.self) { tag in
                                    Button(action: {
                                        if selectedEmotionTags.contains(tag) {
                                            selectedEmotionTags.remove(tag)
                                        } else {
                                            selectedEmotionTags.insert(tag)
                                        }
                                    }) {
                                        Text(tag)
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedEmotionTags.contains(tag) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .foregroundColor(selectedEmotionTags.contains(tag) ? .blue : .primary)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                    // Topics Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Topics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                            ForEach(availableTopics, id: \.self) { topic in
                                Button(action: {
                                    if selectedTopics.contains(topic) {
                                        selectedTopics.remove(topic)
                                    } else {
                                        selectedTopics.insert(topic)
                                    }
                                }) {
                                    Text(topic)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedTopics.contains(topic) ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                                        .foregroundColor(selectedTopics.contains(topic) ? .orange : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Filter Entries")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Reset") {
                    selectedDateRange = .all
                    moodRangeMin = 0
                    moodRangeMax = 4
                    selectedEmotionTags = []
                    selectedTopics = []
                },
                trailing: Button("Apply") {
                    onApply()
                    isPresented = false
                }
                .fontWeight(.semibold)
            )
        }
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Chat View
struct ChatView: View {
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isTyping: Bool = false
    @ObservedObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var openAIService = OpenAIService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.orange)
                                    
                                    Text("Chat with Your Journal")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("I'm here to listen and help you reflect on your thoughts and feelings. What's on your mind?")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .padding(.top, 50)
                            }
                            
                            // Chat messages
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Typing indicator
                            if isTyping {
                                HStack {
                                    HStack(spacing: 4) {
                                        ForEach(0..<3) { index in
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 8, height: 8)
                                                .scaleEffect(isTyping ? 1.0 : 0.5)
                                                .animation(
                                                    Animation.easeInOut(duration: 0.6)
                                                        .repeatForever()
                                                        .delay(Double(index) * 0.2),
                                                    value: isTyping
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(20)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: messages.count) { _, _ in
                        // Auto-scroll to bottom when new message is added
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message Input
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 12) {
                        TextField("Type your message...", text: $messageText, axis: .vertical)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(25)
                            .lineLimit(1...4)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .orange)
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Journal Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadChatHistory()
            // Add initial greeting if no messages
            if messages.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    addJournalMessage("Hello! I'm your personal journal companion. I'm here to help you explore your thoughts and feelings. What would you like to talk about today?")
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // Clear input field immediately
        messageText = ""
        
        // Add user message
        let userMessage = ChatMessage(
            id: UUID(),
            text: trimmedMessage,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        // Save user message to Core Data
        saveChatMessage(userMessage)
        
        // Show typing indicator
        isTyping = true
        
        // Generate AI response
        Task {
            do {
                let response = try await generateAIResponse(to: trimmedMessage)
                
                await MainActor.run {
                    isTyping = false
                    addJournalMessage(response)
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    let errorMessage = "I'm having trouble connecting right now. Please try again in a moment."
                    addJournalMessage(errorMessage)
                    print("Chat AI Error: \(error)")
                }
            }
        }
    }
    
    private func addJournalMessage(_ text: String) {
        let journalMessage = ChatMessage(
            id: UUID(),
            text: text,
            isFromUser: false,
            timestamp: Date()
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            messages.append(journalMessage)
        }
        
        // Save AI message to Core Data
        saveChatMessage(journalMessage)
    }
    
    private func generateAIResponse(to userMessage: String) async throws -> String {
        // Get context from journal entries and previous chat messages
        let context = buildContextForAI()
        
        return try await openAIService.generateChatResponse(
            userMessage: userMessage,
            context: context,
            previousMessages: messages
        )
    }
    
    private func buildContextForAI() -> String {
        var context = "JOURNAL CONTEXT:\n"
        
        // Get recent journal entries (last 30 days)
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = coreDataManager.getEntriesForDateRange(from: thirtyDaysAgo, to: Date())
        
        if !recentEntries.isEmpty {
            context += "Recent journal entries from the past 30 days:\n\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            for entry in recentEntries.prefix(10) { // Limit to 10 most recent entries
                if let date = entry.date {
                    context += "--- \(dateFormatter.string(from: date)) ---\n"
                }
                
                if entry.moodValue > 0 {
                    context += "Mood: \(entry.moodEmoji ?? "🙂") (\(String(format: "%.1f", entry.moodValue))/4.0)\n"
                }
                
                if !entry.emotionTagsArray.isEmpty {
                    context += "Emotions: \(entry.emotionTagsArray.joined(separator: ", "))\n"
                }
                
                if let whyText = entry.whyText, !whyText.isEmpty {
                    context += "Why they felt this way: \(whyText)\n"
                }
                
                // Include Q&A content
                if !entry.questionsArray.isEmpty {
                    context += "Questions & Answers:\n"
                    for qa in entry.questionsArray {
                        context += "Q: \(qa.question)\nA: \(qa.answer)\n"
                    }
                }
                
                context += "\n"
            }
        } else {
            context += "No recent journal entries found.\n\n"
        }
        
        // Add mood trend information
        let averageMood = coreDataManager.getAverageMoodForPeriod(days: 7)
        context += "Recent mood trend (7 days): \(String(format: "%.1f", averageMood))/4.0\n"
        
        // Add common emotions
        let commonEmotions = coreDataManager.getCommonEmotionTags(limit: 5)
        if !commonEmotions.isEmpty {
            context += "Common emotions: \(commonEmotions.joined(separator: ", "))\n"
        }
        
        context += "\n"
        
        return context
    }
    
    private func loadChatHistory() {
        // Load previous chat messages from Core Data
        messages = coreDataManager.getChatMessages()
    }
    
    private func saveChatMessage(_ message: ChatMessage) {
        coreDataManager.saveChatMessage(
            id: message.id.uuidString,
            text: message.text,
            isFromUser: message.isFromUser,
            timestamp: message.timestamp
        )
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Chat Bubble View
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .cornerRadius(4, corners: .bottomRight)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        
                        Text(message.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(20)
                            .cornerRadius(4, corners: .bottomLeft)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                   radius: topRight, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                   radius: bottomRight, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                   radius: bottomLeft, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                   radius: topLeft, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)

        return path
    }
}

#Preview {
    ContentView()
}
