//
//  InsightsViewComponents.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import SwiftUI

// MARK: - Supporting Views for InsightsView

struct StreakInsightsCard: View {
    let coreDataManager: CoreDataManager
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var journalingDaysThisMonth: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak & Consistency")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(currentStreak) days")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Longest Streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(longestStreak) days")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.green)
                    Text("This Month")
                        .font(.subheadline)
                    Spacer()
                    Text("\(journalingDaysThisMonth) days")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
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
        longestStreak = coreDataManager.getLongestStreak()
        journalingDaysThisMonth = coreDataManager.getJournalingDaysThisMonth()
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
