import Foundation

struct Config {
    // MARK: - OpenAI Configuration
    
    /// Your OpenAI API Key
    /// Get your API key from: https://platform.openai.com/api-keys
    /// 
    /// IMPORTANT: Replace "YOUR_OPENAI_API_KEY" with your actual API key
    /// Example: "sk-proj-abc123def456..."
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY"
    
    // MARK: - API Settings
    
    static let openAIModel = "gpt-4.1-nano"
    static let maxTokens = 200
    static let temperature = 0.7
    
    // MARK: - Helper Methods
    
    static var isAPIKeyConfigured: Bool {
        return !openAIAPIKey.isEmpty && openAIAPIKey != "YOUR_OPENAI_API_KEY"
    }
    
    static func validateAPIKey() -> Bool {
        return openAIAPIKey.hasPrefix("sk-") && openAIAPIKey.count > 20
    }
} 