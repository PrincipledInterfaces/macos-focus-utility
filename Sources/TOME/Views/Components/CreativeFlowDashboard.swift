import SwiftUI

@available(macOS 12.3, *)
struct CreativeFlowDashboard: View {
    @ObservedObject var screenCaptureService: ScreenCaptureService
    @State private var showPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if screenCaptureService.hasScreenRecordingPermission {
                activeContent
            } else {
                permissionRequiredView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.8))
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .alert("Screen Recording Permission Required", isPresented: $showPermissionAlert) {
            Button("Grant Permission") {
                screenCaptureService.promptForScreenRecordingPermission()
                // After prompting, enable screen capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    screenCaptureService.enableScreenCapture()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("TOME needs screen recording permission to monitor your creative work and provide flow insights.")
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Creative Flow")
                    .font(.tomeHeading())
                    .foregroundColor(.white)
                
                Text("AI-powered work insights")
                    .font(.tomeCaption())
                    .foregroundColor(.purple.opacity(0.8))
            }
            
            Spacer()
            
            statusIndicator
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(screenCaptureService.isCapturing ? .green : .orange)
                .frame(width: 8, height: 8)
            
            Text(screenCaptureService.isCapturing ? "Monitoring" : "Idle")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.white.opacity(0.05))
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var activeContent: some View {
        VStack(spacing: 16) {
            // Current activity overview
            currentActivitySection
            
            // Focus metrics
            focusMetricsSection
            
            // Active creative apps
            if !screenCaptureService.activeCreativeApps.isEmpty {
                activeAppsSection
            }
            
            // Flow insights
            flowInsightsSection
        }
    }
    
    private var currentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Activity")
                .font(.tomeBodyMedium())
                .foregroundColor(.white.opacity(0.8))
            
            HStack {
                activityLevelIndicator
                Spacer()
                sessionTimeIndicator
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var activityLevelIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(screenCaptureService.screenActivityLevel.color.toColor())
                .frame(width: 12, height: 12)
            
            Text(screenCaptureService.screenActivityLevel.displayName)
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var sessionTimeIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text(formatDuration(screenCaptureService.focusMetrics.totalTime))
                .font(.tomeSmallMedium())
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var focusMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Metrics")
                .font(.tomeBodyMedium())
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 20) {
                focusScoreCard
                productivityTrendCard
                creativeTimeCard
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var focusScoreCard: some View {
        VStack(spacing: 4) {
            Text("\(Int(screenCaptureService.focusMetrics.focusScore))%")
                .font(.tomeSubheading())
                .foregroundColor(focusScoreColor)
            
            Text("Focus Score")
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var productivityTrendCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text("\(Int(screenCaptureService.focusMetrics.productivityTrend))%")
                    .font(.tomeBodyMedium())
                    .foregroundColor(trendColor)
                
                Image(systemName: trendIcon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(trendColor)
            }
            
            Text("Productivity")
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var creativeTimeCard: some View {
        VStack(spacing: 4) {
            Text(formatDuration(screenCaptureService.focusMetrics.creativeTime))
                .font(.tomeBodyMedium())
                .foregroundColor(.purple)
            
            Text("Creative Time")
                .font(.tomeTiny())
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var activeAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Creative Apps")
                    .font(.tomeBodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(screenCaptureService.activeCreativeApps.filter { $0.isActive }.count)")
                    .font(.tomeSmall())
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.purple.opacity(0.1))
                    )
            }
            
            LazyVStack(spacing: 8) {
                ForEach(screenCaptureService.activeCreativeApps.filter { $0.isActive }, id: \.bundleId) { session in
                    creativeAppCard(session)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func creativeAppCard(_ session: CreativeAppSession) -> some View {
        HStack(spacing: 12) {
            // App icon placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(session.activityLevel.color.toColor().opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(session.appName.prefix(1)))
                        .font(.tomeSmallMedium())
                        .foregroundColor(session.activityLevel.color.toColor())
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.appName)
                    .font(.tomeSmallMedium())
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Active for \(formatDuration(session.totalDuration))")
                    .font(.tomeTiny())
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Circle()
                .fill(session.isActive ? .green : .gray)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.02))
        )
    }
    
    private var flowInsightsSection: some View {
        let insights = screenCaptureService.getCreativeFlowInsights()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Flow Insights")
                .font(.tomeBodyMedium())
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 8) {
                flowStateIndicator(insights.flowStateDetected)
                contextSwitchesIndicator(insights.contextSwitches)
                
                if !insights.deepWorkPeriods.isEmpty {
                    deepWorkIndicator(insights.deepWorkPeriods.count)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func flowStateIndicator(_ isInFlow: Bool) -> some View {
        HStack {
            Image(systemName: isInFlow ? "brain.head.profile.fill" : "brain.head.profile")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isInFlow ? .green : .white.opacity(0.4))
            
            Text(isInFlow ? "Flow state detected" : "No flow state")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            if isInFlow {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private func contextSwitchesIndicator(_ switches: Int) -> some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(switches > 5 ? .orange : .white.opacity(0.4))
            
            Text("\(switches) context switches this hour")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            if switches > 5 {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private func deepWorkIndicator(_ periods: Int) -> some View {
        HStack {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            
            Text("\(periods) deep work periods")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
        }
    }
    
    private var permissionRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.orange.opacity(0.6))
            
            Text("Screen Recording Permission Required")
                .font(.tomeSubheading())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("To monitor your creative work and provide flow insights, TOME needs permission to record your screen. This data stays on your device and is used only for productivity analysis.")
                .font(.tomeSmall())
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button("Grant Permission") {
                screenCaptureService.promptForScreenRecordingPermission()
                // After prompting, enable screen capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    screenCaptureService.enableScreenCapture()
                }
            }
            .font(.tomeBodyMedium())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.2))
                    .stroke(.orange.opacity(0.4), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
        }
        .padding(32)
    }
    
    // MARK: - Helper Properties
    
    private var focusScoreColor: Color {
        let score = screenCaptureService.focusMetrics.focusScore
        if score >= 80 {
            return .green
        } else if score >= 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var trendColor: Color {
        let trend = screenCaptureService.focusMetrics.productivityTrend
        if trend >= screenCaptureService.focusMetrics.focusScore {
            return .green
        } else {
            return .red
        }
    }
    
    private var trendIcon: String {
        let trend = screenCaptureService.focusMetrics.productivityTrend
        if trend >= screenCaptureService.focusMetrics.focusScore {
            return "arrow.up.right"
        } else {
            return "arrow.down.right"
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Extensions

extension NSColor {
    func toColor() -> Color {
        return Color(self)
    }
}