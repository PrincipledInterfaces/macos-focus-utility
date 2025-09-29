import Foundation
import Combine
import AppKit
import SwiftUI

class CreativeIntelligenceService: ObservableObject {
    @Published var currentFlow: CreativeFlow = .idle
    @Published var flowRecommendations: [FlowRecommendation] = []
    @Published var adaptiveInsights: [AdaptiveInsight] = []
    @Published var creativityScore: Double = 0.0
    @Published var optimalWorkingHours: [Int] = []
    @Published var contextualSuggestions: [ContextualSuggestion] = []
    
    // Learning and adaptation
    @Published var userPatterns: UserCreativePatterns = UserCreativePatterns()
    @Published var environmentPreferences: [TOMEEnvironment: EnvironmentPreference] = [:]
    @Published var toolUsagePatterns: [String: ToolUsagePattern] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private var openAIService: OpenAIService
    private var screenCaptureService: ScreenCaptureService?
    private var analysisTimer: Timer?
    
    // Intelligence data
    private var behaviorHistory: [BehaviorSnapshot] = []
    private var flowSessions: [FlowSession] = []
    private var contextSwitchEvents: [ContextSwitchEvent] = []
    
    init(openAIService: OpenAIService, screenCaptureService: ScreenCaptureService? = nil) {
        self.openAIService = openAIService
        self.screenCaptureService = screenCaptureService
        
        startIntelligenceAnalysis()
        loadUserPatterns()
        generateInitialRecommendations()
    }
    
    deinit {
        stopIntelligenceAnalysis()
        saveUserPatterns()
    }
    
    // MARK: - Intelligence Analysis
    
    private func startIntelligenceAnalysis() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.performIntelligenceAnalysis()
            }
        }
        
        // Subscribe to screen capture updates if available
        if #available(macOS 12.3, *), let screenService = screenCaptureService {
            screenService.$activeCreativeApps
                .sink { [weak self] apps in
                    self?.analyzeCreativeAppUsage(apps)
                }
                .store(in: &cancellables)
            
            screenService.$focusMetrics
                .sink { [weak self] metrics in
                    self?.updateCreativityScore(from: metrics)
                }
                .store(in: &cancellables)
        }
    }
    
    private func stopIntelligenceAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        cancellables.removeAll()
    }
    
    private func performIntelligenceAnalysis() async {
        await MainActor.run {
            // Capture current behavior snapshot
            let snapshot = captureBehaviorSnapshot()
            behaviorHistory.append(snapshot)
            
            // Analyze flow patterns
            analyzeFlowPatterns()
            
            // Update recommendations
            generateAdaptiveRecommendations()
            
            // Learn from patterns
            updateUserPatterns()
            
            // Generate AI insights
            generateAIInsights()
            
            // Clean old data
            cleanupOldData()
        }
    }
    
    private func captureBehaviorSnapshot() -> BehaviorSnapshot {
        let currentTime = Date()
        let hour = Calendar.current.component(.hour, from: currentTime)
        
        let activeApps = screenCaptureService?.activeCreativeApps.filter { $0.isActive }.map { $0.appName } ?? []
        
        return BehaviorSnapshot(
            timestamp: currentTime,
            hour: hour,
            activeApps: activeApps,
            screenActivity: screenCaptureService?.screenActivityLevel ?? .idle,
            currentFlow: currentFlow,
            focusScore: screenCaptureService?.focusMetrics.focusScore ?? 0.0
        )
    }
    
    // MARK: - Flow Pattern Analysis
    
    private func analyzeFlowPatterns() {
        guard behaviorHistory.count >= 5 else { return }
        
        let recentSnapshots = Array(behaviorHistory.suffix(10))
        
        // Detect current flow state
        let newFlow = detectFlowState(from: recentSnapshots)
        if newFlow != currentFlow {
            handleFlowStateChange(from: currentFlow, to: newFlow)
            currentFlow = newFlow
        }
        
        // Analyze productivity patterns
        analyzeProductivityPatterns(from: recentSnapshots)
        
        // Detect optimal working hours
        updateOptimalWorkingHours()
        
        // Analyze context switching patterns
        analyzeContextSwitching(from: recentSnapshots)
    }
    
    private func detectFlowState(from snapshots: [BehaviorSnapshot]) -> CreativeFlow {
        let avgFocusScore = snapshots.map { $0.focusScore }.reduce(0, +) / Double(snapshots.count)
        let consecutiveFocusedCount = countConsecutiveFocusedPeriods(snapshots)
        let appStability = measureAppStability(snapshots)
        
        if avgFocusScore >= 80 && consecutiveFocusedCount >= 3 && appStability >= 0.7 {
            return .deepFlow
        } else if avgFocusScore >= 60 && consecutiveFocusedCount >= 2 {
            return .activeFlow
        } else if avgFocusScore >= 40 {
            return .lightWork
        } else if snapshots.last?.activeApps.isEmpty == false {
            return .distracted
        } else {
            return .idle
        }
    }
    
    private func countConsecutiveFocusedPeriods(_ snapshots: [BehaviorSnapshot]) -> Int {
        var count = 0
        for snapshot in snapshots.reversed() {
            if snapshot.focusScore >= 70 {
                count += 1
            } else {
                break
            }
        }
        return count
    }
    
    private func measureAppStability(_ snapshots: [BehaviorSnapshot]) -> Double {
        guard snapshots.count > 1 else { return 1.0 }
        
        var stableCount = 0
        for i in 1..<snapshots.count {
            let prevApps = Set(snapshots[i-1].activeApps)
            let currentApps = Set(snapshots[i].activeApps)
            
            if !prevApps.isDisjoint(with: currentApps) {
                stableCount += 1
            }
        }
        
        return Double(stableCount) / Double(snapshots.count - 1)
    }
    
    private func handleFlowStateChange(from oldFlow: CreativeFlow, to newFlow: CreativeFlow) {
        let changeEvent = FlowChangeEvent(
            timestamp: Date(),
            fromFlow: oldFlow,
            toFlow: newFlow,
            duration: 0 // Would be calculated from previous flow start time
        )
        
        // Generate contextual suggestions based on flow change
        generateFlowTransitionSuggestions(for: changeEvent)
        
        print("🌊 Flow state changed: \(oldFlow.displayName) → \(newFlow.displayName)")
    }
    
    // MARK: - User Pattern Learning
    
    private func updateUserPatterns() {
        guard !behaviorHistory.isEmpty else { return }
        
        // Update hourly productivity patterns
        updateHourlyPatterns()
        
        // Update app usage patterns
        updateAppUsagePatterns()
        
        // Update environment preferences
        updateEnvironmentPreferences()
        
        // Update flow transition patterns
        updateFlowTransitionPatterns()
    }
    
    private func updateHourlyPatterns() {
        var hourlyData: [Int: [Double]] = [:]
        
        for snapshot in behaviorHistory {
            if hourlyData[snapshot.hour] == nil {
                hourlyData[snapshot.hour] = []
            }
            hourlyData[snapshot.hour]?.append(snapshot.focusScore)
        }
        
        var bestHours: [Int] = []
        for (hour, scores) in hourlyData {
            let avgScore = scores.reduce(0, +) / Double(scores.count)
            if avgScore >= 70 && scores.count >= 3 {
                bestHours.append(hour)
            }
        }
        
        optimalWorkingHours = bestHours.sorted()
    }
    
    private func updateAppUsagePatterns() {
        for snapshot in behaviorHistory {
            for appName in snapshot.activeApps {
                if toolUsagePatterns[appName] == nil {
                    toolUsagePatterns[appName] = ToolUsagePattern(
                        toolName: appName,
                        usageCount: 0,
                        totalDuration: 0,
                        averageFocusScore: 0,
                        bestHours: [],
                        commonPairings: []
                    )
                }
                
                toolUsagePatterns[appName]?.usageCount += 1
                toolUsagePatterns[appName]?.totalDuration += 60 // 1 minute per snapshot
            }
        }
    }
    
    private func updateEnvironmentPreferences() {
        // This would analyze which environments lead to best performance
        // For now, create sample data
        environmentPreferences[.workshop] = EnvironmentPreference(
            usageCount: 10,
            averageFocusScore: 85.0,
            preferredTimeRange: 9...17,
            commonTasks: ["Development", "Design", "Testing"]
        )
    }
    
    private func updateFlowTransitionPatterns() {
        // Analyze how users typically transition between flow states
        // This would help predict optimal times for breaks, deep work, etc.
    }
    
    // MARK: - AI-Powered Insights
    
    private func generateAIInsights() {
        Task {
            await generateProductivityInsights()
            await generateFlowOptimizationSuggestions()
            await generatePersonalizedRecommendations()
        }
    }
    
    private func generateProductivityInsights() async {
        guard !behaviorHistory.isEmpty else { return }
        
        let recentData = Array(behaviorHistory.suffix(50))
        let context = createAnalysisContext(from: recentData)
        
        let messages = [
            ChatMessage(role: "system", content: """
                You are an AI productivity coach specializing in creative workflows. Analyze user behavior data and provide actionable insights.
                Focus on patterns, opportunities for improvement, and personalized recommendations.
                Keep insights concise and actionable (2-3 sentences each).
                """),
            ChatMessage(role: "user", content: """
                Analyze this creative work pattern data and provide 3 key insights:
                
                \(context)
                
                Focus on: productivity patterns, optimal working times, and flow state optimization.
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let insights):
                    self?.parseAndStoreInsights(insights)
                case .failure(let error):
                    print("Failed to generate AI insights: \(error)")
                }
            }
        }
    }
    
    private func generateFlowOptimizationSuggestions() async {
        let messages = [
            ChatMessage(role: "system", content: """
                You are a flow state optimization expert. Based on creative work patterns, suggest specific techniques and timing for achieving optimal flow states.
                Provide practical, actionable suggestions that can be implemented immediately.
                """),
            ChatMessage(role: "user", content: """
                Based on the current creativity score of \(creativityScore)% and recent flow patterns, suggest 2-3 specific optimizations for achieving better flow states in creative work.
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let suggestions):
                    self?.parseFlowOptimizationSuggestions(suggestions)
                case .failure(let error):
                    print("Failed to generate flow optimization suggestions: \(error)")
                }
            }
        }
    }
    
    private func generatePersonalizedRecommendations() async {
        let messages = [
            ChatMessage(role: "system", content: """
                You are a personalized workflow optimizer. Based on individual work patterns and preferences, suggest specific workflow improvements and tool recommendations.
                Focus on creative professionals and provide practical suggestions that fit their established patterns.
                """),
            ChatMessage(role: "user", content: """
                Generate 3 personalized workflow recommendations based on these patterns:
                - Optimal working hours: \(optimalWorkingHours)
                - Current creativity score: \(creativityScore)%
                - Most used tools: \(Array(toolUsagePatterns.keys.prefix(3)))
                
                Suggest specific actions for improving creative productivity.
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let recommendations):
                    self?.parsePersonalizedRecommendations(recommendations)
                case .failure(let error):
                    print("Failed to generate personalized recommendations: \(error)")
                }
            }
        }
    }
    
    // MARK: - Recommendation Generation
    
    private func generateAdaptiveRecommendations() {
        flowRecommendations.removeAll()
        
        // Time-based recommendations
        generateTimeBasedRecommendations()
        
        // Flow state recommendations
        generateFlowStateRecommendations()
        
        // Tool optimization recommendations
        generateToolOptimizationRecommendations()
        
        // Environment recommendations
        generateEnvironmentRecommendations()
    }
    
    private func generateTimeBasedRecommendations() {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        if optimalWorkingHours.contains(currentHour) {
            flowRecommendations.append(FlowRecommendation(
                type: .timing,
                title: "Peak Performance Time",
                description: "This is one of your most productive hours. Consider tackling challenging creative tasks now.",
                priority: .high,
                actionable: true,
                estimatedImpact: 0.8
            ))
        } else if currentHour >= 22 || currentHour <= 6 {
            flowRecommendations.append(FlowRecommendation(
                type: .timing,
                title: "Rest Period Detected",
                description: "Working late may impact tomorrow's creativity. Consider winding down.",
                priority: .medium,
                actionable: true,
                estimatedImpact: 0.6
            ))
        }
    }
    
    private func generateFlowStateRecommendations() {
        switch currentFlow {
        case .idle:
            flowRecommendations.append(FlowRecommendation(
                type: .flowState,
                title: "Ready to Start",
                description: "Begin with a quick warm-up task to ease into focused work.",
                priority: .medium,
                actionable: true,
                estimatedImpact: 0.7
            ))
            
        case .lightWork:
            flowRecommendations.append(FlowRecommendation(
                type: .flowState,
                title: "Building Momentum",
                description: "You're getting started. Try eliminating distractions to deepen your focus.",
                priority: .high,
                actionable: true,
                estimatedImpact: 0.8
            ))
            
        case .activeFlow:
            flowRecommendations.append(FlowRecommendation(
                type: .flowState,
                title: "In the Zone",
                description: "Great focus! Avoid context switching and ride this productive wave.",
                priority: .high,
                actionable: false,
                estimatedImpact: 0.9
            ))
            
        case .deepFlow:
            flowRecommendations.append(FlowRecommendation(
                type: .flowState,
                title: "Deep Flow State",
                description: "You're in peak flow! Minimize all interruptions and continue this focused work.",
                priority: .critical,
                actionable: false,
                estimatedImpact: 1.0
            ))
            
        case .distracted:
            flowRecommendations.append(FlowRecommendation(
                type: .flowState,
                title: "Refocus Needed",
                description: "Multiple distractions detected. Try a 5-minute mindfulness break to reset.",
                priority: .high,
                actionable: true,
                estimatedImpact: 0.7
            ))
        }
    }
    
    private func generateToolOptimizationRecommendations() {
        // Analyze tool switching patterns and suggest optimizations
        let recentSwitches = contextSwitchEvents.suffix(5)
        if recentSwitches.count >= 3 {
            flowRecommendations.append(FlowRecommendation(
                type: .toolOptimization,
                title: "Frequent Tool Switching",
                description: "Consider batching similar tasks to reduce context switching overhead.",
                priority: .medium,
                actionable: true,
                estimatedImpact: 0.6
            ))
        }
    }
    
    private func generateEnvironmentRecommendations() {
        // Suggest optimal environment based on current task and patterns
        if let bestEnv = findOptimalEnvironment() {
            flowRecommendations.append(FlowRecommendation(
                type: .environment,
                title: "Environment Optimization",
                description: "Based on your patterns, \(bestEnv.displayName) might be optimal for your current work.",
                priority: .low,
                actionable: true,
                estimatedImpact: 0.5
            ))
        }
    }
    
    // MARK: - Helper Methods
    
    private func analyzeCreativeAppUsage(_ apps: [CreativeAppSession]) {
        let switchEvent = ContextSwitchEvent(
            timestamp: Date(),
            fromApp: contextSwitchEvents.last?.toApp,
            toApp: apps.first?.appName,
            duration: 0
        )
        
        contextSwitchEvents.append(switchEvent)
    }
    
    private func updateCreativityScore(from metrics: FocusMetrics) {
        // Calculate creativity score based on focus metrics and flow state
        var score = metrics.focusScore
        
        // Boost score based on flow state
        switch currentFlow {
        case .deepFlow:
            score *= 1.2
        case .activeFlow:
            score *= 1.1
        case .lightWork:
            score *= 1.0
        case .distracted:
            score *= 0.8
        case .idle:
            score *= 0.6
        }
        
        // Apply time-based multiplier
        let currentHour = Calendar.current.component(.hour, from: Date())
        if optimalWorkingHours.contains(currentHour) {
            score *= 1.1
        }
        
        creativityScore = min(100, score)
    }
    
    private func analyzeProductivityPatterns(from snapshots: [BehaviorSnapshot]) {
        // Analyze patterns to identify productivity trends
        userPatterns.averageFocusScore = snapshots.map { $0.focusScore }.reduce(0, +) / Double(snapshots.count)
        userPatterns.peakProductivityHours = identifyPeakHours(from: snapshots)
        userPatterns.optimalSessionLength = calculateOptimalSessionLength(from: snapshots)
    }
    
    private func identifyPeakHours(from snapshots: [BehaviorSnapshot]) -> [Int] {
        var hourlyScores: [Int: [Double]] = [:]
        
        for snapshot in snapshots {
            if hourlyScores[snapshot.hour] == nil {
                hourlyScores[snapshot.hour] = []
            }
            hourlyScores[snapshot.hour]?.append(snapshot.focusScore)
        }
        
        return hourlyScores.compactMap { (hour, scores) in
            let avgScore = scores.reduce(0, +) / Double(scores.count)
            return avgScore >= 75 ? hour : nil
        }.sorted()
    }
    
    private func calculateOptimalSessionLength(from snapshots: [BehaviorSnapshot]) -> TimeInterval {
        // Analyze session lengths and find optimal duration
        // For now, return a default value
        return 90 * 60 // 90 minutes
    }
    
    private func analyzeContextSwitching(from snapshots: [BehaviorSnapshot]) {
        // Analyze how context switching affects productivity
        var switchCount = 0
        for i in 1..<snapshots.count {
            let prevApps = Set(snapshots[i-1].activeApps)
            let currentApps = Set(snapshots[i].activeApps)
            if prevApps != currentApps {
                switchCount += 1
            }
        }
        
        userPatterns.averageContextSwitches = Double(switchCount) / Double(max(1, snapshots.count - 1))
    }
    
    private func updateOptimalWorkingHours() {
        // This is already implemented in updateHourlyPatterns()
    }
    
    private func generateInitialRecommendations() {
        flowRecommendations = [
            FlowRecommendation(
                type: .general,
                title: "Welcome to Creative Intelligence",
                description: "TOME is learning your work patterns to provide personalized productivity insights.",
                priority: .low,
                actionable: false,
                estimatedImpact: 0.0
            )
        ]
    }
    
    private func generateFlowTransitionSuggestions(for event: FlowChangeEvent) {
        // Generate contextual suggestions based on flow transitions
        contextualSuggestions.removeAll { $0.type == .flowTransition }
        
        switch (event.fromFlow, event.toFlow) {
        case (.idle, .lightWork):
            contextualSuggestions.append(ContextualSuggestion(
                type: .flowTransition,
                message: "Great! You're starting to focus. Try to eliminate potential distractions.",
                action: "Enable Focus Mode",
                relevanceScore: 0.8
            ))
            
        case (.lightWork, .activeFlow):
            contextualSuggestions.append(ContextualSuggestion(
                type: .flowTransition,
                message: "You're building momentum! This is a good time for challenging tasks.",
                action: "Tackle Complex Work",
                relevanceScore: 0.9
            ))
            
        case (.activeFlow, .distracted):
            contextualSuggestions.append(ContextualSuggestion(
                type: .flowTransition,
                message: "Focus interrupted. Consider a brief reset before continuing.",
                action: "Take 2-Minute Break",
                relevanceScore: 0.7
            ))
            
        default:
            break
        }
    }
    
    private func findOptimalEnvironment() -> TOMEEnvironment? {
        // Find the environment with highest success rate for current context
        let sortedPrefs = environmentPreferences.sorted { $0.value.averageFocusScore > $1.value.averageFocusScore }
        return sortedPrefs.first?.key
    }
    
    private func createAnalysisContext(from snapshots: [BehaviorSnapshot]) -> String {
        let avgFocus = snapshots.map { $0.focusScore }.reduce(0, +) / Double(snapshots.count)
        let appUsage = snapshots.flatMap { $0.activeApps }.reduce(into: [String: Int]()) { counts, app in
            counts[app, default: 0] += 1
        }
        let topApps = Array(appUsage.sorted { $0.value > $1.value }.prefix(3))
        
        return """
        Recent Work Session Analysis:
        - Average Focus Score: \(Int(avgFocus))%
        - Session Duration: \(snapshots.count) minutes
        - Most Used Apps: \(topApps.map { $0.key }.joined(separator: ", "))
        - Current Flow State: \(currentFlow.displayName)
        - Peak Hours: \(optimalWorkingHours.map { "\($0):00" }.joined(separator: ", "))
        """
    }
    
    private func parseAndStoreInsights(_ insights: String) {
        let insightLines = insights.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        adaptiveInsights.removeAll { $0.type == .productivity }
        
        for line in insightLines.prefix(3) {
            adaptiveInsights.append(AdaptiveInsight(
                type: .productivity,
                title: "AI Insight",
                description: line.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: 0.8,
                timeGenerated: Date()
            ))
        }
    }
    
    private func parseFlowOptimizationSuggestions(_ suggestions: String) {
        let suggestionLines = suggestions.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        for suggestion in suggestionLines.prefix(2) {
            contextualSuggestions.append(ContextualSuggestion(
                type: .flowOptimization,
                message: suggestion.trimmingCharacters(in: .whitespacesAndNewlines),
                action: "Learn More",
                relevanceScore: 0.9
            ))
        }
    }
    
    private func parsePersonalizedRecommendations(_ recommendations: String) {
        let recLines = recommendations.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        for rec in recLines.prefix(3) {
            flowRecommendations.append(FlowRecommendation(
                type: .personalized,
                title: "Personalized Suggestion",
                description: rec.trimmingCharacters(in: .whitespacesAndNewlines),
                priority: .medium,
                actionable: true,
                estimatedImpact: 0.7
            ))
        }
    }
    
    private func cleanupOldData() {
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days ago
        behaviorHistory = behaviorHistory.filter { $0.timestamp > cutoffDate }
        contextSwitchEvents = contextSwitchEvents.filter { $0.timestamp > cutoffDate }
    }
    
    // MARK: - Persistence
    
    private func loadUserPatterns() {
        // Load saved patterns from UserDefaults
        // Implementation would deserialize saved data
    }
    
    private func saveUserPatterns() {
        // Save patterns to UserDefaults
        // Implementation would serialize current patterns
    }
}

// MARK: - Supporting Types

enum CreativeFlow {
    case idle, lightWork, activeFlow, deepFlow, distracted
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .lightWork: return "Light Work"
        case .activeFlow: return "Active Flow"
        case .deepFlow: return "Deep Flow"
        case .distracted: return "Distracted"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .lightWork: return .blue
        case .activeFlow: return .green
        case .deepFlow: return .purple
        case .distracted: return .red
        }
    }
}

struct FlowRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let actionable: Bool
    let estimatedImpact: Double
    
    enum RecommendationType {
        case timing, flowState, toolOptimization, environment, general, personalized
    }
    
    enum Priority {
        case low, medium, high, critical
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

struct AdaptiveInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let timeGenerated: Date
    
    enum InsightType {
        case productivity, pattern, optimization, warning
    }
}

struct ContextualSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let message: String
    let action: String
    let relevanceScore: Double
    
    enum SuggestionType {
        case flowTransition, timeOptimization, toolSuggestion, breakReminder, flowOptimization
    }
}

struct UserCreativePatterns {
    var averageFocusScore: Double = 0
    var peakProductivityHours: [Int] = []
    var optimalSessionLength: TimeInterval = 0
    var averageContextSwitches: Double = 0
    var preferredTools: [String] = []
    var flowTransitionPatterns: [String: Double] = [:]
}

struct EnvironmentPreference {
    let usageCount: Int
    let averageFocusScore: Double
    let preferredTimeRange: ClosedRange<Int>
    let commonTasks: [String]
}

struct ToolUsagePattern {
    let toolName: String
    var usageCount: Int
    var totalDuration: TimeInterval
    var averageFocusScore: Double
    var bestHours: [Int]
    var commonPairings: [String]
}

struct BehaviorSnapshot {
    let timestamp: Date
    let hour: Int
    let activeApps: [String]
    let screenActivity: ActivityLevel
    let currentFlow: CreativeFlow
    let focusScore: Double
}

struct FlowSession: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let flowType: CreativeFlow
    let averageFocus: Double
    let appsUsed: [String]
}

struct FlowChangeEvent {
    let timestamp: Date
    let fromFlow: CreativeFlow
    let toFlow: CreativeFlow
    let duration: TimeInterval
}

struct ContextSwitchEvent {
    let timestamp: Date
    let fromApp: String?
    let toApp: String?
    let duration: TimeInterval
}