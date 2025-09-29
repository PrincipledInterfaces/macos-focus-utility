import SwiftUI
import AVFoundation

struct GardenView: View {
    @ObservedObject var currentState: TOMEState
    @State private var breathingPhase: Double = 0.0
    @State private var showBreathingGuide = true
    @State private var currentExercise: MindfulnessExercise = .breathing
    @State private var sessionDuration: TimeInterval = 300 // 5 minutes
    @State private var elapsedTime: TimeInterval = 0
    @State private var isSessionActive = false
    @State private var reflectionText = ""
    @State private var moodRating: Int = 3
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAudioPlaying = false
    @State private var selectedNatureSound: NatureSound = .forestRain
    @State private var selectedNatureScene: NatureScene = .zenGarden
    @State private var aiPrompts: [String] = []
    @State private var showAIDialogue = false
    @State private var currentAIPrompt = ""
    @State private var aiResponse = ""
    @State private var isProcessingAI = false
    
    let onNavigateHome: () -> Void
    
    init(currentState: TOMEState, onNavigateHome: @escaping () -> Void = {}) {
        self.currentState = currentState
        self.onNavigateHome = onNavigateHome
    }
    
    var body: some View {
        ZStack {
            // Natural background with animated elements
            gardenBackground
            
            VStack(spacing: 0) {
                // Header with exit
                gardenHeader
                
                Spacer()
                
                // Main content area
                if showBreathingGuide {
                    breathingExerciseView
                } else {
                    switch currentExercise {
                    case .breathing:
                        breathingExerciseView
                    case .meditation:
                        meditationView
                    case .reflection:
                        reflectionView
                    case .stretching:
                        stretchingView
                    }
                }
                
                Spacer()
                
                // Exercise controls
                exerciseControls
                    .padding(.bottom, 40)
            }
            
            // Floating particles for ambiance
            particleEffects
        }
        .overlay(
            TOMENavigationOverlay(
                onNavigateHome: onNavigateHome,
                environmentName: "Garden",
                environmentColor: .green
            )
        )
        .onAppear {
            startBreathingAnimation()
            startAmbientSounds()
            generateIntrospectivePrompts()
        }
        .onDisappear {
            stopAmbientSounds()
        }
    }
    
    private var gardenBackground: some View {
        ZStack {
            // Base nature gradient
            LinearGradient(
                colors: [
                    Color.green.opacity(0.15),
                    Color.black,
                    Color.green.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated growing elements
            ForEach(0..<8, id: \.self) { index in
                growingPlant(at: index)
            }
            
            // Breathing light pulses
            breathingLight
        }
        .ignoresSafeArea(.all)
    }
    
    private func growingPlant(at index: Int) -> some View {
        let angles = Array(stride(from: 0, to: 360, by: 45))
        let angle = angles[index % angles.count]
        
        return Circle()
            .fill(Color.green.opacity(0.02))
            .frame(width: CGFloat(40 + index * 20))
            .offset(
                x: cos(Double(angle) * .pi / 180) * 300,
                y: sin(Double(angle) * .pi / 180) * 200
            )
            .scaleEffect(0.8 + sin(breathingPhase + Double(index)) * 0.2)
            .opacity(0.3 + sin(breathingPhase + Double(index) * 0.5) * 0.2)
    }
    
    private var breathingLight: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.green.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 300
                )
            )
            .frame(width: 600, height: 600)
            .scaleEffect(0.8 + sin(breathingPhase) * 0.3)
            .opacity(0.5 + sin(breathingPhase) * 0.3)
            .animation(.easeInOut(duration: 4).repeatForever(), value: breathingPhase)
    }
    
    private var particleEffects: some View {
        ForEach(0..<15, id: \.self) { index in
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: CGFloat.random(in: 2...6))
                .position(
                    x: CGFloat.random(in: 0...1920),
                    y: CGFloat.random(in: 0...1080)
                )
                .animation(
                    .linear(duration: Double.random(in: 15...30))
                    .repeatForever(autoreverses: false),
                    value: breathingPhase
                )
        }
    }
    
    private var gardenHeader: some View {
        HStack {
            Button(action: { /* Exit to home */ }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text("GARDEN")
                    .font(.system(size: 18, weight: .light, design: .default))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Rest & Reflection")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Session timer
            sessionTimerView
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var sessionTimerView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if isSessionActive {
                Text(formatTime(elapsedTime))
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.green.opacity(0.8))
                
                Text("/ \(formatTime(sessionDuration))")
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Text("Ready")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var breathingExerciseView: some View {
        VStack(spacing: 40) {
            // Breathing visualization
            breathingVisualization
            
            // Breathing instructions
            breathingInstructions
        }
    }
    
    private var breathingVisualization: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: 2)
                .frame(width: 300, height: 300)
            
            // Breathing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.green.opacity(0.3),
                            Color.green.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(0.6 + sin(breathingPhase) * 0.4)
                .animation(.easeInOut(duration: 4).repeatForever(), value: breathingPhase)
            
            // Center guidance
            VStack(spacing: 8) {
                Text(breathingInstruction)
                    .font(.system(size: 24, weight: .light, design: .default))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 2), value: breathingInstruction)
                
                Text(breathingSubtext)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.6))
                    .animation(.easeInOut(duration: 2), value: breathingSubtext)
            }
        }
    }
    
    private var breathingInstruction: String {
        let phase = sin(breathingPhase)
        if phase > 0.7 {
            return "INHALE"
        } else if phase < -0.7 {
            return "EXHALE"
        } else {
            return "HOLD"
        }
    }
    
    private var breathingSubtext: String {
        let phase = sin(breathingPhase)
        if phase > 0.7 {
            return "Breathe in slowly"
        } else if phase < -0.7 {
            return "Release gently"
        } else {
            return "Pause naturally"
        }
    }
    
    private var breathingInstructions: some View {
        VStack(spacing: 12) {
            Text("4-7-8 Breathing Technique")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 6) {
                instructionStep("1.", "Inhale for 4 counts")
                instructionStep("2.", "Hold for 7 counts")
                instructionStep("3.", "Exhale for 8 counts")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func instructionStep(_ number: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(.green.opacity(0.8))
                .frame(width: 20, alignment: .leading)
            
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var meditationView: some View {
        VStack(spacing: 24) {
            Text("MINDFUL MEDITATION")
                .font(.system(size: 20, weight: .light, design: .default))
                .foregroundColor(.white)
            
            Text("Focus on the present moment. Notice your thoughts without judgment, then gently return your attention to your breath.")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Simple meditation timer
            Text(formatTime(sessionDuration - elapsedTime))
                .font(.system(size: 48, weight: .ultraLight, design: .default))
                .foregroundColor(.green.opacity(0.8))
        }
    }
    
    private var reflectionView: some View {
        VStack(spacing: 24) {
            HStack {
                Text("REFLECTION")
                    .font(.system(size: 20, weight: .light, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showAIDialogue.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showAIDialogue ? "brain.head.profile" : "sparkles")
                            .font(.system(size: 12, weight: .medium))
                        Text(showAIDialogue ? "Journal" : "AI Guide")
                            .font(.system(size: 10, weight: .medium, design: .default))
                    }
                    .foregroundColor(.green.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.1))
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if showAIDialogue {
                aiDialogueSection
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                VStack(spacing: 16) {
                    // Mood tracking
                    moodTracker
                    
                    // Reflection notes
                    reflectionNotes
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: 600)
        .animation(.easeInOut(duration: 0.3), value: showAIDialogue)
    }
    
    private var moodTracker: some View {
        VStack(spacing: 12) {
            Text("How are you feeling?")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { rating in
                    Button(action: { moodRating = rating }) {
                        Image(systemName: moodIcon(rating))
                            .font(.system(size: 20, weight: .medium))
                            .scaleEffect(moodRating == rating ? 1.2 : 1.0)
                            .opacity(moodRating == rating ? 1.0 : 0.6)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func moodIcon(_ rating: Int) -> String {
        switch rating {
        case 1: return "minus.circle"
        case 2: return "minus"
        case 3: return "circle"
        case 4: return "plus"
        case 5: return "plus.circle"
        default: return "circle"
        }
    }
    
    private var reflectionNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reflection Notes")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.8))
            
            TextEditor(text: $reflectionText)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.white)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .frame(height: 120)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .overlay(
                    Text("What insights emerged during your session?")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(12)
                        .allowsHitTesting(false)
                        .opacity(reflectionText.isEmpty ? 1 : 0),
                    alignment: .topLeading
                )
        }
    }
    
    private var stretchingView: some View {
        VStack(spacing: 24) {
            Text("STRETCHING BREAK")
                .font(.system(size: 20, weight: .light, design: .default))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ForEach(stretchingExercises, id: \.name) { exercise in
                    stretchingExerciseCard(exercise)
                }
            }
            .frame(maxWidth: 500)
        }
    }
    
    private func stretchingExerciseCard(_ exercise: StretchingExercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(exercise.duration)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: exercise.icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var exerciseControls: some View {
        VStack(spacing: 16) {
            // Exercise selector
            HStack(spacing: 12) {
                ForEach(MindfulnessExercise.allCases, id: \.self) { exercise in
                    exerciseButton(exercise)
                }
            }
            
            // Session controls
            HStack(spacing: 16) {
                if !isSessionActive {
                    Button("Start Session") {
                        startSession()
                    }
                    .font(.tomeSmallMedium())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button("End Session") {
                        endSession()
                    }
                    .font(.tomeSmallMedium())
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.2))
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                    )
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func exerciseButton(_ exercise: MindfulnessExercise) -> some View {
        Button(action: { 
            currentExercise = exercise
            showBreathingGuide = false
        }) {
            VStack(spacing: 4) {
                Image(systemName: exercise.icon)
                    .font(.tomeBody())
                
                Text(exercise.displayName)
                    .font(.tomeSmallLabelMedium())
                    .foregroundColor(currentExercise == exercise ? .white : .white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(currentExercise == exercise ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                    .stroke(currentExercise == exercise ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startBreathingAnimation() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            breathingPhase = .pi * 2
        }
    }
    
    private func startAmbientSounds() {
        playNatureSound(selectedNatureSound)
    }
    
    private func stopAmbientSounds() {
        audioPlayer?.stop()
        audioPlayer = nil
        isAudioPlaying = false
    }
    
    private func playNatureSound(_ sound: NatureSound) {
        // First try to load bundled audio file
        if loadBundledAudio(sound.audioFileName, soundName: sound.name) {
            return
        }
        
        // If no bundled file, generate a simple tone
        generateSimpleTone(for: sound)
    }
    
    private func loadBundledAudio(_ fileName: String, soundName: String) -> Bool {
        // Try to find bundled audio file
        guard let audioURL = Bundle.main.url(forResource: fileName, withExtension: "mp3") ??
                             Bundle.main.url(forResource: fileName, withExtension: "wav") ??
                             Bundle.main.url(forResource: fileName, withExtension: "m4a") else {
            print("No bundled audio file found for: \(fileName)")
            return false
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.6
            audioPlayer?.prepareToPlay()
            
            if audioPlayer?.play() == true {
                isAudioPlaying = true
                print("Playing bundled audio: \(soundName)")
                return true
            }
        } catch {
            print("Failed to play bundled audio: \(error)")
        }
        
        return false
    }
    
    private func generateSimpleTone(for sound: NatureSound) {
        // Generate a simple repeating tone as a placeholder
        isAudioPlaying = true
        print("Playing generated tone for: \(sound.name)")
        
        // Create a timer that simulates audio playback
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
            if self.isAudioPlaying {
                print("🎵 \(sound.name) ambient sound continues...")
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func fallbackToLocalAudio(soundName: String) {
        // Fallback to bundled audio files or generate simple tones
        print("Using fallback audio for: \(soundName)")
        
        // Create a simple repeating notification to simulate audio
        isAudioPlaying = true
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
            if self.isAudioPlaying {
                print("🎵 \(soundName) ambient sounds playing...")
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func startSession() {
        isSessionActive = true
        elapsedTime = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if isSessionActive && elapsedTime < sessionDuration {
                elapsedTime += 1
            } else {
                timer.invalidate()
                if elapsedTime >= sessionDuration {
                    endSession()
                }
            }
        }
    }
    
    private func endSession() {
        isSessionActive = false
        // Save reflection data to user state
        saveReflectionData()
    }
    
    private func saveReflectionData() {
        if !reflectionText.isEmpty {
            // Save reflection to a todo for future reference
            currentState.addTodo("Review Garden reflection: \(reflectionText.prefix(50))...")
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var stretchingExercises: [StretchingExercise] {
        [
            StretchingExercise(name: "Neck rolls", duration: "30 seconds", icon: "arrow.circlepath"),
            StretchingExercise(name: "Shoulder shrugs", duration: "30 seconds", icon: "arrow.up.and.down"),
            StretchingExercise(name: "Wrist stretches", duration: "30 seconds", icon: "hand.raised"),
            StretchingExercise(name: "Seated spinal twist", duration: "1 minute", icon: "arrow.triangle.2.circlepath")
        ]
    }
    
    // MARK: - AI Integration for Introspective Dialogue
    
    private var aiDialogueSection: some View {
        VStack(spacing: 16) {
            Text("Mindful Reflection with AI")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.9))
            
            if !currentAIPrompt.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reflection Prompt:")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.green.opacity(0.8))
                    
                    Text(currentAIPrompt)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.05))
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Response:")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.8))
                
                TextEditor(text: $reflectionText)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.03))
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(
                        Text("Take your time... let your thoughts flow naturally")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(12)
                            .allowsHitTesting(false)
                            .opacity(reflectionText.isEmpty ? 1 : 0),
                        alignment: .topLeading
                    )
            }
            
            HStack(spacing: 12) {
                Button("New Prompt") {
                    generateNewPrompt()
                }
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.green.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.1))
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .buttonStyle(PlainButtonStyle())
                
                if !reflectionText.isEmpty {
                    Button(isProcessingAI ? "Processing..." : "AI Response") {
                        getAIReflectionResponse()
                    }
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(isProcessingAI ? 0.5 : 0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessingAI)
                }
            }
            
            if !aiResponse.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Reflection:")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text(aiResponse)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.05))
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: 550)
    }
    
    private func generateIntrospectivePrompts() {
        aiPrompts = [
            "What emotions or thoughts are you carrying from today? How might you set them down gently?",
            "If your present self could send a message to your past self from this morning, what would it be?",
            "What small moment today brought you unexpected joy or peace?",
            "What would you like to forgive yourself for today?",
            "If you could plant one seed of intention for tomorrow, what would it grow into?",
            "What patterns in your thinking today served you? Which ones might you want to tend differently?",
            "What are you grateful for in this very moment, including challenges that helped you grow?",
            "How has your relationship with yourself evolved today?",
            "What would it look like to treat yourself with the same compassion you'd show a dear friend?",
            "What truth about yourself are you ready to acknowledge today?"
        ]
        
        // Select a random prompt to start
        if let randomPrompt = aiPrompts.randomElement() {
            currentAIPrompt = randomPrompt
        }
    }
    
    private func generateNewPrompt() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newPrompt = aiPrompts.filter({ $0 != currentAIPrompt }).randomElement() {
                currentAIPrompt = newPrompt
            }
        }
    }
    
    private func getAIReflectionResponse() {
        guard !reflectionText.isEmpty, let aiService = currentState.openAIService else {
            return
        }
        
        isProcessingAI = true
        aiResponse = ""
        
        let mindfulPrompt = """
        You are a gentle, wise mindfulness teacher having a compassionate dialogue with someone in reflection. 
        They shared: "\(reflectionText)"
        
        Respond with:
        - Deep empathy and understanding
        - Gentle insight without judgment
        - A thoughtful question or reflection to deepen their awareness
        - Validation of their experience
        
        Keep your response warm, concise (2-3 sentences), and focused on their inner wisdom rather than giving advice.
        """
        
        let messages = [ChatMessage(role: "user", content: mindfulPrompt)]
        
        aiService.chatCompletion(messages: messages, model: "gpt-3.5-turbo") { result in
            DispatchQueue.main.async {
                isProcessingAI = false
                
                switch result {
                case .success(let response):
                    withAnimation(.easeInOut(duration: 0.5)) {
                        aiResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                case .failure(let error):
                    print("AI reflection error: \(error)")
                    aiResponse = "I'm here to listen. Sometimes the most profound insights come from within our own reflection."
                }
            }
        }
    }
}

enum MindfulnessExercise: String, CaseIterable {
    case breathing = "breathing"
    case meditation = "meditation"
    case reflection = "reflection"
    case stretching = "stretching"
    
    var displayName: String {
        switch self {
        case .breathing: return "Breathing"
        case .meditation: return "Meditation"
        case .reflection: return "Reflection"
        case .stretching: return "Stretching"
        }
    }
    
    var icon: String {
        switch self {
        case .breathing: return "lungs"
        case .meditation: return "figure.mind.and.body"
        case .reflection: return "bubble.left"
        case .stretching: return "figure.flexibility"
        }
    }
}

struct StretchingExercise {
    let name: String
    let duration: String
    let icon: String
}

enum NatureSound: String, CaseIterable {
    case forestRain = "forest_rain"
    case oceanWaves = "ocean_waves"
    case birds = "birds"
    case wind = "wind"
    case stream = "stream"
    case thunderstorm = "thunderstorm"
    
    var name: String {
        switch self {
        case .forestRain: return "Forest Rain"
        case .oceanWaves: return "Ocean Waves"
        case .birds: return "Bird Songs"
        case .wind: return "Gentle Wind"
        case .stream: return "Babbling Stream"
        case .thunderstorm: return "Distant Thunder"
        }
    }
    
    var icon: String {
        switch self {
        case .forestRain: return "cloud.rain"
        case .oceanWaves: return "waveform"
        case .birds: return "bird"
        case .wind: return "wind"
        case .stream: return "water.waves"
        case .thunderstorm: return "cloud.bolt"
        }
    }
    
    // Audio file names (these would be bundled with the app)
    var audioFileName: String {
        switch self {
        case .forestRain:
            return "forest_rain"
        case .oceanWaves:
            return "ocean_waves"
        case .birds:
            return "bird_songs"
        case .wind:
            return "gentle_wind"
        case .stream:
            return "babbling_stream"
        case .thunderstorm:
            return "distant_thunder"
        }
    }
}

enum NatureScene: String, CaseIterable {
    case zenGarden = "zen_garden"
    case forestPath = "forest_path"
    case mountainLake = "mountain_lake"
    case bambooGrove = "bamboo_grove"
    case meadow = "meadow"
    case sunset = "sunset"
    
    var name: String {
        switch self {
        case .zenGarden: return "Zen Garden"
        case .forestPath: return "Forest Path"
        case .mountainLake: return "Mountain Lake"
        case .bambooGrove: return "Bamboo Grove"
        case .meadow: return "Peaceful Meadow"
        case .sunset: return "Golden Sunset"
        }
    }
    
    // High-quality nature images from Unsplash (free for commercial use)
    var imageURL: String {
        switch self {
        case .zenGarden:
            return "https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=1920&h=1080&fit=crop&auto=format&q=80"
        case .forestPath:
            return "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1920&h=1080&fit=crop&auto=format&q=80"
        case .mountainLake:
            return "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&h=1080&fit=crop&auto=format&q=80"
        case .bambooGrove:
            return "https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=1920&h=1080&fit=crop&auto=format&q=80"
        case .meadow:
            return "https://images.unsplash.com/photo-1500964757637-c85e8a162699?w=1920&h=1080&fit=crop&auto=format&q=80"
        case .sunset:
            return "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&h=1080&fit=crop&auto=format&q=80"
        }
    }
    
    var description: String {
        switch self {
        case .zenGarden: return "A peaceful Japanese zen garden with raked sand and stones"
        case .forestPath: return "A serene path winding through tall forest trees"
        case .mountainLake: return "A crystal clear lake reflecting mountain peaks"
        case .bambooGrove: return "Tall bamboo stalks swaying gently in the breeze"
        case .meadow: return "A bright meadow filled with wildflowers"
        case .sunset: return "Golden hour light filtering through nature"
        }
    }
}


