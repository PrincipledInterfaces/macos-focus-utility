import SwiftUI

enum TOMEEnvironment: String, CaseIterable, Identifiable, Codable {
    case home = "home"
    case planning = "planning"
    case writerDesk = "writer_desk"
    case workshop = "workshop"
    case coffeeshop = "coffeeshop"
    case garden = "garden"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .home:
            return "Home"
        case .planning:
            return "Planning"
        case .writerDesk:
            return "Writer's Desk"
        case .workshop:
            return "Workshop"
        case .coffeeshop:
            return "Coffeeshop"
        case .garden:
            return "Garden"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .home:
            return .white
        case .planning:
            return .blue
        case .writerDesk:
            return .green
        case .workshop:
            return .purple
        case .coffeeshop:
            return .orange
        case .garden:
            return .green
        }
    }

    var primaryColor: Color {
        return accentColor
    }
    
    var icon: String {
        switch self {
        case .home:
            return "house"
        case .planning:
            return "list.bullet.clipboard"
        case .writerDesk:
            return "doc.text"
        case .workshop:
            return "hammer"
        case .coffeeshop:
            return "cup.and.saucer"
        case .garden:
            return "leaf"
        }
    }
    
    var description: String {
        switch self {
        case .home:
            return "Task selection and overview"
        case .planning:
            return "Focus planning and AI assistance"
        case .writerDesk:
            return "Communication and writing"
        case .workshop:
            return "Development and creation"
        case .coffeeshop:
            return "Research and exploration"
        case .garden:
            return "Rest and reflection"
        }
    }
}