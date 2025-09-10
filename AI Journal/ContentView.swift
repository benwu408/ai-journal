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

// MARK: - Mood Timeline View (Shared Component)
struct MoodTimelineView: View {
    let coreDataManager: CoreDataManager
    @State private var moodData: [MoodDataPoint] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Timeline")
                .font(.headline)
                .padding(.horizontal)
            
            if moodData.isEmpty {
                Text("No mood data yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(moodData, id: \.date) { dataPoint in
                            MoodDataPointView(dataPoint: dataPoint)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadMoodData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JournalDataUpdated"))) { _ in
            loadMoodData()
        }
    }
    
    private func loadMoodData() {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate
        
        let entries = coreDataManager.getEntriesForDateRange(from: startDate, to: endDate)
        let moodEntries = entries.filter { $0.moodValue > 0 && $0.moodValue.isFinite }
        
        var dataPoints: [MoodDataPoint] = []
        
        // Group by date
        let groupedEntries = Dictionary(grouping: moodEntries) { entry in
            calendar.startOfDay(for: entry.date ?? Date())
        }
        
        for (date, entries) in groupedEntries {
            let averageMood = entries.reduce(0.0) { $0 + $1.moodValue } / Double(entries.count)
            let moodEmoji = entries.first?.moodEmoji ?? "🙂"
            
            dataPoints.append(MoodDataPoint(
                date: date,
                moodValue: averageMood,
                moodEmoji: moodEmoji,
                entryCount: entries.count
            ))
        }
        
        moodData = dataPoints.sorted { $0.date < $1.date }
    }
}

struct MoodDataPointView: View {
    let dataPoint: MoodDataPoint
    
    var body: some View {
        VStack(spacing: 8) {
            Text(dataPoint.moodEmoji)
                .font(.title2)
            
            Text(String(format: "%.1f", dataPoint.moodValue))
                .font(.caption)
                .fontWeight(.medium)
            
            Text(dataPoint.date, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 60, height: 80)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct MoodDataPoint {
    let date: Date
    let moodValue: Double
    let moodEmoji: String
    let entryCount: Int
}

// MARK: - History View
struct HistoryView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var searchText = ""
    @State private var selectedEntry: JournalEntry?
    
    var body: some View {
        NavigationView {
            VStack {
                if coreDataManager.getAllEntries().isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Entries Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start journaling to see your history here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredEntries, id: \.id) { entry in
                            HistoryEntryRow(entry: entry)
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                        }
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }
    
    private var filteredEntries: [JournalEntry] {
        let entries = coreDataManager.getAllEntries()
        
        if searchText.isEmpty {
            return entries
        } else {
            return coreDataManager.searchEntries(searchText: searchText)
        }
    }
}

struct HistoryEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let date = entry.date {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if entry.moodValue > 0 {
                    HStack(spacing: 4) {
                        Text(entry.moodEmoji ?? "🙂")
                        Text(String(format: "%.1f", entry.moodValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let previewText = getPreviewText() {
                Text(previewText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if !entry.emotionTagsArray.isEmpty {
                HStack {
                    ForEach(entry.emotionTagsArray.prefix(3), id: \.self) { emotion in
                        Text(emotion)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                    
                    if entry.emotionTagsArray.count > 3 {
                        Text("+\(entry.emotionTagsArray.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getPreviewText() -> String? {
        let journalText = entry.journalText ?? ""
        let reflectionText = entry.reflectionResponse ?? ""
        let whyText = entry.whyText ?? ""
        
        let fullText = !journalText.isEmpty ? journalText : 
                      !reflectionText.isEmpty ? reflectionText : whyText
        
        return fullText.isEmpty ? nil : String(fullText.prefix(100)) + (fullText.count > 100 ? "..." : "")
    }
}

struct EntryDetailView: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        if let date = entry.date {
                            Text(date, style: .date)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        if entry.moodValue > 0 {
                            HStack {
                                Text(entry.moodEmoji ?? "🙂")
                                    .font(.title)
                                Text(String(format: "%.1f", entry.moodValue))
                                    .font(.title2)
                                    .fontWeight(.medium)
                                Text("out of 4.0")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
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
                    
                    // Why Text
                    if let whyText = entry.whyText, !whyText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why")
                                .font(.headline)
                            Text(whyText)
                                .font(.subheadline)
                        }
                    }
                    
                    // Q&A
                    if !entry.questionsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Questions & Answers")
                                .font(.headline)
                            
                            ForEach(Array(entry.questionsArray.enumerated()), id: \.offset) { index, qa in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Q\(index + 1): \(qa.question)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                    
                                    Text(qa.answer)
                                        .font(.subheadline)
                                    
                                    Text(qa.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Legacy content
                    if let journalText = entry.journalText, !journalText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal Entry")
                                .font(.headline)
                            Text(journalText)
                                .font(.subheadline)
                        }
                    }
                    
                    if let reflectionResponse = entry.reflectionResponse, !reflectionResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reflection")
                                .font(.headline)
                            Text(reflectionResponse)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Entry Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var isLoading = false
    @StateObject private var openAIService = OpenAIService.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if messages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "message.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Start a Conversation")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Ask me anything about your journal entries or how you're feeling")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                            }
                            
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                }
                
                // Message Input
                HStack {
                    TextField("Type your message...", text: $newMessage, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...4)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.orange)
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("AI Chat")
            .onAppear {
                loadMessages()
            }
        }
    }
    
    private func loadMessages() {
        messages = coreDataManager.getChatMessages()
    }
    
    private func sendMessage() {
        let messageText = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(
            id: UUID(),
            text: messageText,
            isFromUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        coreDataManager.saveChatMessage(
            id: userMessage.id.uuidString,
            text: userMessage.text,
            isFromUser: userMessage.isFromUser,
            timestamp: userMessage.timestamp
        )
        
        newMessage = ""
        isLoading = true
        
        // Generate AI response
        Task {
            do {
                let context = generateContext()
                let response = try await openAIService.generateChatResponse(
                    userMessage: messageText,
                    context: context,
                    previousMessages: messages
                )
                
                await MainActor.run {
                    let aiMessage = ChatMessage(
                        id: UUID(),
                        text: response,
                        isFromUser: false,
                        timestamp: Date()
                    )
                    
                    messages.append(aiMessage)
                    coreDataManager.saveChatMessage(
                        id: aiMessage.id.uuidString,
                        text: aiMessage.text,
                        isFromUser: aiMessage.isFromUser,
                        timestamp: aiMessage.timestamp
                    )
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        text: "I'm having trouble responding right now. Please try again later.",
                        isFromUser: false,
                        timestamp: Date()
                    )
                    
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
    
    private func generateContext() -> String {
        let recentEntries = coreDataManager.getEntriesForDateRange(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            to: Date()
        )
        
        var context = "Recent journal entries:\n"
        
        for entry in recentEntries.prefix(3) {
            if let date = entry.date {
                context += "\(date, style: .date): "
            }
            
            if entry.moodValue > 0 {
                context += "Mood: \(entry.moodEmoji ?? "🙂") (\(String(format: "%.1f", entry.moodValue))/4.0). "
            }
            
            if !entry.emotionTagsArray.isEmpty {
                context += "Emotions: \(entry.emotionTagsArray.joined(separator: ", ")). "
            }
            
            if let whyText = entry.whyText, !whyText.isEmpty {
                context += "Context: \(whyText). "
            }
            
            context += "\n"
        }
        
        return context
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.subheadline)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .cornerRadius(4, corners: .bottomTrailing)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.subheadline)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .cornerRadius(4, corners: .bottomLeading)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
