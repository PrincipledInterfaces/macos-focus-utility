import SwiftUI
import Foundation

/// Settings for the overhead HUD projector system
class HUDProjectorSettings: ObservableObject, Codable {
    @Published var isEnabled: Bool = false
    @Published var isCalibrated: Bool = false
    @Published var selectedDisplayID: CGDirectDisplayID? = nil
    @Published var selectedDisplayName: String? = nil

    // TOME physical location calibration
    @Published var frontLeftCorner: CGPoint = .zero
    @Published var frontRightCorner: CGPoint = .zero

    // Projection crop boundaries (relative to display coordinates)
    @Published var cropRect: CGRect = .zero

    // Display resolution (stored for reference)
    @Published var displayWidth: CGFloat = 0
    @Published var displayHeight: CGFloat = 0

    // Computed properties for content positioning
    var frontEdgeCenter: CGPoint {
        CGPoint(
            x: (frontLeftCorner.x + frontRightCorner.x) / 2,
            y: (frontLeftCorner.y + frontRightCorner.y) / 2
        )
    }

    var frontEdgeWidth: CGFloat {
        let dx = frontRightCorner.x - frontLeftCorner.x
        let dy = frontRightCorner.y - frontLeftCorner.y
        return sqrt(dx * dx + dy * dy)
    }

    var frontEdgeAngle: CGFloat {
        let dx = frontRightCorner.x - frontLeftCorner.x
        let dy = frontRightCorner.y - frontLeftCorner.y
        return atan2(dy, dx)
    }

    // Singleton instance
    static let shared = HUDProjectorSettings()

    private init() {
        loadFromUserDefaults()
    }

    // MARK: - Codable Support

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case isCalibrated
        case selectedDisplayID
        case selectedDisplayName
        case frontLeftCornerX
        case frontLeftCornerY
        case frontRightCornerX
        case frontRightCornerY
        case cropRectX
        case cropRectY
        case cropRectWidth
        case cropRectHeight
        case displayWidth
        case displayHeight
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isCalibrated = try container.decode(Bool.self, forKey: .isCalibrated)

        if let displayID = try container.decodeIfPresent(UInt32.self, forKey: .selectedDisplayID) {
            selectedDisplayID = displayID
        }
        selectedDisplayName = try container.decodeIfPresent(String.self, forKey: .selectedDisplayName)

        let flx = try container.decode(CGFloat.self, forKey: .frontLeftCornerX)
        let fly = try container.decode(CGFloat.self, forKey: .frontLeftCornerY)
        frontLeftCorner = CGPoint(x: flx, y: fly)

        let frx = try container.decode(CGFloat.self, forKey: .frontRightCornerX)
        let fry = try container.decode(CGFloat.self, forKey: .frontRightCornerY)
        frontRightCorner = CGPoint(x: frx, y: fry)

        let cx = try container.decode(CGFloat.self, forKey: .cropRectX)
        let cy = try container.decode(CGFloat.self, forKey: .cropRectY)
        let cw = try container.decode(CGFloat.self, forKey: .cropRectWidth)
        let ch = try container.decode(CGFloat.self, forKey: .cropRectHeight)
        cropRect = CGRect(x: cx, y: cy, width: cw, height: ch)

        displayWidth = try container.decode(CGFloat.self, forKey: .displayWidth)
        displayHeight = try container.decode(CGFloat.self, forKey: .displayHeight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isCalibrated, forKey: .isCalibrated)

        if let displayID = selectedDisplayID {
            try container.encode(displayID, forKey: .selectedDisplayID)
        }
        try container.encodeIfPresent(selectedDisplayName, forKey: .selectedDisplayName)

        // Encode points with separate keys for x and y
        try container.encode(frontLeftCorner.x, forKey: .frontLeftCornerX)
        try container.encode(frontLeftCorner.y, forKey: .frontLeftCornerY)
        try container.encode(frontRightCorner.x, forKey: .frontRightCornerX)
        try container.encode(frontRightCorner.y, forKey: .frontRightCornerY)

        // Encode rect with separate keys
        try container.encode(cropRect.origin.x, forKey: .cropRectX)
        try container.encode(cropRect.origin.y, forKey: .cropRectY)
        try container.encode(cropRect.size.width, forKey: .cropRectWidth)
        try container.encode(cropRect.size.height, forKey: .cropRectHeight)

        try container.encode(displayWidth, forKey: .displayWidth)
        try container.encode(displayHeight, forKey: .displayHeight)
    }

    // MARK: - Persistence

    func saveToUserDefaults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: "hud_projector_settings")
            print("💾 Saved HUD projector settings")
        }
    }

    func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "hud_projector_settings"),
              let decoded = try? JSONDecoder().decode(HUDProjectorSettings.self, from: data) else {
            print("⚠️ No saved HUD projector settings found, using defaults")
            return
        }

        self.isEnabled = decoded.isEnabled
        self.isCalibrated = decoded.isCalibrated
        self.selectedDisplayID = decoded.selectedDisplayID
        self.selectedDisplayName = decoded.selectedDisplayName
        self.frontLeftCorner = decoded.frontLeftCorner
        self.frontRightCorner = decoded.frontRightCorner
        self.cropRect = decoded.cropRect
        self.displayWidth = decoded.displayWidth
        self.displayHeight = decoded.displayHeight

        print("✅ Loaded HUD projector settings")
    }

    // MARK: - Display Management

    func getAvailableDisplays() -> [(id: CGDirectDisplayID, name: String, bounds: CGRect)] {
        var displays: [(id: CGDirectDisplayID, name: String, bounds: CGRect)] = []

        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 32)

        guard CGGetActiveDisplayList(32, &displayIDs, &displayCount) == .success else {
            print("❌ Failed to get active display list")
            return displays
        }

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let bounds = CGDisplayBounds(displayID)
            let name = getDisplayName(for: displayID)
            displays.append((id: displayID, name: name, bounds: bounds))
        }

        return displays
    }

    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        // Try to get the display name using IOKit
        var name = "Display \(displayID)"

        // Check if it's the main display
        if CGDisplayIsMain(displayID) != 0 {
            name = "Main Display (\(displayID))"
        } else {
            name = "External Display (\(displayID))"
        }

        return name
    }

    func selectDisplay(_ displayID: CGDirectDisplayID) {
        self.selectedDisplayID = displayID

        // Get display bounds
        let bounds = CGDisplayBounds(displayID)
        self.displayWidth = bounds.width
        self.displayHeight = bounds.height
        self.selectedDisplayName = getDisplayName(for: displayID)

        // Reset calibration when display changes
        self.isCalibrated = false

        print("📺 Selected display: \(selectedDisplayName ?? "Unknown") (\(displayWidth)x\(displayHeight))")
    }

    func saveCalibration(frontLeft: CGPoint, frontRight: CGPoint, crop: CGRect) {
        self.frontLeftCorner = frontLeft
        self.frontRightCorner = frontRight
        self.cropRect = crop
        self.isCalibrated = true

        saveToUserDefaults()

        print("✅ HUD calibration saved:")
        print("   Front edge: \(frontLeft) to \(frontRight)")
        print("   Crop rect: \(crop)")
    }

    func resetCalibration() {
        self.isCalibrated = false
        self.frontLeftCorner = .zero
        self.frontRightCorner = .zero
        self.cropRect = .zero

        saveToUserDefaults()

        print("🔄 HUD calibration reset")
    }
}

// MARK: - Coordinate Transformation Helpers

extension HUDProjectorSettings {
    /// Transform a point from TOME-relative coordinates to display coordinates
    /// - Parameter relativePoint: Point relative to TOME front edge (0,0 = center of front edge, positive Y = away from user)
    /// - Returns: Point in display coordinate space
    func transformToDisplayCoordinates(_ relativePoint: CGPoint) -> CGPoint {
        let center = frontEdgeCenter
        let angle = frontEdgeAngle

        // Apply rotation and translation
        let cos = CGFloat(Darwin.cos(angle))
        let sin = CGFloat(Darwin.sin(angle))

        let rotatedX = relativePoint.x * cos - relativePoint.y * sin
        let rotatedY = relativePoint.x * sin + relativePoint.y * cos

        return CGPoint(
            x: center.x + rotatedX,
            y: center.y + rotatedY
        )
    }

    /// Check if a display point is within the cropped area
    func isInCroppedArea(_ point: CGPoint) -> Bool {
        return cropRect.contains(point)
    }

    /// Clip a rect to the cropped area
    func clipToCroppedArea(_ rect: CGRect) -> CGRect {
        return rect.intersection(cropRect)
    }
}
