import SwiftUI
import AVKit

struct TransitionView: View {
    let fromEnvironment: TOMEEnvironment
    let toEnvironment: TOMEEnvironment
    let progress: CGFloat
    
    @State private var player: AVPlayer?
    @State private var showVideo = false
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea(.all)
            
            if showVideo, let player = player {
                // Video transition
                VideoPlayer(player: player)
                    .ignoresSafeArea(.all)
                    .opacity(progress)
            } else {
                // Fallback animated transition
                fallbackTransition
            }
            
            // Overlay effect
            overlayEffect
        }
        .onAppear {
            setupVideoTransition()
        }
    }
    
    private var fallbackTransition: some View {
        ZStack {
            // Animated circles expanding from center
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(toEnvironment.primaryColor.opacity(0.1))
                    .frame(width: CGFloat(100 + index * 200) * progress)
                    .scaleEffect(progress)
            }
            
            // Environment icon transition
            VStack {
                Image(systemName: toEnvironment.icon)
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundColor(toEnvironment.primaryColor)
                    .scaleEffect(0.5 + progress * 0.5)
                    .opacity(progress)
                
                Text(toEnvironment.displayName)
                    .font(.tomeTitle())
                    .foregroundColor(.white)
                    .opacity(progress)
            }
        }
    }
    
    private var overlayEffect: some View {
        ZStack {
            // Scanline effect
            VStack(spacing: 4) {
                ForEach(0..<200, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.01))
                        .frame(height: 1)
                }
            }
            .opacity(progress * 0.3)
            
            // Vignette effect
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ],
                center: .center,
                startRadius: 300,
                endRadius: 800
            )
            .opacity(progress)
        }
    }
    
    private func setupVideoTransition() {
        guard let videoURL = getVideoURL(for: toEnvironment) else {
            return
        }
        
        player = AVPlayer(url: videoURL)
        
        // Configure player for seamless playback
        player?.actionAtItemEnd = .none
        player?.isMuted = false
        player?.volume = 0.3
        
        showVideo = true
        player?.play()
        
        // Stop video quickly - no need for long delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            player?.pause()
            player = nil
            showVideo = false
        }
    }
    
    private func getVideoURL(for environment: TOMEEnvironment) -> URL? {
        // Map environments to legacy video files
        let videoName: String
        switch environment {
        case .planning, .writerDesk:
            videoName = "productivity"
        case .workshop, .coffeeshop:
            videoName = "creativity"
        case .garden:
            videoName = "social_media_detox"
        case .home:
            videoName = "productivity" // Default
        }
        
        // Look for video in legacy folder
        let videoPath = "legacy/videos/\(videoName).mp4"
        
        if FileManager.default.fileExists(atPath: videoPath) {
            return URL(fileURLWithPath: videoPath)
        }
        
        // Fallback to bundle if available
        return Bundle.main.url(forResource: videoName, withExtension: "mp4")
    }
}

