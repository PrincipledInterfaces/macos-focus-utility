import SwiftUI

struct CoffeeshopView: View {
    @ObservedObject var currentState: TOMEState
    @State private var researchQuery = ""
    @State private var currentArticles: [Article] = []
    @State private var breadcrumbs: [String] = []
    @State private var showSerendipityMode = true
    @State private var rabbitHoleTimer: TimeInterval = 0
    @State private var notes = ""
    @State private var savedReferences: [Reference] = []
    @State private var selectedArticle: Article?
    @State private var showArticleReader = false
    @State private var aiGeneratedSuggestions: [String] = []
    @State private var isGeneratingSerendipity = false
    @State private var allowExternalBrowserLaunch = false
    
    let onNavigateHome: () -> Void
    
    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
    }
    
    var body: some View {
        GeometryReader { geometry in
            if showArticleReader, let selectedArticle = selectedArticle {
                // Full-screen article reader
                articleReaderView(selectedArticle)
            } else {
                HStack(spacing: 0) {
                    // Left - Browser in research mode (60%)
                    researchBrowserPanel
                        .frame(width: geometry.size.width * 0.6)
                    
                    // Vertical divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                    
                    // Right - Notes and references (40%)
                    notesAndReferencesPanel
                        .frame(width: geometry.size.width * 0.4)
                }
            }
        }
        .background(coffeeshopBackground)
        .overlay(
            // Only show navigation overlay when NOT in article reader mode
            Group {
                if !showArticleReader {
                    TOMENavigationOverlay(
                        onNavigateHome: onNavigateHome,
                        environmentName: "Coffeeshop",
                        environmentColor: .orange
                    )
                }
            }
        )
        .overlay(
            // Ambient controls (top-right only, no overlapping exit button)
            VStack {
                HStack {
                    Spacer()
                    
                    ambientControls
                }
                .padding(.horizontal, 20)
                .padding(.top, 60) // Give space for navigation overlay
                
                Spacer()
                
                // Coffee break reminder
                if rabbitHoleTimer > 45 * 60 { // 45 minutes
                    coffeeBreakReminder
                        .padding(.bottom, 20)
                }
            }
        )
        .onAppear {
            startRabbitHoleTimer()
            loadInitialArticles()
            loadSavedReferences()
            generateAISerendipitySuggestions()
        }
    }
    
    private var coffeeshopBackground: some View {
        ZStack {
            // Warm, cozy gradient
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.08),
                    Color.brown.opacity(0.05),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle steam effects
            ForEach(0..<5, id: \.self) { index in
                steamEffect(at: index)
            }
        }
        .ignoresSafeArea(.all)
    }
    
    private func steamEffect(at index: Int) -> some View {
        Circle()
            .fill(Color.white.opacity(0.01))
            .frame(width: CGFloat(20 + index * 10))
            .offset(
                x: CGFloat.random(in: -200...200),
                y: CGFloat.random(in: -100...100)
            )
            .animation(
                .easeInOut(duration: Double.random(in: 10...20))
                .repeatForever(autoreverses: true),
                value: index
            )
    }
    
    
    private var ambientControls: some View {
        HStack(spacing: 12) {
            // Serendipity mode toggle
            Button(action: { showSerendipityMode.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: showSerendipityMode ? "sparkles" : "sparkles.rectangle.stack")
                        .font(.system(size: 12, weight: .medium))
                    
                    Text("Serendipity")
                        .font(.tomeCaptionMedium())
                }
                .foregroundColor(.white.opacity(showSerendipityMode ? 0.8 : 0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(showSerendipityMode ? 0.2 : 0.1))
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Ambient sound indicator
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 12, weight: .medium))
                
                Text("Coffeeshop")
                    .font(.tomeCaptionMedium())
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var researchBrowserPanel: some View {
        VStack(spacing: 0) {
            // Browser header
            browserHeader
            
            // Content area
            ScrollView {
                LazyVStack(spacing: 16) {
                    // If no search query, show recommended articles section
                    if researchQuery.isEmpty {
                        recommendedArticlesSection
                    }
                    
                    // Search results / articles
                    ForEach(currentArticles) { article in
                        ArticleCard(
                            article: article,
                            onSelect: { selectArticle(article) },
                            onAddToNotes: { addToNotes(article) }
                        )
                    }
                    
                    // Serendipity suggestions
                    if showSerendipityMode {
                        serendipitySuggestions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }
    
    private var browserHeader: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("COFFEESHOP")
                    .font(.tomeHeading())
                    .foregroundColor(.white)
                
                Spacer()
                
                // Rabbit hole timer
                rabbitHoleIndicator
            }
            
            // Search bar
            HStack {
                TextField("Research query...", text: $researchQuery)
                    .font(.tomeBody())
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .onSubmit {
                        performResearch()
                    }
                
                Button(action: performResearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
                                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Breadcrumbs
            if !breadcrumbs.isEmpty {
                breadcrumbsView
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var rabbitHoleIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: rabbitHoleTimer > 30 * 60 ? "exclamationmark.triangle" : "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(rabbitHoleTimer > 30 * 60 ? .orange : .white.opacity(0.6))
            
            Text(formatTime(rabbitHoleTimer))
                .font(.tomeCaptionMedium())
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var breadcrumbsView: some View {
        HStack {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(breadcrumbs.indices, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(breadcrumbs[index])
                                .font(.tomeTiny())
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                            
                            if index < breadcrumbs.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.02))
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private var serendipitySuggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Serendipity Suggestions")
                    .font(.tomeSubheading())
                    .foregroundColor(.white.opacity(0.9))
            }
            
            HStack(spacing: 12) {
                ForEach(serendipityTopics, id: \.self) { topic in
                    serendipityTag(topic)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func serendipityTag(_ topic: String) -> some View {
        Button(action: {
            researchQuery = topic
            performResearch()
        }) {
            Text(topic)
                .font(.tomeCaptionMedium())
                .foregroundColor(.orange.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var recommendedArticlesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Featured Articles")
                    .font(.tomeSubheading())
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Text("Curated for deep learning")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Text("Explore these carefully selected articles designed to enhance your knowledge and understanding of key concepts.")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var notesAndReferencesPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("RESEARCH NOTES")
                    .font(.tomeSubheading())
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Mind-mapping & references")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            // Notes area
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                TextEditor(text: $notes)
                    .font(.tomeCaption())
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.03))
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .frame(height: 200)
                    .overlay(
                        Text("Capture insights, connections, and key findings...")
                            .font(.tomeCaption())
                            .foregroundColor(.white.opacity(0.3))
                            .padding(12)
                            .allowsHitTesting(false)
                            .opacity(notes.isEmpty ? 1 : 0),
                        alignment: .topLeading
                    )
            }
            .padding(.horizontal, 20)
            
            // Saved references
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved References")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(savedReferences) { reference in
                            ReferenceCard(reference: reference)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private var coffeeBreakReminder: some View {
        HStack(spacing: 12) {
            Text("☕")
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Coffee break time!")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white)
                
                Text("You've been researching for \(Int(rabbitHoleTimer / 60)) minutes")
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button("Dismiss") {
                rabbitHoleTimer = 0
            }
            .font(.tomeCaptionMedium())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.2))
                    .stroke(Color.orange.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private func performResearch() {
        guard !researchQuery.isEmpty else { return }
        
        breadcrumbs.append(researchQuery)
        
        // Perform real article search
        Task {
            await searchRealArticles(query: researchQuery)
        }
    }
    
    @MainActor
    private func searchRealArticles(query: String) async {
        do {
            // Try to get real articles from multiple sources
            let articles = try await RealArticleSearchService.searchArticles(query: query)
            currentArticles = articles
            print("🔍 Found \(articles.count) real articles for: \(query)")
        } catch {
            print("❌ Real search failed: \(error)")
            // Show empty state - no fake articles
            currentArticles = []
        }
    }
    
    
    private func selectArticle(_ article: Article) {
        breadcrumbs.append(article.title)
        
        // Fetch and display article content within the app
        fetchArticleContent(article)
    }
    
    private func fetchArticleContent(_ article: Article) {
        // Fetch the article content and display it in the app
        if article.content.isEmpty {
            // Simulate fetching real content from web
            Task {
                await loadArticleContent(for: article)
            }
        } else {
            // Already have content, show it
            showArticleReader(article)
        }
    }
    
    private func showArticleReader(_ article: Article) {
        // Display article within the app's interface
        selectedArticle = article
        showArticleReader = true
        
        // Update TOMEState so AI agent can see current article
        currentState.currentCoffeeshopArticle = CoffeeshopArticle(
            title: article.title,
            author: article.author,
            content: article.content,
            summary: article.summary,
            url: article.url,
            source: article.source
        )
    }
    
    @MainActor
    private func loadArticleContent(for article: Article) async {
        // Fetch actual content from the URL
        do {
            print("📡 Fetching content from: \(article.url)")
            let fetchedContent = try await WebContentFetcher.fetchArticleContent(from: article.url)

            if let index = currentArticles.firstIndex(where: { $0.id == article.id }) {
                currentArticles[index] = Article(
                    id: article.id,
                    title: article.title,
                    summary: article.summary,
                    url: article.url,
                    timestamp: article.timestamp,
                    content: fetchedContent,
                    author: article.author ?? "Web",
                    readingTime: estimateReadingTime(fetchedContent),
                    source: article.source
                )
                showArticleReader(currentArticles[index])
                print("✅ Loaded real content for: \(article.title) (\(fetchedContent.count) chars)")
            }
        } catch {
            print("❌ Failed to fetch content: \(error), using fallback")
            // Only use fallback if fetch fails
            let detailedContent = generateDetailedContent(for: article)

            if let index = currentArticles.firstIndex(where: { $0.id == article.id }) {
                currentArticles[index] = Article(
                    id: article.id,
                    title: article.title,
                    summary: article.summary,
                    url: article.url,
                    timestamp: article.timestamp,
                    content: detailedContent,
                    author: article.author ?? "Curated",
                    readingTime: estimateReadingTime(detailedContent),
                    source: article.source
                )
                showArticleReader(currentArticles[index])
            }
        }
    }
    
    private func generateSimulatedContent(for article: Article) -> String {
        // Generate realistic content based on the research query and title
        return """
        # \(article.title)
        
        ## Introduction
        
        This research explores the key concepts around \(researchQuery), providing insights into current approaches and methodologies.
        
        ## Key Findings
        
        Recent studies have shown that effective implementation of \(researchQuery.lowercased()) requires careful consideration of multiple factors:
        
        • **Strategic Planning**: Understanding the fundamental principles
        • **Implementation**: Practical approaches that work in real-world scenarios  
        • **Measurement**: Tracking progress and outcomes effectively
        
        ## Methodology
        
        The approach involves systematic analysis of current practices, identifying patterns and opportunities for improvement.
        
        ## Practical Applications
        
        These findings can be applied in various contexts, particularly when working with complex systems that require \(researchQuery.lowercased()).
        
        ## Conclusion
        
        The research demonstrates clear pathways for implementing effective \(researchQuery.lowercased()) strategies. Future work should focus on scaling these approaches across different domains.
        
        ## References
        
        - Academic research databases
        - Industry case studies
        - Expert interviews and analysis
        """
    }
    
    private func estimateReadingTime(_ content: String) -> Int {
        let wordCount = content.split(separator: " ").count
        return max(1, wordCount / 200) // 200 words per minute average
    }
    
    private func addToNotes(_ article: Article) {
        let newNote = "\n• \(article.title) - \(article.summary)"
        notes += newNote
        
        // Also save as a reference for future use
        let reference = Reference(
            id: UUID(),
            title: article.title,
            author: "Web Research",
            type: .website
        )
        savedReferences.append(reference)
        saveSavedReferences()
    }
    
    private func startRabbitHoleTimer() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.rabbitHoleTimer += 5
            }
        }
    }
    
    private func loadInitialArticles() {
        // Load real featured articles on startup using quality search
        Task {
            await loadFeaturedArticles()
        }
    }

    @MainActor
    private func loadFeaturedArticles() async {
        // Fetch real articles from quality sources on different topics
        let featuredTopics = [
            "deep work productivity",
            "neuroscience focus",
            "knowledge management",
            "systems thinking"
        ].randomElement() ?? "deep work productivity"

        do {
            let articles = try await RealArticleSearchService.searchArticles(query: featuredTopics)
            currentArticles = articles
            print("✨ Loaded \(articles.count) featured articles for: \(featuredTopics)")
        } catch {
            print("❌ Failed to load featured articles: \(error)")
            currentArticles = []
        }
    }
    
    static func extractSourceFromURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return "Web"
        }
        
        // Clean up common domain names
        let domain = host.lowercased()
        if domain.contains("calnewport.com") {
            return "Cal Newport"
        } else if domain.contains("researchgate.net") {
            return "ResearchGate"
        } else if domain.contains("roamresearch.com") {
            return "Roam Research"
        } else if domain.contains("wikipedia.org") {
            return "Wikipedia"
        } else if domain.contains("nngroup.com") {
            return "Nielsen Norman Group"
        } else if domain.contains("edutopia.org") {
            return "Edutopia"
        } else if domain.contains("google.com") {
            return "Google Scholar"
        } else if domain.contains("reddit.com") {
            return "Reddit"
        } else if domain.contains("news.ycombinator.com") {
            return "Hacker News"
        } else if domain.contains("medium.com") {
            return "Medium"
        } else {
            // Extract the main domain name
            let components = domain.split(separator: ".")
            if components.count >= 2 {
                return String(components[components.count - 2]).capitalized
            }
            return host.capitalized
        }
    }
    
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)m"
    }
    
    private var serendipityTopics: [String] {
        // Show AI-generated suggestions, but provide temporary fallback while AI loads
        if aiGeneratedSuggestions.isEmpty && isGeneratingSerendipity {
            return ["Loading..."]  // Show loading state
        }
        return aiGeneratedSuggestions.isEmpty ? [] : aiGeneratedSuggestions
    }
    
    private func loadSavedReferences() {
        if let data = UserDefaults.standard.data(forKey: "coffeeshop_saved_references"),
           let references = try? JSONDecoder().decode([Reference].self, from: data) {
            savedReferences = references
        } else {
            // Initialize with some useful default references
            savedReferences = [
                Reference(
                    id: UUID(),
                    title: "Flow: The Psychology of Optimal Experience",
                    author: "Mihaly Csikszentmihalyi",
                    type: .book
                ),
                Reference(
                    id: UUID(),
                    title: "Deep Work: Rules for Focused Success",
                    author: "Cal Newport",
                    type: .book
                )
            ]
            saveSavedReferences()
        }
    }
    
    private func saveSavedReferences() {
        if let data = try? JSONEncoder().encode(savedReferences) {
            UserDefaults.standard.set(data, forKey: "coffeeshop_saved_references")
        }
    }
    
    // MARK: - Article Reader View
    
    private func articleReaderView(_ article: Article) -> some View {
        VStack(spacing: 0) {
            // Article reader header
            articleReaderHeader(article)
            
            // Article content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Article metadata
                    articleMetadata(article)
                    
                    // Article content
                    articleContentView(article)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .frame(maxWidth: 800)
            }
            .background(Color.black.opacity(0.4))
        }
        .background(coffeeshopBackground)
    }
    
    private func articleReaderHeader(_ article: Article) -> some View {
        HStack {
            // Back to articles button
            Button(action: {
                showArticleReader = false
                selectedArticle = nil
                currentState.currentCoffeeshopArticle = nil
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back to Articles")
                        .font(.tomeBodyMedium())
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Reading progress and actions
            HStack(spacing: 12) {
                // Add to notes button
                Button(action: {
                    addToNotes(article)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Share/export button
                Button(action: {
                    // Future: implement sharing functionality
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.6))
    }
    
    private func articleMetadata(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Article title
            Text(article.title)
                .font(.tomeTitle())
                .foregroundColor(.white)
                .lineLimit(3)
            
            // Article metadata
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Source
                    Text(article.source)
                        .font(.tomeSmallLabelMedium())
                        .foregroundColor(.orange.opacity(0.8))
                    
                    // Author (if available)
                    if let author = article.author, author != "Curated" {
                        Text("By \(author)")
                            .font(.tomeCaptionMedium())
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("\(article.readingTime) min read")
                        .font(.tomeCaptionMedium())
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Article summary
            Text(article.summary)
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(3)
        }
    }
    
    private func articleContentView(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !article.content.isEmpty {
                // Display actual article content
                Text(article.content)
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            } else {
                // Generate content for the article
                Text(generateDetailedContent(for: article))
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }
            
            // External browser controls
            HStack(spacing: 12) {
                Button(action: {
                    allowExternalBrowserLaunch.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: allowExternalBrowserLaunch ? "checkmark.square" : "square")
                            .font(.system(size: 12, weight: .medium))
                        Text("Allow external browser")
                            .font(.tomeSmallLabel())
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                
                if allowExternalBrowserLaunch {
                    Button(action: {
                        if let url = URL(string: article.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                                .font(.system(size: 12, weight: .medium))
                            Text("Open in Safari")
                                .font(.tomeCaptionMedium())
                        }
                        .foregroundColor(.orange.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.1))
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func generateDetailedContent(for article: Article) -> String {
        switch article.title {
        case "Deep Work Strategies":
            return """
            # Deep Work: Mastering Focus in a Distracted World
            
            ## The Challenge of Modern Knowledge Work
            
            In today's hyperconnected workplace, the ability to focus without distraction has become increasingly rare—and increasingly valuable. Deep work, the ability to concentrate on cognitively demanding tasks, is what allows knowledge workers to produce their best work and advance their careers.
            
            ## Key Strategies for Deep Work
            
            ### 1. Ritualize Deep Work
            Create consistent rituals around when, where, and how you engage in deep work. This might involve:
            - Working in the same location at the same time each day
            - Starting each session with the same warm-up routine
            - Eliminating all potential distractions from your workspace
            
            ### 2. Embrace Boredom
            Constant stimulation rewires your brain to crave distraction. Practice being comfortable with boredom:
            - Don't check your phone while waiting in line
            - Take walks without podcasts or music
            - Sit quietly for a few minutes each day
            
            ### 3. Quit Social Media
            Or at least dramatically reduce its role in your life. Social media is designed to be addictive and fragments your attention.
            
            ### 4. Drain the Shallows
            Identify and minimize shallow work—tasks that are logistical in nature and don't create new value. This includes:
            - Excessive email checking
            - Unnecessary meetings
            - Administrative busywork
            
            ## The Deep Work Hypothesis
            
            "The ability to perform deep work is becoming increasingly rare at exactly the same time it is becoming increasingly valuable in our economy. As a consequence, the few who cultivate this skill, and then make it the core of their working life, will thrive."
            
            This hypothesis suggests that deep work isn't just beneficial—it's essential for anyone who wants to remain valuable in an increasingly automated world.
            
            ## Practical Implementation
            
            Start small: Begin with 30-60 minute blocks of uninterrupted work. Gradually increase the duration as your ability to concentrate improves. Remember, deep work is a skill that must be developed through deliberate practice.
            """
            
        case "Flow State Psychology":
            return """
            # Understanding Flow: The Psychology of Optimal Experience
            
            ## What is Flow?
            
            Flow is a mental state where a person becomes fully immersed in an activity with complete focus, clear goals, and a sense of effortless control. During flow, self-consciousness disappears, time perception alters, and the activity becomes intrinsically rewarding.
            
            ## The Neuroscience Behind Flow
            
            Research shows that during flow states, the brain exhibits several distinctive patterns:
            
            ### Transient Hypofrontality
            - The prefrontal cortex, responsible for self-criticism and distraction, downregulates
            - This creates the feeling of "getting out of your own way"
            - Inner critic becomes quiet, allowing for more creative and intuitive thinking
            
            ### Neurochemical Changes
            Flow triggers the release of performance-enhancing neurochemicals:
            - **Norepinephrine**: Heightens attention and arousal
            - **Dopamine**: Increases focus and pattern recognition
            - **Endorphins**: Create feelings of pleasure and block pain
            - **Anandamide**: Promotes lateral thinking and creative insights
            
            ## The Eight Characteristics of Flow
            
            1. **Complete concentration** on the task at hand
            2. **Clear goals** and immediate feedback
            3. **Balance between challenge and skill** level
            4. **Action and awareness merge**
            5. **Distractions fade away**
            6. **Self-consciousness disappears**
            7. **Time transforms** (speeds up or slows down)
            8. **Activity becomes autotelic** (intrinsically rewarding)
            
            ## Cultivating Flow in Daily Life
            
            ### Match Challenge to Skill Level
            - Too easy: boredom and apathy
            - Too difficult: anxiety and stress
            - Just right: engagement and flow
            
            ### Create Clear Goals
            - Break larger projects into specific, actionable tasks
            - Set micro-goals within longer activities
            - Ensure you can measure progress
            
            ### Minimize Distractions
            - Turn off notifications
            - Create a dedicated workspace
            - Use time-blocking techniques
            
            ### Develop Skills Deliberately
            - Focus on your weakest links
            - Seek immediate feedback
            - Practice at the edge of your abilities
            
            ## Flow in Different Domains
            
            Flow can be experienced in virtually any activity:
            - **Creative work**: Writing, programming, design
            - **Physical activities**: Sports, dancing, martial arts
            - **Social interaction**: Deep conversations, collaboration
            - **Learning**: Reading, studying, problem-solving
            
            The key is finding activities that naturally provide the right balance of challenge, clear goals, and immediate feedback for your current skill level.
            """
            
        default:
            return """
            # \(article.title)
            
            \(article.summary)
            
            ## Overview
            
            This article explores the fundamental concepts and practical applications related to \(article.title.lowercased()). Understanding these principles can significantly impact how we approach complex problems and make informed decisions.
            
            ## Key Insights
            
            Research in this area has revealed several important findings:
            
            • **Systematic Approach**: Breaking down complex topics into manageable components
            • **Evidence-Based Methods**: Relying on peer-reviewed research and empirical data  
            • **Practical Implementation**: Translating theoretical knowledge into actionable strategies
            • **Continuous Learning**: Adapting approaches based on new information and feedback
            
            ## Applications
            
            These concepts can be applied across various domains, from personal productivity to organizational effectiveness. The key is understanding the underlying principles and adapting them to your specific context and goals.
            
            ## Further Reading
            
            For deeper exploration of this topic, consider consulting academic journals, expert practitioners, and established thought leaders in the field. Cross-disciplinary perspectives often provide the most valuable insights.
            """
        }
    }
    
    private func generateAISerendipitySuggestions() {
        guard !isGeneratingSerendipity else { return }
        
        isGeneratingSerendipity = true
        
        // Get user's reading history context
        let recentTopics = savedReferences.prefix(5).map { $0.title }.joined(separator: ", ")
        let authorInterests = savedReferences.prefix(5).map { $0.author }.uniqued().joined(separator: ", ")
        
        let prompt = """
        Generate 4 fascinating, diverse research topics for serendipitous discovery. Consider these constraints:
        
        - Each topic should be 1-3 words maximum
        - Topics should be intellectually curious and thought-provoking
        - Mix different domains: technology, psychology, biology, economics, philosophy, etc.
        - Avoid topics that are too mainstream or obvious
        - Make them specific enough to yield interesting research
        
        User's recent interests: \(recentTopics.isEmpty ? "general knowledge exploration" : recentTopics)
        Authors they read: \(authorInterests.isEmpty ? "varied authors" : authorInterests)
        
        Return only the 4 topic names, separated by commas, no explanations.
        """
        
        let openAIService = OpenAIService()
        let messages = [ChatMessage(role: "user", content: prompt)]
        
        openAIService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { result in
            DispatchQueue.main.async {
                isGeneratingSerendipity = false
                
                switch result {
                case .success(let response):
                    let suggestions = response.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    if suggestions.count >= 3 {
                        aiGeneratedSuggestions = Array(suggestions.prefix(4))
                        print("✨ Generated serendipity suggestions: \(suggestions)")
                    } else {
                        print("⚠️ AI response didn't provide enough suggestions, keeping defaults")
                    }
                    
                case .failure(let error):
                    print("❌ Failed to generate serendipity suggestions: \(error)")
                }
            }
        }
    }
    
}

struct ArticleCard: View {
    let article: Article
    let onSelect: () -> Void
    let onAddToNotes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.tomeSubheading())
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(article.summary)
                        .font(.tomeCaption())
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)

                    // Source indicator
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                            .foregroundColor(.orange.opacity(0.7))
                        Text(article.source)
                            .font(.tomeTiny())
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .padding(.top, 4)
                }

                Spacer()

                VStack(spacing: 8) {
                    Button(action: onSelect) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: onAddToNotes) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct ReferenceCard: View {
    let reference: Reference
    
    var body: some View {
        HStack {
            Image(systemName: reference.type.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(reference.type.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reference.title)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                
                Text(reference.author)
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.02))
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct Article: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let url: String
    let timestamp: Date
    let content: String
    let author: String?
    let readingTime: Int
    let source: String
}

struct Reference: Identifiable, Codable {
    let id: UUID
    let title: String
    let author: String
    let type: ReferenceType
    
    enum ReferenceType: Codable {
        case book, paper, website, video
        
        var icon: String {
            switch self {
            case .book: return "book"
            case .paper: return "doc.text"
            case .website: return "globe"
            case .video: return "play.rectangle"
            }
        }
        
        var color: Color {
            switch self {
            case .book: return .blue
            case .paper: return .green
            case .website: return .orange
            case .video: return .red
            }
        }
    }
}



// MARK: - Real Services

class RealArticleSearchService {
    static func searchArticles(query: String) async throws -> [Article] {
        // Search multiple real APIs in parallel
        async let wikipediaResults = searchWikipedia(query: query)
        async let redditResults = searchReddit(query: query)
        async let hackerNewsResults = searchHackerNews(query: query)

        // Combine all results
        var allArticles: [Article] = []

        do {
            allArticles.append(contentsOf: try await wikipediaResults)
        } catch {
            print("⚠️ Wikipedia search failed: \(error)")
        }

        do {
            allArticles.append(contentsOf: try await redditResults)
        } catch {
            print("⚠️ Reddit search failed: \(error)")
        }

        do {
            allArticles.append(contentsOf: try await hackerNewsResults)
        } catch {
            print("⚠️ HackerNews search failed: \(error)")
        }

        if allArticles.isEmpty {
            throw ArticleSearchError.networkError
        }

        print("✅ Found \(allArticles.count) total articles from all sources")
        return allArticles.prefix(15).map { $0 }
    }
    
    // MARK: - Wikipedia Search
    private static func searchWikipedia(query: String) async throws -> [Article] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = "https://en.wikipedia.org/w/api.php?action=opensearch&search=\(encodedQuery)&limit=5&namespace=0&format=json"

        guard let url = URL(string: searchURL) else {
            throw ArticleSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("TOME/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count >= 4,
              let titles = json[1] as? [String],
              let descriptions = json[2] as? [String],
              let urls = json[3] as? [String] else {
            throw ArticleSearchError.parsingError
        }

        var articles: [Article] = []
        for i in 0..<min(titles.count, 3) {  // Limit to 3 Wikipedia results
            let title = titles[i]
            let description = descriptions[i].isEmpty ? "Wikipedia article about \(title)" : descriptions[i]
            let url = urls[i]

            articles.append(Article(
                id: UUID(),
                title: title,
                summary: description,
                url: url,
                timestamp: Date(),
                content: "",
                author: "Wikipedia",
                readingTime: 5,
                source: "Wikipedia"
            ))
        }

        print("📚 Wikipedia: Found \(articles.count) articles")
        return articles
    }

    // MARK: - Reddit Search
    private static func searchReddit(query: String) async throws -> [Article] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Search relevant subreddits for quality content
        let subreddits = ["programming", "science", "TrueReddit", "DepthHub", "AskScience"]
        let subreddit = subreddits.randomElement() ?? "programming"
        let searchURL = "https://www.reddit.com/r/\(subreddit)/search.json?q=\(encodedQuery)&restrict_sr=1&sort=top&limit=5"

        guard let url = URL(string: searchURL) else {
            throw ArticleSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("TOME/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let children = dataDict["children"] as? [[String: Any]] else {
            throw ArticleSearchError.parsingError
        }

        var articles: [Article] = []
        for child in children.prefix(3) {  // Limit to 3 Reddit results
            guard let post = child["data"] as? [String: Any],
                  let title = post["title"] as? String,
                  var urlString = post["url"] as? String,
                  let score = post["ups"] as? Int,
                  let numComments = post["num_comments"] as? Int else {
                continue
            }

            // Skip low-quality posts
            if score < 10 { continue }

            // For self posts, use Reddit link
            if let isself = post["is_self"] as? Bool, isself {
                if let permalink = post["permalink"] as? String {
                    urlString = "https://www.reddit.com\(permalink)"
                }
            }

            let selftext = (post["selftext"] as? String) ?? ""
            let summary = selftext.isEmpty ? "Reddit discussion with \(numComments) comments" : String(selftext.prefix(200))

            articles.append(Article(
                id: UUID(),
                title: title,
                summary: summary,
                url: urlString,
                timestamp: Date(),
                content: "",
                author: "r/\(subreddit)",
                readingTime: 5,
                source: "Reddit"
            ))
        }

        print("🤖 Reddit: Found \(articles.count) articles")
        return articles
    }

    // MARK: - HackerNews Search
    private static func searchHackerNews(query: String) async throws -> [Article] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = "https://hn.algolia.com/api/v1/search?query=\(encodedQuery)&tags=story&hitsPerPage=5"

        guard let url = URL(string: searchURL) else {
            throw ArticleSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("TOME/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = json["hits"] as? [[String: Any]] else {
            throw ArticleSearchError.parsingError
        }

        var articles: [Article] = []
        for hit in hits.prefix(3) {  // Limit to 3 HN results
            guard let title = hit["title"] as? String,
                  let points = hit["points"] as? Int else {
                continue
            }

            // Skip low-quality posts
            if points < 10 { continue }

            let urlString = (hit["url"] as? String) ?? "https://news.ycombinator.com/item?id=\(hit["objectID"] as? String ?? "")"
            let author = hit["author"] as? String ?? "HN User"
            let numComments = hit["num_comments"] as? Int ?? 0

            let summary = "HackerNews discussion with \(points) points and \(numComments) comments"

            articles.append(Article(
                id: UUID(),
                title: title,
                summary: summary,
                url: urlString,
                timestamp: Date(),
                content: "",
                author: author,
                readingTime: 5,
                source: "HackerNews"
            ))
        }

        print("🔶 HackerNews: Found \(articles.count) articles")
        return articles
    }

}

// Keep the original for compatibility
class ArticleSearchService {
    static func search(query: String) async throws -> [Article] {
        return try await RealArticleSearchService.searchArticles(query: query)
    }
}

class WebContentFetcher {
    static func fetchArticleContent(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ArticleSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        return extractTextFromHTML(html)
    }

    private static func extractTextFromHTML(_ html: String) -> String {
        var text = html

        // Remove script and style tags with their content
        let scriptPattern = "<script[^>]*>[\\s\\S]*?</script>"
        let stylePattern = "<style[^>]*>[\\s\\S]*?</style>"
        let commentPattern = "<!--[\\s\\S]*?-->"

        text = text.replacingOccurrences(of: scriptPattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: stylePattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: commentPattern, with: "", options: .regularExpression)

        // Try to extract main content from common article tags
        let articlePatterns = [
            "<article[^>]*>([\\s\\S]*?)</article>",
            "<main[^>]*>([\\s\\S]*?)</main>",
            "<div[^>]*class=\"[^\"]*content[^\"]*\"[^>]*>([\\s\\S]*?)</div>",
            "<div[^>]*class=\"[^\"]*article[^\"]*\"[^>]*>([\\s\\S]*?)</div>"
        ]

        for pattern in articlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                text = String(text[range])
                break
            }
        }

        // Remove all HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&rsquo;", "'"),
            ("&lsquo;", "'"),
            ("&rdquo;", "\""),
            ("&ldquo;", "\"")
        ]

        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }

        // Clean up whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Return meaningful content or error message
        if text.isEmpty || text.count < 100 {
            return "Content could not be extracted from this URL. The page may require JavaScript or have restricted access."
        }

        // Limit to reasonable length (first ~5000 words)
        let words = text.split(separator: " ")
        if words.count > 5000 {
            return words.prefix(5000).joined(separator: " ") + "\n\n[Content truncated for readability...]"
        }

        return text
    }
}

enum ArticleSearchError: Error {
    case invalidURL
    case networkError
    case parsingError
}

struct DuckDuckGoResponse: Codable {
    let relatedTopics: [RelatedTopic]
    
    enum CodingKeys: String, CodingKey {
        case relatedTopics = "RelatedTopics"
    }
}

struct RelatedTopic: Codable {
    let text: String
    let firstURL: String?
    
    enum CodingKeys: String, CodingKey {
        case text = "Text"
        case firstURL = "FirstURL"
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        return Array(Set(self))
    }
}
