import SwiftUI
import AppKit
import AVFoundation

/// High-resolution rendering utility for marketing materials
/// Renders SwiftUI views at 8x Retina resolution for crisp zoom-ins in video ads
struct MarketingExporter {

    static let exportScale: CGFloat = 8.0 // 8x Retina = ultra high resolution
    static let baseSize = CGSize(width: 1200, height: 800)
    static let animationFPS: Int = 60 // 60fps for smooth animations
    static let animationScale: CGFloat = 4.0 // 4x for animations (smaller files, still high quality)

    /// Renders a SwiftUI view at ultra-high resolution
    static func render<Content: View>(
        _ view: Content,
        name: String,
        folder: String,
        size: CGSize = baseSize
    ) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = exportScale

        guard let nsImage = renderer.nsImage,
              let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            print("❌ Failed to render: \(name)")
            return
        }

        // Save as PNG (lossless)
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("❌ Failed to create PNG: \(name)")
            return
        }

        let baseURL = FileManager.default.currentDirectoryPath
        let folderURL = URL(fileURLWithPath: "\(baseURL)/MarketingExport/\(folder)")

        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileURL = folderURL.appendingPathComponent("\(name).png")

        do {
            try pngData.write(to: fileURL)
            let fileSize = Double(pngData.count) / 1_000_000
            print("✅ Exported: \(folder)/\(name).png (\(String(format: "%.1f", fileSize))MB)")
        } catch {
            print("❌ Failed to write: \(name) - \(error)")
        }
    }

    /// Renders an animation as PNG sequence with transparency
    /// PNG sequences can be imported into any video editor and converted to ProRes 4444
    static func renderAnimation<Content: View>(
        _ viewBuilder: @escaping (Double) -> Content,
        name: String,
        duration: Double = 2.0,
        size: CGSize = CGSize(width: 800, height: 800)
    ) {
        let totalFrames = Int(duration * Double(animationFPS))
        let folderName = "Animations/PNGSequences/\(name)"

        print("🎬 Rendering animation: \(name)")
        print("   Duration: \(duration)s @ \(animationFPS)fps = \(totalFrames) frames")

        let baseURL = FileManager.default.currentDirectoryPath
        let folderURL = URL(fileURLWithPath: "\(baseURL)/MarketingExport/\(folderName)")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for frame in 0..<totalFrames {
            let progress = Double(frame) / Double(totalFrames - 1)
            let view = viewBuilder(progress)

            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            renderer.scale = animationScale

            guard let nsImage = renderer.nsImage,
                  let tiffData = nsImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                continue
            }

            // Frame naming: name_0001.png, name_0002.png, etc.
            let frameNumber = String(format: "%04d", frame + 1)
            let fileURL = folderURL.appendingPathComponent("\(name)_\(frameNumber).png")

            try? pngData.write(to: fileURL)

            if frame % 10 == 0 {
                print("   Frame \(frame + 1)/\(totalFrames)")
            }
        }

        print("✅ Animation exported: \(folderName)")
        print("   Convert to MOV: see ASSET_INFO.txt for ffmpeg command\n")
    }

    /// Export all environments at multiple states
    static func exportAllEnvironments(state: TOMEState) {
        print("\n🎬 Starting Marketing Asset Export...")
        print("📐 Resolution: \(Int(baseSize.width * exportScale))x\(Int(baseSize.height * exportScale)) pixels")
        print("📊 Scale: \(exportScale)x Retina\n")

        // Home Environment
        render(HomeView().environmentObject(state),
               name: "home-default",
               folder: "Environments/Home")

        // Garden Environment
        render(GardenView().environmentObject(state),
               name: "garden-default",
               folder: "Environments/Garden")

        // Workshop Environment
        render(WorkshopView().environmentObject(state),
               name: "workshop-default",
               folder: "Environments/Workshop")

        // Coffeeshop Environment
        render(CoffeeshopView().environmentObject(state),
               name: "coffeeshop-default",
               folder: "Environments/Coffeeshop")

        // Writer's Desk Environment
        render(WriterDeskView().environmentObject(state),
               name: "writerdesk-default",
               folder: "Environments/WriterDesk")

        // Planning Environment
        render(PlanningView().environmentObject(state),
               name: "planning-default",
               folder: "Environments/Planning")

        // Components - Static shockwave frames
        render(GlassmorphicShockwave(isAnimating: .constant(true)),
               name: "glassmorphic-shockwave-frame",
               folder: "Components/Shockwaves",
               size: CGSize(width: 800, height: 800))

        render(WorkshopShockwave(isAnimating: .constant(true)),
               name: "workshop-shockwave-frame",
               folder: "Components/Shockwaves",
               size: CGSize(width: 800, height: 800))

        print("\n✨ Marketing asset export complete!")
        print("📁 Location: MarketingExport/")
        print("🎥 Ready for After Effects, Motion, or Final Cut Pro\n")
    }

    /// Export animated shockwaves as PNG sequences
    static func exportAnimations() {
        print("\n🎞️ Starting Animation Export...")
        print("📐 Resolution: 3200x3200 (4x scale)")
        print("🎬 Frame Rate: 60fps\n")

        // Glassmorphic Shockwave Animation
        renderAnimation(name: "glassmorphic-shockwave", duration: 2.0) { progress in
            GlassmorphicShockwave(isAnimating: .constant(true))
                .opacity(progress < 0.1 ? progress * 10 : 1.0) // Fade in
        }

        // Workshop Shockwave Animation
        renderAnimation(name: "workshop-shockwave", duration: 2.0) { progress in
            WorkshopShockwave(isAnimating: .constant(true))
                .opacity(progress < 0.1 ? progress * 10 : 1.0) // Fade in
        }

        print("\n✨ Animation export complete!")
        print("📁 Location: MarketingExport/Animations/PNGSequences/")
        print("💡 Convert to transparent MOV using the conversion script\n")
    }
}

// Extension to make views easier to export
extension View {
    func exportForMarketing(name: String, folder: String, size: CGSize = MarketingExporter.baseSize) {
        MarketingExporter.render(self, name: name, folder: folder, size: size)
    }
}
