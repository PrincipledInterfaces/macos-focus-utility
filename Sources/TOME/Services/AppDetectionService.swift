import Foundation
import AppKit
import Combine

class AppDetectionService: ObservableObject {
    @Published var installedApps: [InstalledApp] = []
    @Published var categorizedApps: [TOMEEnvironment: [AppInfo]] = [:]
    
    private let openAIService: OpenAIService
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.openAIService = OpenAIService()
        scanInstalledApps()
    }
    
    func scanInstalledApps() {
        print("🔍 Scanning installed applications...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var apps: [InstalledApp] = []
            
            // Get all running applications first
            let runningApps = NSWorkspace.shared.runningApplications
            for runningApp in runningApps {
                if let bundleId = runningApp.bundleIdentifier,
                   let localizedName = runningApp.localizedName,
                   runningApp.activationPolicy == .regular {
                    
                    let icon = runningApp.icon
                    apps.append(InstalledApp(
                        name: localizedName,
                        bundleIdentifier: bundleId,
                        icon: icon
                    ))
                }
            }
            
            // Scan /Applications directory
            let applicationsURL = URL(fileURLWithPath: "/Applications")
            if let appURLs = try? FileManager.default.contentsOfDirectory(
                at: applicationsURL,
                includingPropertiesForKeys: [.nameKey],
                options: [.skipsHiddenFiles]
            ) {
                for appURL in appURLs {
                    if appURL.pathExtension == "app" {
                        if let bundle = Bundle(url: appURL),
                           let bundleId = bundle.bundleIdentifier,
                           let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                                      bundle.infoDictionary?["CFBundleName"] as? String {
                            
                            // Avoid duplicates
                            if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                                apps.append(InstalledApp(
                                    name: appName,
                                    bundleIdentifier: bundleId,
                                    icon: icon
                                ))
                            }
                        }
                    }
                }
            }
            
            // Scan ~/Applications directory
            let userAppsURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
            if let userAppURLs = try? FileManager.default.contentsOfDirectory(
                at: userAppsURL,
                includingPropertiesForKeys: [.nameKey],
                options: [.skipsHiddenFiles]
            ) {
                for appURL in userAppURLs {
                    if appURL.pathExtension == "app" {
                        if let bundle = Bundle(url: appURL),
                           let bundleId = bundle.bundleIdentifier,
                           let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                                      bundle.infoDictionary?["CFBundleName"] as? String {
                            
                            // Avoid duplicates
                            if !apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                                apps.append(InstalledApp(
                                    name: appName,
                                    bundleIdentifier: bundleId,
                                    icon: icon
                                ))
                            }
                        }
                    }
                }
            }
            
            print("🎯 Found \(apps.count) installed applications")
            
            DispatchQueue.main.async {
                self.installedApps = apps
                self.categorizeAppsForAllEnvironments()
            }
        }
    }
    
    private func categorizeAppsForAllEnvironments() {
        let environments: [TOMEEnvironment] = [.planning, .writerDesk, .workshop, .coffeeshop, .garden]
        
        for environment in environments {
            categorizeAppsForEnvironment(environment)
        }
    }
    
    private func categorizeAppsForEnvironment(_ environment: TOMEEnvironment) {
        print("🧠 AI categorizing apps for \(environment.displayName)...")
        
        openAIService.categorizeInstalledAppsForEnvironment(
            environment: environment.displayName,
            installedApps: installedApps
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let apps):
                    // Add proper icons to the categorized apps
                    let appsWithIcons = apps.map { appInfo in
                        let installedApp = self?.installedApps.first { $0.name == appInfo.name }
                        return AppInfo(
                            name: appInfo.name,
                            bundleId: appInfo.bundleId,
                            icon: installedApp?.icon != nil ? "app" : "❓"
                        )
                    }
                    
                    self?.categorizedApps[environment] = appsWithIcons
                    print("✅ Categorized \(appsWithIcons.count) apps for \(environment.displayName)")
                    
                case .failure(let error):
                    print("❌ Failed to categorize apps for \(environment.displayName): \(error)")
                    // Fallback to manual selection based on common patterns
                    self?.fallbackCategorization(for: environment)
                }
            }
        }
    }
    
    private func fallbackCategorization(for environment: TOMEEnvironment) {
        let fallbackApps: [AppInfo]
        
        switch environment {
        case .planning:
            fallbackApps = installedApps.filter { app in
                let name = app.name.lowercased()
                return name.contains("note") || name.contains("calendar") || 
                       name.contains("remind") || name.contains("plan") ||
                       name.contains("todo") || name.contains("task")
            }.prefix(6).map { AppInfo(name: $0.name, bundleId: $0.bundleIdentifier ?? "", icon: "app") }
            
        case .writerDesk:
            fallbackApps = installedApps.filter { app in
                let name = app.name.lowercased()
                return name.contains("write") || name.contains("document") ||
                       name.contains("text") || name.contains("word") ||
                       name.contains("mail") || name.contains("message")
            }.prefix(6).map { AppInfo(name: $0.name, bundleId: $0.bundleIdentifier ?? "", icon: "app") }
            
        case .workshop:
            fallbackApps = installedApps.filter { app in
                let name = app.name.lowercased()
                return name.contains("xcode") || name.contains("code") ||
                       name.contains("terminal") || name.contains("git") ||
                       name.contains("develop") || name.contains("build")
            }.prefix(6).map { AppInfo(name: $0.name, bundleId: $0.bundleIdentifier ?? "", icon: "app") }
            
        case .coffeeshop:
            fallbackApps = installedApps.filter { app in
                let name = app.name.lowercased()
                return name.contains("figma") || name.contains("sketch") ||
                       name.contains("photo") || name.contains("design") ||
                       name.contains("creative") || name.contains("browser")
            }.prefix(6).map { AppInfo(name: $0.name, bundleId: $0.bundleIdentifier ?? "", icon: "app") }
            
        case .garden:
            fallbackApps = installedApps.filter { app in
                let name = app.name.lowercased()
                return name.contains("music") || name.contains("spotify") ||
                       name.contains("calm") || name.contains("meditation") ||
                       name.contains("relax") || name.contains("podcast")
            }.prefix(6).map { AppInfo(name: $0.name, bundleId: $0.bundleIdentifier ?? "", icon: "app") }
            
        case .home:
            fallbackApps = []
        }
        
        categorizedApps[environment] = Array(fallbackApps)
        print("🔄 Used fallback categorization for \(environment.displayName): \(fallbackApps.count) apps")
    }
    
    func getAppsForEnvironment(_ environment: TOMEEnvironment) -> [AppInfo] {
        return categorizedApps[environment] ?? []
    }
    
    func getAppIcon(for bundleId: String) -> NSImage? {
        return installedApps.first { $0.bundleIdentifier == bundleId }?.icon
    }
    
    func refreshAppDetection() {
        scanInstalledApps()
    }
}