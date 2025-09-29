import SwiftUI

struct ThreePaneLayout: View {
    let currentEnvironment: TOMEEnvironment
    @ObservedObject var tomeState: TOMEState
    @Binding var selectedLeftApp: String?
    @Binding var selectedRightApp: String?
    let onNavigateHome: () -> Void
    
    @StateObject private var appDetectionService = AppDetectionService()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Pane - Application Launcher (25%)
                leftPane
                    .frame(width: geometry.size.width * 0.25)
                
                // Thin divider
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 1)
                
                // Center Pane - Main Environment Content (50%)
                centerPane
                    .frame(width: geometry.size.width * 0.5)
                
                // Thin divider
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 1)
                
                // Right Pane - Controls & Tools (25%)
                rightPane
                    .frame(width: geometry.size.width * 0.25)
            }
        }
        .background(Color.black)
    }
    
    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Left pane header
            HStack {
                Text("Apps")
                    .font(.tomeBody())
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if selectedLeftApp != nil {
                    Button("×") {
                        selectedLeftApp = nil
                    }
                    .font(.tomeCaption())
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            if let selectedApp = selectedLeftApp,
               let app = environmentApps.first(where: { $0.name == selectedApp }) {
                // Show embedded app
                SimpleAppEmbedView(appName: app.name, bundleId: app.bundleId)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show app launcher
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(environmentApps, id: \.name) { app in
                            AppLaunchButton(
                                app: app,
                                appIcon: appDetectionService.getAppIcon(for: app.bundleId),
                                isSelected: selectedLeftApp == app.name,
                                onTap: { selectApp(app) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.black)
    }
    
    private var centerPane: some View {
        VStack(spacing: 0) {
            // Environment-specific content (embedded views without navigation overlays)
            switch currentEnvironment {
            case .planning:
                EmbeddedPlanningView(currentState: tomeState)
            case .writerDesk:
                EmbeddedWriterDeskView(currentState: tomeState)
            case .workshop:
                EmbeddedWorkshopView(currentState: tomeState)
            case .coffeeshop:
                EmbeddedCoffeeshopView(currentState: tomeState)
            case .garden:
                EmbeddedGardenView(currentState: tomeState)
            case .home:
                EmptyView()
            }
        }
        .background(Color.black)
    }
    
    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Right pane header
            Text("Tools")
                .font(.tomeBody())
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Environment controls
                    environmentControls
                    
                    // Notification summary
                    notificationSummary
                    
                    // Quick actions
                    quickActions
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color.black)
    }
    
    private var environmentControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigation")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 8) {
                Button(action: onNavigateHome) {
                    HStack(spacing: 8) {
                        Image(systemName: "house")
                            .font(.system(size: 12, weight: .regular))
                        Text("Home")
                            .font(.tomeCaption())
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                HStack {
                    Text("Current:")
                        .font(.tomeTiny())
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(currentEnvironment.displayName)
                        .font(.tomeTinyMedium())
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var notificationSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))
            
            Text("Focus mode active")
                .font(.tomeSmallLabel())
                .foregroundColor(.white.opacity(0.6))
            
            Text("\(tomeState.todos.filter { !$0.isCompleted }.count) active todos")
                .font(.tomeSmallLabel())
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.tomeCaption())
                .foregroundColor(.white.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 4) {
                Button("Add Todo") {
                    // TODO: Add quick todo functionality
                }
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(PlainButtonStyle())
                
                Button("Break Timer") {
                    // TODO: Start break timer
                }
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.6))
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var environmentApps: [AppInfo] {
        let apps = appDetectionService.getAppsForEnvironment(currentEnvironment)
        print("📱 Using AI-categorized apps for \(currentEnvironment.displayName): \(apps.count) apps")
        return apps
    }
    
    private func selectApp(_ app: AppInfo) {
        selectedLeftApp = app.name
        print("Selected app for embedding: \(app.name)")
    }
}

struct AppLaunchButton: View {
    let app: AppInfo
    let appIcon: NSImage?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "app.badge")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(app.name)
                    .font(.tomeSmallLabel())
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppInfo {
    let name: String
    let bundleId: String
    let icon: String
}