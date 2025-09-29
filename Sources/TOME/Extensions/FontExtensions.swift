import SwiftUI

extension Font {
    /// Standard TOME font styles using Helvetica Neue
    static func tomeTitle() -> Font {
        return .custom("Helvetica Neue", size: 32).weight(.bold)
    }
    
    static func tomeHeading() -> Font {
        return .custom("Helvetica Neue", size: 24).weight(.semibold)
    }
    
    static func tomeSubheading() -> Font {
        return .custom("Helvetica Neue", size: 20).weight(.medium)
    }
    
    static func tomeBody() -> Font {
        return .custom("Helvetica Neue", size: 16)
    }
    
    static func tomeBodyMedium() -> Font {
        return .custom("Helvetica Neue", size: 16).weight(.medium)
    }
    
    static func tomeSmall() -> Font {
        return .custom("Helvetica Neue", size: 14)
    }
    
    static func tomeSmallMedium() -> Font {
        return .custom("Helvetica Neue", size: 14).weight(.medium)
    }
    
    static func tomeCaption() -> Font {
        return .custom("Helvetica Neue", size: 12)
    }
    
    static func tomeCaptionMedium() -> Font {
        return .custom("Helvetica Neue", size: 12).weight(.medium)
    }
    
    static func tomeLabel() -> Font {
        return .custom("Helvetica Neue", size: 11)
    }
    
    static func tomeLabelMedium() -> Font {
        return .custom("Helvetica Neue", size: 11).weight(.medium)
    }
    
    static func tomeSmallLabel() -> Font {
        return .custom("Helvetica Neue", size: 10)
    }
    
    static func tomeSmallLabelMedium() -> Font {
        return .custom("Helvetica Neue", size: 10).weight(.medium)
    }
    
    static func tomeTiny() -> Font {
        return .custom("Helvetica Neue", size: 9)
    }
    
    static func tomeTinyMedium() -> Font {
        return .custom("Helvetica Neue", size: 9).weight(.medium)
    }
}