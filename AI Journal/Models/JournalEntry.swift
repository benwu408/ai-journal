//
//  JournalEntry.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import Foundation
import CoreData

// Q&A Data Structure
struct QuestionAnswer: Codable {
    let question: String
    let answer: String
    let timestamp: Date
}

@objc(JournalEntry)
public class JournalEntry: NSManagedObject {
    
}

extension JournalEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        return NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }
    
    // Basic Entry Info
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var journalText: String?
    
    // Mood Tracking
    @NSManaged public var moodValue: Double
    @NSManaged public var moodEmoji: String?
    @NSManaged public var emotionTags: String? // JSON string of array
    
    // Why Context
    @NSManaged public var whyText: String?
    @NSManaged public var whyTags: String? // JSON string of array
    
    // Questions & Answers (New Q&A format)
    @NSManaged public var questions: String? // JSON string of QuestionAnswer array
    
    // AI Classification
    @NSManaged public var aiTopics: String? // JSON string of AI-classified topics array
    
    // Chat Messages
    @NSManaged public var chatMessageId: String?
    @NSManaged public var chatMessageText: String?
    @NSManaged public var chatIsFromUser: Bool
    @NSManaged public var chatTimestamp: Date?
    
    // Daily Reflection (Legacy - keeping for backward compatibility)
    @NSManaged public var reflectionPrompt: String?
    @NSManaged public var reflectionResponse: String?
    
    // Metadata
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    // Computed properties for easier access
    var emotionTagsArray: [String] {
        get {
            guard let emotionTags = emotionTags, !emotionTags.isEmpty else { return [] }
            return (try? JSONDecoder().decode([String].self, from: emotionTags.data(using: .utf8) ?? Data())) ?? []
        }
        set {
            emotionTags = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? ""
        }
    }
    
    var whyTagsArray: [String] {
        get {
            guard let whyTags = whyTags, !whyTags.isEmpty else { return [] }
            return (try? JSONDecoder().decode([String].self, from: whyTags.data(using: .utf8) ?? Data())) ?? []
        }
        set {
            whyTags = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? ""
        }
    }
    
    var questionsArray: [QuestionAnswer] {
        get {
            guard let questions = questions, !questions.isEmpty else { return [] }
            return (try? JSONDecoder().decode([QuestionAnswer].self, from: questions.data(using: .utf8) ?? Data())) ?? []
        }
        set {
            questions = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? ""
        }
    }
    
    var aiTopicsArray: [String] {
        get {
            guard let aiTopics = aiTopics, !aiTopics.isEmpty else { return [] }
            return (try? JSONDecoder().decode([String].self, from: aiTopics.data(using: .utf8) ?? Data())) ?? []
        }
        set {
            aiTopics = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? ""
        }
    }
}

// MARK: - Convenience Initializer
extension JournalEntry {
    convenience init(context: NSManagedObjectContext) {
        self.init(entity: JournalEntry.entity(), insertInto: context)
        self.id = UUID()
        self.date = Date()
        self.journalText = ""
        self.moodValue = 2.0
        self.moodEmoji = "🙂"
        self.emotionTags = ""
        self.whyText = ""
        self.whyTags = ""
        self.questions = ""
        self.aiTopics = ""
        self.chatMessageId = nil
        self.chatMessageText = nil
        self.chatIsFromUser = false
        self.chatTimestamp = nil
        self.reflectionPrompt = ""
        self.reflectionResponse = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 