import SwiftUI
import WebKit

struct TOMEBrowserView: View {
    @State private var tabs: [BrowserTab] = []
    @State private var activeTabIndex = 0
    @State private var urlInput = ""
    @State private var isLoading = false
    @State private var showAISidebar = true
    @StateObject private var aiAgent = BrowserAIAgent()
    @StateObject private var webViewManager = WebViewManager()
    
    private let maxTabs = 3
    
    var body: some View {
        // Add padding around the entire browser for integration feel
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Main browser area
                VStack(spacing: 0) {
                    // Browser header with tabs and controls
                    browserHeader
                    
                    // Active tab content - MODERN WEBKIT BROWSER
                    if tabs.indices.contains(activeTabIndex) {
                        ModernWebView(
                            url: tabs[activeTabIndex].url,
                            isLoading: $isLoading,
                            onURLChange: { newURL in
                                if tabs.indices.contains(activeTabIndex) {
                                    tabs[activeTabIndex].url = newURL
                                    tabs[activeTabIndex].title = extractDomainFromURL(newURL)
                                    aiAgent.updateCurrentPage(url: newURL, title: tabs[activeTabIndex].title)
                                    aiAgent.generateContextualRecommendations() // Refresh on URL change
                                }
                            },
                            onTitleChange: { newTitle in
                                if tabs.indices.contains(activeTabIndex) {
                                    tabs[activeTabIndex].title = newTitle
                                    aiAgent.updateCurrentPage(url: tabs[activeTabIndex].url, title: newTitle)
                                }
                            },
                            onContentLoad: { content in
                                if tabs.indices.contains(activeTabIndex) {
                                    aiAgent.updatePageContent(content)
                                }
                            },
                            webViewManager: webViewManager
                        )
                    } else {
                        // Empty state
                        browserEmptyState
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // AI Sidebar
                if showAISidebar {
                    aiSidebar
                        .frame(width: 280)
                        .transition(.move(edge: .trailing))
                }
            }
            .padding(.top, 50) // Add extra top spacing to avoid overlap with navigation
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.3)) // Subtle background to show integration
        .onAppear {
            if tabs.isEmpty {
                createNewTab(url: "https://google.com")
            }
        }
    }
    
    private var browserHeader: some View {
        VStack(spacing: 8) {
            // Tab bar
            HStack(spacing: 4) {
                ForEach(tabs.indices, id: \.self) { index in
                    tabButton(for: index)
                }
                
                // New tab button (only if under max tabs)
                if tabs.count < maxTabs {
                    newTabButton
                }
                
                Spacer()
            }
            
            // URL bar and controls
            HStack(spacing: 8) {
                // Back/Forward buttons
                HStack(spacing: 4) {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.tomeCaptionMedium())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .disabled(!canGoBack())
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: goForward) {
                        Image(systemName: "chevron.right")
                            .font(.tomeCaptionMedium())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .disabled(!canGoForward())
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: refresh) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                            .font(.tomeCaptionMedium())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // URL input field
                TextField("Enter URL or search...", text: $urlInput)
                    .font(.tomeCaption())
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .onSubmit {
                        navigateToURL()
                    }
                    .onChange(of: activeTabIndex) {
                        updateURLInput()
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func tabButton(for index: Int) -> some View {
        Button(action: { switchToTab(index) }) {
            HStack(spacing: 6) {
                Text(tabs[index].title)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(activeTabIndex == index ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                
                // Close button
                Button(action: { closeTab(index) }) {
                    Image(systemName: "xmark")
                        .font(.tomeTinyMedium())
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(activeTabIndex == index ? Color.white.opacity(0.1) : Color.clear)
                    .stroke(activeTabIndex == index ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var newTabButton: some View {
        Button(action: { createNewTab(url: "https://google.com") }) {
            Image(systemName: "plus")
                .font(.tomeSmallLabelMedium())
                .foregroundColor(.white.opacity(0.6))
                .padding(4)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var browserEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.custom("Helvetica Neue", size: 48).weight(.medium))
                .foregroundColor(.white.opacity(0.5))
            
            Text("TOME Browser")
                .font(.tomeSubheading())
                .foregroundColor(.white)
            
            Text("WebKit-powered browsing with Chrome compatibility")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - AI Sidebar
    
    private var aiSidebar: some View {
        VStack(spacing: 16) {
            // Sidebar header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.blue)
                
                Text("Focus AI")
                    .font(.tomeSmallMedium())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showAISidebar.toggle() }) {
                    Image(systemName: "sidebar.right")
                        .font(.tomeCaptionMedium())
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Focus level indicator
                    focusLevelIndicator
                    
                    // Current page analysis
                    currentPageAnalysis
                    
                    // Quick launch recommendations
                    quickLaunchRecommendations
                    
                    // AI chat interface
                    aiChatInterface
                }
                .padding(.horizontal, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.leading, 12)
    }
    
    private var focusLevelIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus Level")
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.8))
            
            HStack {
                Circle()
                    .fill(aiAgent.focusLevel.color)
                    .frame(width: 8, height: 8)
                
                Text(aiAgent.focusLevel.description)
                    .font(.tomeLabel())
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(Int(aiAgent.focusScore))%")
                    .font(.tomeLabelMedium())
                    .foregroundColor(aiAgent.focusLevel.color)
            }
            
            ProgressView(value: aiAgent.focusScore / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: aiAgent.focusLevel.color))
                .scaleEffect(y: 0.5)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var currentPageAnalysis: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Page")
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.8))
            
            if let currentPage = aiAgent.currentPage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentPage.title)
                        .font(.tomeSmallLabelMedium())
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(currentPage.domain)
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.6))
                    
                    if !currentPage.analysis.isEmpty {
                        Text(currentPage.analysis)
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(3)
                    }
                }
            } else {
                Text("No page loaded")
                    .font(.tomeSmallLabel())
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var quickLaunchRecommendations: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended")
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.8))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(aiAgent.recommendations, id: \.title) { rec in
                    Button(action: { navigateToRecommendation(rec) }) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.1))
                                .frame(width: 16, height: 16)
                            
                            Text(rec.title)
                                .font(.tomeTinyMedium())
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.05))
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var aiChatInterface: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask AI about this page")
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.8))
            
            // Quick action buttons
            VStack(spacing: 6) {
                Button("Summarize this page") {
                    aiAgent.summarizePage()
                }
                .font(.tomeSmallLabel())
                .foregroundColor(aiAgent.isProcessingAI ? .gray : .blue.opacity(0.8))
                .disabled(aiAgent.isProcessingAI)
                .buttonStyle(PlainButtonStyle())
                
                Button("How does this relate to my todos?") {
                    aiAgent.relateTodos()
                }
                .font(.tomeSmallLabel())
                .foregroundColor(aiAgent.isProcessingAI ? .gray : .blue.opacity(0.8))
                .disabled(aiAgent.isProcessingAI)
                .buttonStyle(PlainButtonStyle())
                
                Button("Find related content") {
                    aiAgent.findRelated()
                }
                .font(.tomeSmallLabel())
                .foregroundColor(aiAgent.isProcessingAI ? .gray : .blue.opacity(0.8))
                .disabled(aiAgent.isProcessingAI)
                .buttonStyle(PlainButtonStyle())
            }
            
            // AI Response area
            if !aiAgent.aiResponse.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.tomeSmallLabelMedium())
                            .foregroundColor(.blue)
                        
                        Text("AI Response")
                            .font(.tomeSmallLabelMedium())
                            .foregroundColor(.white.opacity(0.8))
                        
                        if aiAgent.isProcessingAI {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        }
                    }
                    
                    ScrollView {
                        Text(aiAgent.aiResponse)
                            .font(.tomeTiny())
                            .foregroundColor(.white.opacity(0.7))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.blue.opacity(0.05))
                        .stroke(.blue.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func navigateToRecommendation(_ recommendation: SiteRecommendation) {
        if tabs.indices.contains(activeTabIndex) {
            tabs[activeTabIndex].url = recommendation.url
            urlInput = recommendation.url
        }
    }
    
    // MARK: - Tab Management
    
    private func createNewTab(url: String) {
        guard tabs.count < maxTabs else { return }
        
        let newTab = BrowserTab(
            id: UUID(),
            url: url,
            title: extractDomainFromURL(url)
        )
        
        tabs.append(newTab)
        activeTabIndex = tabs.count - 1
        urlInput = url
    }
    
    private func switchToTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabIndex = index
        updateURLInput()
        
        // Refresh AI recommendations when switching tabs
        if tabs.indices.contains(index) {
            aiAgent.updateCurrentPage(url: tabs[index].url, title: tabs[index].title)
            aiAgent.generateContextualRecommendations()
        }
    }
    
    private func closeTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        
        tabs.remove(at: index)
        
        if tabs.isEmpty {
            // Create a new tab if all tabs are closed
            createNewTab(url: "https://google.com")
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
            updateURLInput()
        } else if activeTabIndex > index {
            activeTabIndex -= 1
        }
    }
    
    private func updateURLInput() {
        if tabs.indices.contains(activeTabIndex) {
            urlInput = tabs[activeTabIndex].url
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToURL() {
        guard !urlInput.isEmpty, tabs.indices.contains(activeTabIndex) else { return }
        
        let processedURL = processURL(urlInput)
        tabs[activeTabIndex].url = processedURL
    }
    
    private func goBack() {
        webViewManager.goBack()
    }
    
    private func goForward() {
        webViewManager.goForward()
    }
    
    private func refresh() {
        webViewManager.reload()
    }
    
    private func canGoBack() -> Bool {
        return webViewManager.canGoBack()
    }
    
    private func canGoForward() -> Bool {
        return webViewManager.canGoForward()
    }
    
    // MARK: - Utility Functions
    
    private func processURL(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            return "https://" + trimmed
        } else {
            // Treat as search query
            return "https://www.google.com/search?q=" + trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        }
    }
    
}

// MARK: - Browser Tab Model

struct BrowserTab: Identifiable {
    let id: UUID
    var url: String
    var title: String
}


// MARK: - Browser AI Agent

class BrowserAIAgent: ObservableObject {
    @Published var focusLevel: FocusLevel = .medium
    @Published var focusScore: Double = 75.0
    @Published var currentPage: PageInfo?
    @Published var recommendations: [SiteRecommendation] = []
    @Published var aiResponse: String = ""
    @Published var isProcessingAI: Bool = false
    
    private var pageHistory: [PageInfo] = []
    private var sessionStartTime = Date()
    private let openAIService = OpenAIService()
    private var lastRecommendationUpdate = Date.distantPast
    private var currentPageContent: String = ""
    
    init() {
        generateInitialRecommendations()
    }
    
    func updateCurrentPage(url: String, title: String) {
        let domain = extractDomainFromURL(url)
        let analysis = analyzePageForFocus(url: url, title: title, domain: domain)
        
        currentPage = PageInfo(
            url: url,
            title: title,
            domain: domain,
            analysis: analysis,
            timeSpent: 0,
            visitTime: Date()
        )
        
        // Add to history
        if let page = currentPage {
            pageHistory.append(page)
        }
        
        // Update focus level based on content
        updateFocusLevel(for: domain, title: title)
    }
    
    func updatePageContent(_ content: String) {
        currentPageContent = content
        // Update focus analysis with actual content
        if let currentPage = currentPage {
            updateFocusLevel(for: currentPage.domain, title: currentPage.title, content: content)
        }
    }
    
    private func analyzePageForFocus(url: String, title: String, domain: String) -> String {
        // Analyze if the page is productive or distracting
        let distractingDomains = ["youtube.com", "netflix.com", "tiktok.com", "instagram.com", "facebook.com", "twitter.com"]
        let productiveDomains = ["github.com", "stackoverflow.com", "medium.com", "documentation", "docs.", "wiki"]
        
        if distractingDomains.contains(where: domain.contains) {
            return "Potentially distracting content. Consider time limits."
        } else if productiveDomains.contains(where: domain.contains) {
            return "Productive content detected. Good for focus."
        } else if title.lowercased().contains("news") {
            return "News content. Moderate for focused work."
        } else {
            return "General web content."
        }
    }
    
    private func updateFocusLevel(for domain: String, title: String, content: String = "") {
        // Enhanced focus scoring algorithm with content analysis
        var score = 50.0
        
        // Boost score for productive sites
        if domain.contains("github.com") || domain.contains("stackoverflow.com") {
            score += 30
        } else if domain.contains("documentation") || domain.contains("docs.") {
            score += 25
        } else if domain.contains("learning") || domain.contains("education") {
            score += 20
        }
        
        // Reduce score for distracting sites
        if domain.contains("youtube.com") || domain.contains("netflix.com") {
            score -= 25
        } else if domain.contains("social") || domain.contains("facebook") || domain.contains("instagram") {
            score -= 30
        }
        
        // Content-based analysis
        if !content.isEmpty {
            let lowercaseContent = content.lowercased()
            
            // Look for productive keywords in content
            let productiveKeywords = ["documentation", "tutorial", "guide", "learn", "develop", "code", "programming", "technical", "api", "framework"]
            let productiveCount = productiveKeywords.reduce(0) { count, keyword in
                count + (lowercaseContent.contains(keyword) ? 1 : 0)
            }
            score += Double(productiveCount) * 3
            
            // Look for distracting keywords
            let distractingKeywords = ["entertainment", "celebrity", "gossip", "funny", "viral", "trending", "watch", "subscribe"]
            let distractingCount = distractingKeywords.reduce(0) { count, keyword in
                count + (lowercaseContent.contains(keyword) ? 1 : 0)
            }
            score -= Double(distractingCount) * 4
        }
        
        // Time-based adjustments
        let sessionLength = Date().timeIntervalSince(sessionStartTime) / 3600 // hours
        if sessionLength > 2 {
            score -= min(15, sessionLength * 5) // Reduce focus over time
        }
        
        focusScore = max(0, min(100, score))
        
        // Update focus level
        if focusScore >= 80 {
            focusLevel = .high
        } else if focusScore >= 50 {
            focusLevel = .medium
        } else {
            focusLevel = .low
        }
    }
    
    private func generateInitialRecommendations() {
        recommendations = [
            SiteRecommendation(title: "GitHub", url: "https://github.com"),
            SiteRecommendation(title: "Stack Overflow", url: "https://stackoverflow.com"),
            SiteRecommendation(title: "Documentation", url: "https://developer.mozilla.org"),
            SiteRecommendation(title: "Learning", url: "https://coursera.org")
        ]
    }
    
    
    func summarizePage() {
        guard let currentPage = currentPage else {
            aiResponse = "No page is currently loaded"
            return
        }
        
        isProcessingAI = true
        aiResponse = "Analyzing page content..."
        
        let contentPreview = String(currentPageContent.prefix(2000)) // First 2000 chars
        
        let messages = [
            ChatMessage(role: "system", content: """
                You are a helpful AI assistant that summarizes web page content for focused reading.
                Provide a concise, actionable summary highlighting key points and insights.
                Keep the summary under 200 words and focus on main takeaways.
                """),
            ChatMessage(role: "user", content: """
                Please summarize this webpage:
                Title: \(currentPage.title)
                URL: \(currentPage.url)
                Domain: \(currentPage.domain)
                Content: \(contentPreview)
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessingAI = false
                switch result {
                case .success(let summary):
                    self?.aiResponse = summary
                case .failure(let error):
                    self?.aiResponse = "Failed to generate summary: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func relateTodos() {
        guard let currentPage = currentPage else {
            aiResponse = "No page is currently loaded"
            return
        }
        
        isProcessingAI = true
        aiResponse = "Analyzing relationship to your todos..."
        
        let contentPreview = String(currentPageContent.prefix(1500))
        
        let messages = [
            ChatMessage(role: "system", content: """
                You are a productivity AI that helps connect web content to user's todo items.
                Analyze the current webpage and suggest how it relates to typical professional tasks.
                Provide actionable insights about how this content could help with work or learning goals.
                """),
            ChatMessage(role: "user", content: """
                How might this webpage content relate to my work and todo items?
                Title: \(currentPage.title)
                URL: \(currentPage.url)
                Domain: \(currentPage.domain)
                Content: \(contentPreview)
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessingAI = false
                switch result {
                case .success(let analysis):
                    self?.aiResponse = analysis
                case .failure(let error):
                    self?.aiResponse = "Failed to analyze todos relationship: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func findRelated() {
        guard let currentPage = currentPage else {
            aiResponse = "No page is currently loaded"
            return
        }
        
        isProcessingAI = true
        aiResponse = "Finding related content recommendations..."
        
        let contentPreview = String(currentPageContent.prefix(1500))
        
        let messages = [
            ChatMessage(role: "system", content: """
                You are a research assistant that suggests related content based on the current webpage.
                Suggest 3-5 specific search queries or topics that would provide complementary information.
                Focus on actionable, specific suggestions rather than generic topics.
                """),
            ChatMessage(role: "user", content: """
                Based on this webpage, what related content should I explore next?
                Title: \(currentPage.title)
                URL: \(currentPage.url)
                Domain: \(currentPage.domain)
                Content: \(contentPreview)
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessingAI = false
                switch result {
                case .success(let suggestions):
                    self?.aiResponse = suggestions
                case .failure(let error):
                    self?.aiResponse = "Failed to find related content: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func generateContextualRecommendations() {
        guard let currentPage = currentPage else { return }
        
        let contentPreview = String(currentPageContent.prefix(1000))
        
        let messages = [
            ChatMessage(role: "system", content: """
                You are a focus and productivity AI. Based on the current webpage content, suggest 4 relevant websites
                that would be productive and helpful for someone working in this domain.
                
                Return ONLY a JSON array of objects with this format:
                [{"title": "Site Name", "url": "https://example.com"}]
                
                Focus on productivity tools, documentation, learning resources, or directly related professional sites.
                """),
            ChatMessage(role: "user", content: """
                Current page: \(currentPage.title) at \(currentPage.domain)
                Content: \(contentPreview)
                """)
        ]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { [weak self] result in
            switch result {
            case .success(let response):
                if let data = response.data(using: .utf8),
                   let recs = try? JSONDecoder().decode([SiteRecommendationData].self, from: data) {
                    DispatchQueue.main.async {
                        self?.recommendations = recs.map { 
                            SiteRecommendation(title: $0.title, url: $0.url) 
                        }
                    }
                }
            case .failure:
                // Keep existing recommendations on error
                break
            }
        }
    }
}

// MARK: - Supporting Data Structures

struct PageInfo {
    let url: String
    let title: String
    let domain: String
    let analysis: String
    var timeSpent: TimeInterval
    let visitTime: Date
}

struct SiteRecommendation {
    let title: String
    let url: String
}

struct SiteRecommendationData: Codable {
    let title: String
    let url: String
}

enum FocusLevel {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
    
    var description: String {
        switch self {
        case .high: return "Highly Focused"
        case .medium: return "Moderately Focused"
        case .low: return "Low Focus"
        }
    }
}

// Helper function to extract domain
private func extractDomainFromURL(_ url: String) -> String {
    guard let urlObj = URL(string: url),
          let host = urlObj.host else {
        return "New Tab"
    }
    
    // Remove 'www.' prefix if present
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
}

// MARK: - WebView Manager

class WebViewManager: ObservableObject {
    private var currentWebView: WKWebView?
    
    func setWebView(_ webView: WKWebView) {
        currentWebView = webView
    }
    
    func goBack() {
        currentWebView?.goBack()
    }
    
    func goForward() {
        currentWebView?.goForward()
    }
    
    func reload() {
        currentWebView?.reload()
    }
    
    func canGoBack() -> Bool {
        return currentWebView?.canGoBack ?? false
    }
    
    func canGoForward() -> Bool {
        return currentWebView?.canGoForward ?? false
    }
}