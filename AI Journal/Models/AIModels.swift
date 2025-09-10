//
//  AIModels.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import Foundation
import SwiftUI

// MARK: - AI Recommendation Models

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
        case .mindfulness: return .mint
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
