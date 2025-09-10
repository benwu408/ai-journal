//
//  MoodModels.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import Foundation
import SwiftUI

// MARK: - Mood Models

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
