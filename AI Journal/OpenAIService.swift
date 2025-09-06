import Foundation

class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init() {}
    
    func generateWeeklySummary(entries: [JournalEntry]) async throws -> String {
        // Check if API key is configured
        guard Config.isAPIKeyConfigured else {
            throw OpenAIError.noAPIKey
        }
        
        guard Config.validateAPIKey() else {
            throw OpenAIError.invalidAPIKey
        }
        
        let prompt = createWeeklySummaryPrompt(entries: entries)
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a compassionate AI therapist and journal analyst. Your role is to provide thoughtful, empathetic weekly summaries of a user's journal entries. 
                    
                    Guidelines:
                    - Be warm, supportive, and non-judgmental
                    - Identify patterns in mood, emotions, and experiences
                    - Highlight growth, resilience, and positive moments
                    - Acknowledge challenges with empathy
                    - Keep summaries to 2-3 sentences, conversational and personal
                    - Use "you" to address the user directly
                    - Focus on insights that would be helpful for self-reflection
                    - Avoid clinical language - speak like a caring friend who really understands
                    """
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": Config.maxTokens,
            "temperature": Config.temperature
        ]
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("OpenAI API Error: Status code \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Error response: \(errorData)")
            }
            
            // Handle specific error codes
            switch httpResponse.statusCode {
            case 401:
                throw OpenAIError.unauthorizedAPIKey
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                throw OpenAIError.serverError
            default:
                throw OpenAIError.apiError(httpResponse.statusCode)
            }
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw OpenAIError.parsingError
            }
        } catch {
            throw OpenAIError.parsingError
        }
    }
    
    private func createWeeklySummaryPrompt(entries: [JournalEntry]) -> String {
        guard !entries.isEmpty else {
            return "The user hasn't written any journal entries this week. Please provide an encouraging message about starting their journaling journey."
        }
        
        var prompt = "Please analyze this week's journal entries and provide a warm, insightful summary:\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        for (index, entry) in entries.enumerated() {
            prompt += "--- Entry \(index + 1) ---\n"
            
            if let date = entry.date {
                prompt += "Date: \(dateFormatter.string(from: date))\n"
            }
            
            if entry.moodValue > 0 {
                prompt += "Mood: \(entry.moodEmoji ?? "🙂") (\(String(format: "%.1f", entry.moodValue))/4.0)\n"
            }
            
            if !entry.emotionTagsArray.isEmpty {
                prompt += "Emotions: \(entry.emotionTagsArray.joined(separator: ", "))\n"
            }
            
            if let whyText = entry.whyText, !whyText.isEmpty {
                prompt += "Why they felt this way: \(whyText)\n"
            }
            
            if !entry.whyTagsArray.isEmpty {
                prompt += "Context tags: \(entry.whyTagsArray.joined(separator: ", "))\n"
            }
            
            // Include Q&A content
            if !entry.questionsArray.isEmpty {
                prompt += "Questions & Answers:\n"
                for qa in entry.questionsArray {
                    prompt += "Q: \(qa.question)\nA: \(qa.answer)\n"
                }
            }
            
            // Include legacy content if present
            if let journalText = entry.journalText, !journalText.isEmpty {
                prompt += "Journal entry: \(journalText)\n"
            }
            
            if let reflectionResponse = entry.reflectionResponse, !reflectionResponse.isEmpty {
                prompt += "Reflection: \(reflectionResponse)\n"
            }
            
            prompt += "\n"
        }
        
        prompt += """
        
        Based on these entries, please provide a thoughtful 2-3 sentence summary that:
        1. Acknowledges the user's emotional journey this week
        2. Highlights any patterns, growth, or insights
        3. Offers gentle encouragement or validation
        
        Write as if you're a caring friend who has been following their journey.
        """
        
        return prompt
    }
    
    func generatePersonalizedRecommendations(entries: [JournalEntry]) async throws -> [AIRecommendation] {
        // Check if API key is configured
        guard Config.isAPIKeyConfigured else {
            throw OpenAIError.noAPIKey
        }
        
        guard Config.validateAPIKey() else {
            throw OpenAIError.invalidAPIKey
        }
        
        let prompt = createRecommendationsPrompt(entries: entries)
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a compassionate AI therapist and wellness coach. Your role is to analyze a user's journal entries and provide exactly 3 personalized recommendations.
                    
                    STRICT FORMAT REQUIREMENTS:
                    - Recommendation 1: A journaling prompt (category: "growth")
                    - Recommendation 2: A journaling prompt (category: "growth") 
                    - Recommendation 3: A mindfulness or physical activity (category: "mindfulness" or "lifestyle")
                    
                    For each recommendation, provide EXACTLY this JSON structure:
                    {
                        "icon": "system_icon_name",
                        "title": "Brief Title (max 4 words)",
                        "description": "Warm, supportive description explaining why this helps (1-2 sentences)",
                        "actionText": "Specific instruction starting with 'Write:' for journaling or activity description for mindfulness/lifestyle",
                        "category": "growth/mindfulness/lifestyle",
                        "priority": "high/medium/low"
                    }
                    
                    Guidelines:
                    - Be warm, empathetic, and non-judgmental
                    - Base recommendations on patterns you see in their entries
                    - For journaling prompts, use "Write:" followed by the specific prompt
                    - For activities, give clear, actionable instructions
                    - Use appropriate SF Symbols icon names (e.g., "pencil.and.outline", "wind", "figure.walk")
                    - Keep titles concise but meaningful
                    - Make descriptions personal and relevant to their recent experiences
                    - Prioritize based on emotional urgency (high for concerning patterns, medium for growth, low for maintenance)
                    
                    Return ONLY a valid JSON array with exactly 3 recommendations. No additional text.
                    """
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 800,
            "temperature": 0.7
        ]
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("OpenAI API Error: Status code \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Error response: \(errorData)")
            }
            
            // Handle specific error codes
            switch httpResponse.statusCode {
            case 401:
                throw OpenAIError.unauthorizedAPIKey
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                throw OpenAIError.serverError
            default:
                throw OpenAIError.apiError(httpResponse.statusCode)
            }
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                // Parse the JSON response into AIRecommendation objects
                return try parseRecommendationsFromJSON(content)
            } else {
                throw OpenAIError.parsingError
            }
        } catch {
            print("Failed to parse recommendations: \(error)")
            throw OpenAIError.parsingError
        }
    }
    
    private func createRecommendationsPrompt(entries: [JournalEntry]) -> String {
        guard !entries.isEmpty else {
            return """
            The user hasn't written any journal entries this week. Please provide 3 recommendations:
            1. A gentle journaling prompt to help them start
            2. A self-reflection journaling prompt
            3. A simple mindfulness activity
            """
        }
        
        var prompt = "Please analyze this week's journal entries and provide 3 personalized recommendations:\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        for (index, entry) in entries.enumerated() {
            prompt += "--- Entry \(index + 1) ---\n"
            
            if let date = entry.date {
                prompt += "Date: \(dateFormatter.string(from: date))\n"
            }
            
            if entry.moodValue > 0 {
                prompt += "Mood: \(entry.moodEmoji ?? "🙂") (\(String(format: "%.1f", entry.moodValue))/4.0)\n"
            }
            
            if !entry.emotionTagsArray.isEmpty {
                prompt += "Emotions: \(entry.emotionTagsArray.joined(separator: ", "))\n"
            }
            
            if let whyText = entry.whyText, !whyText.isEmpty {
                prompt += "Why they felt this way: \(whyText)\n"
            }
            
            if !entry.whyTagsArray.isEmpty {
                prompt += "Context tags: \(entry.whyTagsArray.joined(separator: ", "))\n"
            }
            
            // Include Q&A content
            if !entry.questionsArray.isEmpty {
                prompt += "Questions & Answers:\n"
                for qa in entry.questionsArray {
                    prompt += "Q: \(qa.question)\nA: \(qa.answer)\n"
                }
            }
            
            // Include legacy content if present
            if let journalText = entry.journalText, !journalText.isEmpty {
                prompt += "Journal entry: \(journalText)\n"
            }
            
            if let reflectionResponse = entry.reflectionResponse, !reflectionResponse.isEmpty {
                prompt += "Reflection: \(reflectionResponse)\n"
            }
            
            prompt += "\n"
        }
        
        prompt += """
        
        Based on these entries, provide exactly 3 recommendations:
        1. A journaling prompt that addresses their current emotional state or patterns
        2. A journaling prompt that encourages growth or deeper self-reflection
        3. A mindfulness exercise or physical activity that would benefit them right now
        
        Consider their mood patterns, emotional themes, and what would be most helpful for their wellbeing.
        """
        
        return prompt
    }
    
    private func parseRecommendationsFromJSON(_ jsonString: String) throws -> [AIRecommendation] {
        // Clean the JSON string (remove any markdown formatting)
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw OpenAIError.parsingError
        }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                var recommendations: [AIRecommendation] = []
                
                for (index, dict) in jsonArray.enumerated() {
                    guard index < 3 else { break } // Only take first 3
                    
                    let icon = dict["icon"] as? String ?? "lightbulb.fill"
                    let title = dict["title"] as? String ?? "Recommendation \(index + 1)"
                    let description = dict["description"] as? String ?? "A helpful suggestion for you."
                    let actionText = dict["actionText"] as? String ?? "Take action"
                    let categoryString = dict["category"] as? String ?? "growth"
                    let priorityString = dict["priority"] as? String ?? "medium"
                    
                    let category = RecommendationCategory(rawValue: categoryString.capitalized) ?? .growth
                    let priority = RecommendationPriority.from(string: priorityString)
                    
                    let recommendation = AIRecommendation(
                        icon: icon,
                        title: title,
                        description: description,
                        actionText: actionText,
                        category: category,
                        priority: priority
                    )
                    
                    recommendations.append(recommendation)
                }
                
                // Ensure we have exactly 3 recommendations
                while recommendations.count < 3 {
                    let fallbackRecommendation = AIRecommendation(
                        icon: "pencil.and.outline",
                        title: "Journal Reflection",
                        description: "Take a moment to reflect on your recent experiences.",
                        actionText: "Write: 'What am I learning about myself lately?'",
                        category: .growth,
                        priority: .medium
                    )
                    recommendations.append(fallbackRecommendation)
                }
                
                return Array(recommendations.prefix(3))
            } else {
                throw OpenAIError.parsingError
            }
        } catch {
            print("JSON parsing error: \(error)")
            throw OpenAIError.parsingError
        }
    }
    
    // MARK: - Topic Classification
    func generateTopicClassification(prompt: String) async throws -> String {
        guard Config.isAPIKeyConfigured else {
            throw OpenAIError.invalidAPIKey
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 50, // Short response for topic names
            "temperature": 0.3 // Lower temperature for more consistent classification
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.invalidRequest
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            } else {
                throw OpenAIError.serverError
            }
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Emotion Classification
    func generateEmotionClassification(prompt: String) async throws -> String {
        guard Config.isAPIKeyConfigured else {
            throw OpenAIError.invalidAPIKey
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 30, // Short response for emotion names
            "temperature": 0.2 // Lower temperature for more consistent classification
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.invalidRequest
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            } else {
                throw OpenAIError.serverError
            }
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateChatResponse(userMessage: String, context: String, previousMessages: [ChatMessage]) async throws -> String {
        // Check if API key is configured
        guard Config.isAPIKeyConfigured else {
            throw OpenAIError.noAPIKey
        }
        
        guard Config.validateAPIKey() else {
            throw OpenAIError.invalidAPIKey
        }
        
        // Build conversation history
        var messages: [[String: Any]] = [
            [
                "role": "system",
                "content": """
                You are a compassionate AI journal companion and therapist. Your role is to have meaningful conversations with the user about their thoughts, feelings, and experiences.
                
                Guidelines:
                - Be warm, empathetic, and non-judgmental
                - Ask thoughtful follow-up questions to encourage deeper reflection
                - Reference their journal entries and patterns when relevant
                - Provide gentle insights and validation
                - Keep responses conversational and personal (2-4 sentences)
                - Use "you" to address the user directly
                - Avoid clinical language - speak like a caring friend who understands
                - Help them explore their emotions and experiences
                - Encourage self-reflection and growth
                
                Context about the user:
                \(context)
                """
            ]
        ]
        
        // Add recent conversation history (last 10 messages for context)
        let recentMessages = Array(previousMessages.suffix(10))
        for message in recentMessages {
            messages.append([
                "role": message.isFromUser ? "user" : "assistant",
                "content": message.text
            ])
        }
        
        // Add current user message
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        let requestBody: [String: Any] = [
            "model": Config.openAIModel,
            "messages": messages,
            "max_tokens": 300, // Slightly higher for chat responses
            "temperature": 0.8 // More creative for conversations
        ]
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw OpenAIError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("OpenAI API Error: Status code \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Error response: \(errorData)")
            }
            
            // Handle specific error codes
            switch httpResponse.statusCode {
            case 401:
                throw OpenAIError.unauthorizedAPIKey
            case 429:
                throw OpenAIError.rateLimitExceeded
            case 500...599:
                throw OpenAIError.serverError
            default:
                throw OpenAIError.apiError(httpResponse.statusCode)
            }
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw OpenAIError.parsingError
            }
        } catch {
            throw OpenAIError.parsingError
        }
    }
}

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case invalidResponse
    case apiError(Int)
    case parsingError
    case noAPIKey
    case invalidAPIKey
    case unauthorizedAPIKey
    case rateLimitExceeded
    case serverError
    case invalidRequest
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .encodingError:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .parsingError:
            return "Failed to parse API response"
        case .noAPIKey:
            return "OpenAI API key not configured. Please add your API key to Config.swift"
        case .invalidAPIKey:
            return "Invalid OpenAI API key format. Please check your API key in Config.swift"
        case .unauthorizedAPIKey:
            return "Invalid or unauthorized API key. Please check your OpenAI API key"
        case .rateLimitExceeded:
            return "OpenAI API rate limit exceeded. Please try again later"
        case .serverError:
            return "OpenAI server error. Please try again later"
        case .invalidRequest:
            return "Invalid request"
        case .networkError:
            return "Network error"
        }
    }
} 