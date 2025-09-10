//
//  ChatModels.swift
//  AI Journal
//
//  Created by Ben Wu on 6/13/25.
//

import Foundation

// MARK: - Chat Models

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}
