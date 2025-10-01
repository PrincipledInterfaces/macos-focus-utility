import Foundation
import Combine
import AppKit

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load API key from file or environment
        self.apiKey = OpenAIService.loadAPIKey()
    }
    
    private static func loadAPIKey() -> String {
        // Try multiple locations for the API key file
        let possiblePaths = [
            "openai_key.txt",
            "/Users/matthewreichard/git/macos-focus-utility/openai_key.txt",
            Bundle.main.path(forResource: "openai_key", ofType: "txt") ?? "",
            FileManager.default.currentDirectoryPath + "/openai_key.txt"
        ]
        
        print("🔑 Looking for OpenAI API key in locations:")
        for path in possiblePaths {
            print("  Checking: \(path)")
            if let key = try? String(contentsOfFile: path).trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty {
                print("✅ Loaded API key from file: \(path)")
                print("🔑 Key starts with: \(String(key.prefix(10)))...")
                return key
            }
        }
        
        // Fallback to environment variable
        let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if !envKey.isEmpty {
            print("✅ Loaded API key from environment variable")
            print("🔑 Key starts with: \(String(envKey.prefix(10)))...")
        } else {
            print("❌ No API key found in any location!")
            print("💡 Current working directory: \(FileManager.default.currentDirectoryPath)")
        }
        return envKey
    }
    
    func chatCompletion(
        messages: [ChatMessage],
        model: String = "gpt-4",
        maxTokens: Int? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            print("OpenAI API key is missing")
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }

        print("Making OpenAI API call with model: \(model)")

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Use provided maxTokens or determine based on model
        let tokenLimit = maxTokens ?? (model.contains("gpt-4") || model.contains("gpt-5") ? 4000 : 1000)
        print("🎯 Using token limit: \(tokenLimit)")

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            maxTokens: tokenLimit
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Log the raw response for debugging
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 OpenAI API HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ API Error Response: \(responseString)")
                        }
                    } else {
                        // Log successful response body for debugging
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("📦 API Response Body: \(responseString)")
                        }
                    }
                }
                return data
            }
            .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
            .sink(
                receiveCompletion: { taskCompletion in
                    if case .failure(let error) = taskCompletion {
                        print("❌ OpenAI API error: \(error.localizedDescription)")
                        if let decodingError = error as? DecodingError {
                            print("🔍 Decoding error details: \(decodingError)")
                        }
                        completion(.failure(error))
                    }
                },
                receiveValue: { response in
                    print("📊 Response has \(response.choices.count) choices")
                    if let message = response.choices.first?.message.content {
                        print("✅ OpenAI API success - received \(message.count) characters")
                        print("💬 Message content: \(message)")
                        completion(.success(message))
                    } else {
                        print("❌ OpenAI returned empty response or no content field")
                        completion(.failure(OpenAIError.emptyResponse))
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func parseNaturalLanguageTodos(
        input: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        print("🧠 Starting AI todo parsing for input: '\(input)'")
        
        guard !apiKey.isEmpty else {
            print("❌ Cannot parse todos: API key is missing")
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        print("✅ API key available, making OpenAI request...")
        
        let systemPrompt = """
        You are a helpful assistant that parses natural language input into discrete todo items.
        
        Parse the following input into separate, actionable todo items. Each todo should be:
        - Specific and actionable
        - A single task (not multiple tasks combined)
        - Clearly worded
        
        Return only the todo items, one per line, without numbers or bullet points.
        
        Example input: "I need to email John about the proposal and also check if the AWS bill is processed"
        Example output:
        Email John about the proposal
        Check if AWS bill is processed
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: input)
        ]
        
        chatCompletion(messages: messages) { result in
            switch result {
            case .success(let response):
                print("🎉 OpenAI API success! Response: '\(response)'")
                let todos = response
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                print("📝 Parsed todos: \(todos)")
                completion(.success(todos))
            case .failure(let error):
                print("❌ OpenAI API failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func analyzeNotificationUrgency(
        notification: TOMENotification,
        metaprompt: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        let systemPrompt = """
        You are an intelligent notification filter. Based on the user's metaprompt rules, determine if this notification should be allowed through or deferred.
        
        User's filtering rules:
        \(metaprompt)
        
        Analyze this notification and respond with only "ALLOW" or "DEFER".
        """
        
        let notificationText = """
        From: \(notification.source)
        Subject: \(notification.title)
        Content: \(notification.content)
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: notificationText)
        ]
        
        chatCompletion(messages: messages, model: "gpt-3.5-turbo") { result in
            switch result {
            case .success(let response):
                let shouldAllow = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased().contains("ALLOW")
                completion(.success(shouldAllow))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func generateMetapromptSuggestion(
        currentMetaprompt: String,
        recentDecisions: [NotificationDecision],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let systemPrompt = """
        You are an AI assistant that helps improve notification filtering rules based on user behavior.
        
        Current metaprompt:
        \(currentMetaprompt)
        
        Recent user corrections:
        \(recentDecisions.map { "\($0.notification.title): Should have been \($0.correctAction)" }.joined(separator: "\n"))
        
        Suggest an improved metaprompt that incorporates these learnings. Return only the improved metaprompt text.
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: "Please suggest an improved metaprompt.")
        ]
        
        chatCompletion(messages: messages) { result in
            completion(result)
        }
    }
    
    func estimateTaskDuration(
        task: String,
        completion: @escaping (Result<TimeInterval, Error>) -> Void
    ) {
        let systemPrompt = """
        You are a productivity assistant that estimates task duration.
        
        Estimate how long this task will take in minutes. Consider:
        - Task complexity
        - Typical time for similar tasks
        - Need for research or preparation
        
        Respond with only a number (minutes).
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: task)
        ]
        
        chatCompletion(messages: messages, model: "gpt-3.5-turbo") { result in
            switch result {
            case .success(let response):
                if let minutes = Double(response.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    completion(.success(TimeInterval(minutes * 60)))
                } else {
                    completion(.failure(OpenAIError.invalidResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func categorizeInstalledAppsForEnvironment(
        environment: String,
        installedApps: [InstalledApp],
        completion: @escaping (Result<[AppInfo], Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            print("❌ Cannot categorize apps: API key is missing")
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        let appsData = installedApps.map { app in
            "\(app.name) (\(app.bundleIdentifier ?? "unknown"))"
        }.joined(separator: "\n")
        
        let systemPrompt = """
        You are an intelligent app categorization system. Given a list of installed macOS applications and a work environment context, select the 4-6 most relevant apps for that environment.
        
        Environment: \(environment)
        
        Consider these environment types:
        - Planning: Apps for organization, task management, calendars, notes, mind mapping
        - Writer's Desk: Apps for writing, document editing, communication, email
        - Workshop: Apps for development, coding, terminals, version control, design tools
        - Coffeeshop: Apps for research, browsing, creativity, design, media consumption
        - Garden: Apps for relaxation, entertainment, music, meditation, breaks
        
        Return ONLY a JSON array of objects with this exact format:
        [
          {"name": "App Name", "bundleId": "bundle.id", "relevance": 0.9},
          ...
        ]
        
        - Select 4-6 most relevant apps
        - Use exact app names from the input list
        - Use exact bundle IDs from the input list
        - Include relevance score (0.0-1.0)
        - Sort by relevance (highest first)
        - No explanations, only JSON
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: appsData)
        ]
        
        chatCompletion(messages: messages, model: "gpt-3.5-turbo") { result in
            switch result {
            case .success(let response):
                do {
                    let data = response.data(using: .utf8) ?? Data()
                    let categorizedApps = try JSONDecoder().decode([CategorizedApp].self, from: data)
                    
                    let appInfos = categorizedApps.map { app in
                        AppInfo(name: app.name, bundleId: app.bundleId, icon: "app")
                    }
                    
                    print("✅ AI categorized \(appInfos.count) apps for \(environment)")
                    completion(.success(appInfos))
                } catch {
                    print("❌ Failed to parse AI response: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                print("❌ OpenAI API failed for app categorization: \(error)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Data Models

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: ChatMessage
    }
}

// TOMENotification is now defined in TOMEState.swift

// NotificationDecision is now defined in NotificationService.swift

enum OpenAIError: Error, LocalizedError {
    case missingAPIKey
    case emptyResponse
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not found. Please add your key to openai_key.txt or set OPENAI_API_KEY environment variable."
        case .emptyResponse:
            return "OpenAI returned an empty response."
        case .invalidResponse:
            return "OpenAI returned an invalid response format."
        }
    }
}

// Data models for AI app categorization
struct CategorizedApp: Codable {
    let name: String
    let bundleId: String
    let relevance: Double
}

struct InstalledApp {
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage?
}