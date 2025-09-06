//
//  CoreDataManager.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import Foundation
import CoreData

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AIJournal")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data saved successfully")
            } catch {
                print("❌ Core Data save error: \(error)")
            }
        }
    }
    
    // MARK: - Journal Entry Operations
    
    func createJournalEntry() -> JournalEntry {
        let entry = JournalEntry(context: context)
        return entry
    }
    
    // MARK: - AI Topic Classification
    
    private func classifyTopicsForEntry(_ entry: JournalEntry) {
        Task {
            let topics = await getAITopicsForEntry(entry)
            
            await MainActor.run {
                entry.aiTopicsArray = Array(topics)
                
                do {
                    try self.context.save()
                    print("🤖 AI topics classified and saved: \(topics)")
                } catch {
                    print("❌ Error saving AI topics: \(error)")
                }
            }
        }
    }
    
    private func classifyEmotionsForEntry(_ entry: JournalEntry) {
        Task {
            let emotions = await getAIEmotionsForEntry(entry)
            
            await MainActor.run {
                entry.emotionTagsArray = Array(emotions)
                
                do {
                    try self.context.save()
                    print("🤖 AI emotions classified and saved: \(emotions)")
                } catch {
                    print("❌ Error saving AI emotions: \(error)")
                }
            }
        }
    }
    
    private func getAITopicsForEntry(_ entry: JournalEntry) async -> Set<String> {
        guard Config.isAPIKeyConfigured else {
            print("🤖 AI Topic Classification: API key not configured, skipping")
            return []
        }
        
        let entryContent = [
            entry.journalText ?? "",
            entry.reflectionResponse ?? "",
            entry.whyText ?? "",
            entry.questionsArray.map { $0.question + " " + $0.answer }.joined(separator: " ")
        ].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !entryContent.isEmpty else {
            print("🤖 AI Topic Classification: No content to analyze")
            return []
        }
        
        let availableTopics = ["Self-worth", "Relationships", "Work & Career", "Health & Wellness", 
                              "Personal Growth", "Stress & Anxiety", "Gratitude & Joy", "Future & Goals"]
        let topicsString = availableTopics.joined(separator: ", ")
        
        let prompt = """
        Please analyze this journal entry and identify which topics it relates to. Choose the most relevant topics from this list: \(topicsString)
        
        Journal Entry Content:
        \(entryContent)
        
        Instructions:
        - Only select topics that are clearly relevant to the content
        - You can select multiple topics if they apply
        - If no topics clearly fit, respond with "None"
        - Respond with only the topic names, separated by commas
        - Be selective - only choose topics that genuinely match the content
        
        Topics:
        """
        
        do {
            let openAIService = OpenAIService()
            let response = try await openAIService.generateTopicClassification(prompt: prompt)
            
            let identifiedTopics = response
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.lowercased() != "none" }
                .filter { availableTopics.contains($0) }
            
            print("🤖 AI Topic Classification for entry: \(identifiedTopics)")
            return Set(identifiedTopics)
            
        } catch {
            print("🤖 AI Topic Classification failed: \(error)")
            return []
        }
    }
    
    private func getAIEmotionsForEntry(_ entry: JournalEntry) async -> Set<String> {
        guard Config.isAPIKeyConfigured else {
            print("🤖 AI Emotion Classification: API key not configured, skipping")
            return []
        }
        
        // Get all Q&A responses for today only
        let todayResponses = entry.questionsArray.map { $0.answer }.joined(separator: " ")
        
        guard !todayResponses.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🤖 AI Emotion Classification: No Q&A content to analyze")
            return []
        }
        
        let availableEmotions = ["Anxiety", "Excitement", "Loneliness", "Focused", "Grateful", "Tired", "Stressed", "Peaceful", "Motivated", "Overwhelmed"]
        let emotionsString = availableEmotions.joined(separator: ", ")
        
        let prompt = """
        Please analyze these journal responses from today and identify which emotions the person is most likely feeling. Choose the most relevant emotions from this list: \(emotionsString)
        
        Journal Responses:
        \(todayResponses)
        
        Instructions:
        - Only select emotions that are clearly evident from the responses
        - You can select multiple emotions if they apply
        - If no emotions clearly fit, respond with "None"
        - Respond with only the emotion names, separated by commas
        - Be selective - only choose emotions that genuinely match the content
        - Focus on the overall emotional tone of all responses combined
        
        Emotions:
        """
        
        do {
            let openAIService = OpenAIService()
            let response = try await openAIService.generateEmotionClassification(prompt: prompt)
            
            let identifiedEmotions = response
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.lowercased() != "none" }
                .filter { availableEmotions.contains($0) }
            
            print("🤖 AI Emotion Classification for entry: \(identifiedEmotions)")
            return Set(identifiedEmotions)
            
        } catch {
            print("🤖 AI Emotion Classification failed: \(error)")
            return []
        }
    }
    
    // MARK: - Q&A Operations (New)
    
    func saveQuestionAnswer(
        question: String,
        answer: String,
        moodValue: Double = 0,
        moodEmoji: String = "",
        emotionTags: [String] = [],
        whyText: String = "",
        whyTags: [String] = []
    ) -> Bool {
        // Check if there's already an entry for today
        let entry: JournalEntry
        if let existingEntry = getTodaysEntry() {
            entry = existingEntry
        } else {
            entry = createJournalEntry()
            entry.date = Date()
            entry.createdAt = Date()
        }
        
        // Create new Q&A
        let newQA = QuestionAnswer(
            question: question,
            answer: answer,
            timestamp: Date()
        )
        
        // Add to existing questions array
        var currentQuestions = entry.questionsArray
        currentQuestions.append(newQA)
        entry.questionsArray = currentQuestions
        
        // Update mood data if provided
        if moodValue > 0 {
            entry.moodValue = moodValue
            entry.moodEmoji = moodEmoji
            entry.emotionTagsArray = emotionTags
            entry.whyText = whyText
            entry.whyTagsArray = whyTags
        }
        
        entry.updatedAt = Date()
        
        do {
            try context.save()
            print("✅ Q&A saved successfully")
            
            // Classify topics using AI after successful save
            classifyTopicsForEntry(entry)
            classifyEmotionsForEntry(entry)
            
            return true
        } catch {
            print("❌ Core Data save error: \(error)")
            return false
        }
    }
    
    func updateMoodData(
        moodValue: Double,
        moodEmoji: String,
        emotionTags: [String],
        whyText: String = "",
        whyTags: [String] = []
    ) -> Bool {
        // Check if there's already an entry for today
        let entry: JournalEntry
        if let existingEntry = getTodaysEntry() {
            entry = existingEntry
        } else {
            entry = createJournalEntry()
            entry.date = Date()
            entry.createdAt = Date()
        }
        
        // Update mood data
        entry.moodValue = moodValue
        entry.moodEmoji = moodEmoji
        entry.emotionTagsArray = emotionTags
        entry.whyText = whyText
        entry.whyTagsArray = whyTags
        entry.updatedAt = Date()
        
        do {
            try context.save()
            print("✅ Mood data updated successfully")
            
            // Only classify topics, not emotions (emotions come from Q&A analysis)
            classifyTopicsForEntry(entry)
            
            return true
        } catch {
            print("❌ Core Data save error: \(error)")
            return false
        }
    }
    
    // MARK: - Legacy Methods (keeping for backward compatibility)
    
    func saveJournalEntry(
        journalText: String,
        moodValue: Double,
        moodEmoji: String,
        emotionTags: [String],
        whyText: String,
        whyTags: [String],
        reflectionPrompt: String,
        reflectionResponse: String
    ) -> Bool {
        
        // Check if there's already an entry for today
        let entry: JournalEntry
        if let existingEntry = getTodaysEntry() {
            entry = existingEntry
        } else {
            entry = createJournalEntry()
            entry.date = Date()
            entry.createdAt = Date()
        }
        
        entry.journalText = journalText
        entry.moodValue = moodValue
        entry.moodEmoji = moodEmoji
        entry.emotionTagsArray = emotionTags
        entry.whyText = whyText
        entry.whyTagsArray = whyTags
        entry.reflectionPrompt = reflectionPrompt
        entry.reflectionResponse = reflectionResponse
        entry.updatedAt = Date()
        
        do {
            try context.save()
            print("✅ Core Data saved successfully")
            
            // Classify topics using AI after successful save
            classifyTopicsForEntry(entry)
            classifyEmotionsForEntry(entry)
            
            return true
        } catch {
            print("❌ Core Data save error: \(error)")
            return false
        }
    }
    
    func saveReflectionOnly(
        prompt: String,
        response: String,
        date: Date = Date()
    ) -> Bool {
        
        // Check if there's already an entry for today
        let entry: JournalEntry
        if let existingEntry = getTodaysEntry() {
            entry = existingEntry
        } else {
            entry = createJournalEntry()
            entry.date = date
            entry.createdAt = Date()
        }
        
        entry.reflectionPrompt = prompt
        entry.reflectionResponse = response
        entry.updatedAt = Date()
        
        do {
            try context.save()
            print("✅ Core Data saved successfully")
            return true
        } catch {
            print("❌ Core Data save error: \(error)")
            return false
        }
    }
    
    func saveJournalOnly(
        journalText: String,
        moodValue: Double,
        moodEmoji: String,
        emotionTags: [String],
        whyText: String,
        whyTags: [String]
    ) -> Bool {
        
        // Check if there's already an entry for today
        let entry: JournalEntry
        if let existingEntry = getTodaysEntry() {
            entry = existingEntry
        } else {
            entry = createJournalEntry()
            entry.date = Date()
            entry.createdAt = Date()
        }
        
        entry.journalText = journalText
        entry.moodValue = moodValue
        entry.moodEmoji = moodEmoji
        entry.emotionTagsArray = emotionTags
        entry.whyText = whyText
        entry.whyTagsArray = whyTags
        entry.updatedAt = Date()
        
        do {
            try context.save()
            print("✅ Core Data saved successfully")
            return true
        } catch {
            print("❌ Core Data save error: \(error)")
            return false
        }
    }
    
    func saveMoodDataOnly(moodValue: Double, moodEmoji: String, emotionTags: [String], whyText: String = "", whyTags: [String] = []) -> Bool {
        let context = persistentContainer.viewContext
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if entry already exists for today
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", 
                                      today as NSDate, 
                                      Calendar.current.date(byAdding: .day, value: 1, to: today)! as NSDate)
        
        do {
            let existingEntries = try context.fetch(request)
            let entry: JournalEntry
            
            if let existingEntry = existingEntries.first {
                entry = existingEntry
                print("📝 Updating existing mood entry for today")
            } else {
                entry = JournalEntry(context: context)
                entry.date = Date()
                entry.id = UUID()
                print("📝 Creating new mood entry for today")
            }
            
            // Set mood data
            entry.moodValue = moodValue
            entry.moodEmoji = moodEmoji
            entry.emotionTagsArray = emotionTags
            
            // Set why data
            entry.whyText = whyText
            entry.whyTagsArray = whyTags
            
            try context.save()
            print("✅ Mood data saved successfully")
            return true
        } catch {
            print("❌ Error saving mood data: \(error)")
            return false
        }
    }
    
    // MARK: - Fetch Operations
    
    func getAllEntries() -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching entries: \(error)")
            return []
        }
    }
    
    func getTodaysEntry() -> JournalEntry? {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("❌ Error fetching today's entry: \(error)")
            return nil
        }
    }
    
    func getEntriesForDateRange(from startDate: Date, to endDate: Date) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching entries for date range: \(error)")
            return []
        }
    }
    
    func searchEntries(searchText: String) -> [JournalEntry] {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "journalText CONTAINS[cd] %@ OR reflectionResponse CONTAINS[cd] %@", searchText, searchText)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error searching entries: \(error)")
            return []
        }
    }
    
    // MARK: - Analytics & Insights
    
    func getAverageMoodForPeriod(days: Int) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND moodValue > 0", startDate as NSDate, endDate as NSDate)
        
        do {
            let entries = try context.fetch(request)
            let validEntries = entries.filter { $0.moodValue.isFinite }
            guard !validEntries.isEmpty else { return 2.0 } // Default neutral mood
            
            let totalMood = validEntries.reduce(0.0) { $0 + $1.moodValue }
            guard totalMood.isFinite else { return 2.0 }
            
            let result = totalMood / Double(validEntries.count)
            return result.isFinite ? result : 2.0
        } catch {
            print("❌ Failed to fetch average mood: \(error)")
            return 2.0 // Default neutral mood
        }
    }
    
    func getMostCommonEmotionTags(limit: Int = 5) -> [String] {
        let entries = getAllEntries()
        var tagCounts: [String: Int] = [:]
        
        for entry in entries {
            for tag in entry.emotionTagsArray {
                tagCounts[tag, default: 0] += 1
            }
        }
        
        return tagCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    // MARK: - Streak Tracking
    
    func getCurrentStreak() -> Int {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        var currentDate = today
        var checkedToday = false
        
        // Check each day going backwards from today
        while true {
            let startOfDay = calendar.startOfDay(for: currentDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let entriesForDay = getEntriesForDateRange(from: startOfDay, to: endOfDay)
            
            // Check if there's a completed entry for this day
            let hasCompletedEntry = entriesForDay.contains { entry in
                isEntryCompleted(entry)
            }
            
            if hasCompletedEntry {
                streak += 1
                // Move to previous day
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
                checkedToday = true
            } else {
                // If this is today and we haven't journaled yet, don't break the streak
                // Continue to check yesterday
                if !checkedToday && calendar.isDateInToday(currentDate) {
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                        break
                    }
                    currentDate = previousDay
                    checkedToday = true
                } else {
                    // Streak is broken
                    break
                }
            }
        }
        
        return streak
    }
    
    func getLongestStreak() -> Int {
        let allEntries = getAllEntries().sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
        guard !allEntries.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var longestStreak = 0
        var currentStreak = 0
        var lastEntryDate: Date?
        
        // Group entries by date and check for completed entries
        var entriesByDate: [String: [JournalEntry]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in allEntries {
            guard let entryDate = entry.date else { continue }
            let dateKey = dateFormatter.string(from: entryDate)
            
            if entriesByDate[dateKey] == nil {
                entriesByDate[dateKey] = []
            }
            entriesByDate[dateKey]?.append(entry)
        }
        
        // Sort dates and calculate streaks
        let sortedDates = entriesByDate.keys.sorted()
        
        for dateString in sortedDates {
            guard let entries = entriesByDate[dateString],
                  let date = dateFormatter.date(from: dateString) else { continue }
            
            // Check if any entry for this date is completed
            let hasCompletedEntry = entries.contains { isEntryCompleted($0) }
            
            if hasCompletedEntry {
                if let lastDate = lastEntryDate {
                    let daysBetween = calendar.dateComponents([.day], from: lastDate, to: date).day ?? 0
                    
                    if daysBetween == 1 {
                        // Consecutive day
                        currentStreak += 1
                    } else {
                        // Gap in entries, start new streak
                        longestStreak = max(longestStreak, currentStreak)
                        currentStreak = 1
                    }
                } else {
                    // First entry
                    currentStreak = 1
                }
                
                lastEntryDate = date
            }
        }
        
        // Don't forget to check the final streak
        longestStreak = max(longestStreak, currentStreak)
        
        return longestStreak
    }
    
    func getJournalingDaysThisMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        let entries = getEntriesForDateRange(from: startOfMonth, to: endOfMonth)
        
        // Group by date and count days with completed entries
        var daysWithEntries: Set<String> = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in entries {
            guard let entryDate = entry.date, isEntryCompleted(entry) else { continue }
            let dateKey = dateFormatter.string(from: entryDate)
            daysWithEntries.insert(dateKey)
        }
        
        return daysWithEntries.count
    }
    
    private func isEntryCompleted(_ entry: JournalEntry) -> Bool {
        // An entry is considered "completed" if it has any meaningful content
        let hasJournalText = !(entry.journalText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasReflection = !(entry.reflectionResponse?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasQuestions = !entry.questionsArray.isEmpty
        
        // For mood data to count, we need both mood value AND emotions (not just default mood)
        let hasMeaningfulMoodData = entry.moodValue > 0 && !entry.emotionTagsArray.isEmpty
        
        // Entry is completed if it has any of these:
        // - Journal text
        // - Reflection response  
        // - Q&A content
        // - Meaningful mood data (both mood value and emotions)
        return hasJournalText || hasReflection || hasQuestions || hasMeaningfulMoodData
    }
    
    // MARK: - Delete Operations
    
    func deleteEntry(_ entry: JournalEntry) {
        context.delete(entry)
        save()
    }
    
    func deleteAllEntries() {
        let request: NSFetchRequest<NSFetchRequestResult> = JournalEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            save()
        } catch {
            print("❌ Error deleting all entries: \(error)")
        }
    }
    
    // MARK: - Chat Message Methods
    
    func saveChatMessage(id: String, text: String, isFromUser: Bool, timestamp: Date) {
        let context = persistentContainer.viewContext
        
        // Check if message already exists
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "chatMessageId == %@", id)
        
        do {
            let existingMessages = try context.fetch(request)
            if !existingMessages.isEmpty {
                // Message already exists, don't duplicate
                return
            }
        } catch {
            print("Error checking for existing chat message: \(error)")
        }
        
        // Create new chat message entry
        let chatEntry = JournalEntry(context: context)
        chatEntry.id = UUID()
        chatEntry.date = timestamp
        chatEntry.chatMessageId = id
        chatEntry.chatMessageText = text
        chatEntry.chatIsFromUser = isFromUser
        chatEntry.chatTimestamp = timestamp
        
        do {
            try context.save()
            print("✅ Chat message saved successfully")
        } catch {
            print("❌ Failed to save chat message: \(error)")
        }
    }
    
    func getChatMessages() -> [ChatMessage] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        // Only get entries that are chat messages
        request.predicate = NSPredicate(format: "chatMessageId != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntry.chatTimestamp, ascending: true)]
        
        do {
            let entries = try context.fetch(request)
            return entries.compactMap { entry in
                guard let messageId = entry.chatMessageId,
                      let messageText = entry.chatMessageText,
                      let timestamp = entry.chatTimestamp else {
                    return nil
                }
                
                return ChatMessage(
                    id: UUID(uuidString: messageId) ?? UUID(),
                    text: messageText,
                    isFromUser: entry.chatIsFromUser,
                    timestamp: timestamp
                )
            }
        } catch {
            print("❌ Failed to fetch chat messages: \(error)")
            return []
        }
    }
    
    func clearChatHistory() {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "chatMessageId != nil")
        
        do {
            let chatEntries = try context.fetch(request)
            for entry in chatEntries {
                context.delete(entry)
            }
            try context.save()
            print("✅ Chat history cleared successfully")
        } catch {
            print("❌ Failed to clear chat history: \(error)")
        }
    }
    
    func getCommonEmotionTags(limit: Int = 5) -> [String] {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        // Get entries from the last 30 days
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "date >= %@ AND emotionTags != nil AND emotionTags != ''", thirtyDaysAgo as NSDate)
        
        do {
            let entries = try context.fetch(request)
            var emotionCount: [String: Int] = [:]
            
            // Count occurrences of each emotion
            for entry in entries {
                let emotions = entry.emotionTagsArray
                for emotion in emotions {
                    emotionCount[emotion, default: 0] += 1
                }
            }
            
            // Sort by frequency and return top emotions
            let sortedEmotions = emotionCount.sorted { $0.value > $1.value }
            return Array(sortedEmotions.prefix(limit).map { $0.key })
            
        } catch {
            print("❌ Failed to fetch common emotions: \(error)")
            return []
        }
    }
} 