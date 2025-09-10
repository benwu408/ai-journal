//
//  InsightsView.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import SwiftUI

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
