import SwiftUI
import AppKit

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var permissionService: PermissionService
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var slideDirection: Edge = .trailing
    @State private var animateOrbs = false
    @State private var permissionTimer: Timer?
    @State private var didRestorePage = false

    private let totalPages = 8

    var body: some View {
        ZStack {
            orbLayer
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: finishOnboarding) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.top, 14)
                .padding(.trailing, 16)

                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: screenRecordingPage
                    case 2: accessibilityPage
                    case 3: shortcutPage
                    case 4: clipboardPage
                    case 5: saveFolderPage
                    case 6: startupPage
                    case 7: readyPage
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection).combined(with: .opacity),
                    removal: .move(edge: slideDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                ))
                .id(currentPage)

                navigationBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 26)
            }
        }
        .frame(width: 640, height: 500)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            permissionService.checkAllPermissions()

            // Restore saved progress (survives app restart for permission grants)
            let saved = UserDefaults.standard.integer(forKey: "onboardingPage")
            if saved > 0 && saved < totalPages {
                currentPage = saved
            }
            didRestorePage = true

            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateOrbs = true
            }
        }
        .onDisappear {
            stopPermissionPolling()
        }
        .onChange(of: currentPage) { _, newPage in
            UserDefaults.standard.set(newPage, forKey: "onboardingPage")

            if newPage == 1 || newPage == 2 {
                startPermissionPolling()
            } else {
                stopPermissionPolling()
            }
        }
    }

    // MARK: - Animated Orbs

    @ViewBuilder
    private var orbLayer: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color.blue.opacity(0.07), Color.clear],
                    center: .center, startRadius: 0, endRadius: 110
                ))
                .frame(width: 220, height: 220)
                .offset(x: animateOrbs ? 50 : -50, y: animateOrbs ? -40 : 40)
                .blur(radius: 30)

            Circle()
                .fill(RadialGradient(
                    colors: [Color.purple.opacity(0.05), Color.clear],
                    center: .center, startRadius: 0, endRadius: 80
                ))
                .frame(width: 160, height: 160)
                .offset(x: animateOrbs ? -60 : 60, y: animateOrbs ? 50 : -50)
                .blur(radius: 25)

            Circle()
                .fill(RadialGradient(
                    colors: [Color.cyan.opacity(0.04), Color.clear],
                    center: .center, startRadius: 0, endRadius: 60
                ))
                .frame(width: 120, height: 120)
                .offset(x: animateOrbs ? 80 : -20, y: animateOrbs ? 20 : -60)
                .blur(radius: 20)
        }
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.blue.opacity(0.18), Color.clear],
                        center: .center, startRadius: 0, endRadius: 70
                    ))
                    .frame(width: 140, height: 140)
                    .blur(radius: 8)

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            }
            .padding(.bottom, 28)

            Text("Welcome to SwiftSnap")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.bottom, 6)

            Text("The premium screenshot experience for macOS")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.bottom, 36)

            VStack(spacing: 16) {
                OnboardingFeatureRow(icon: "bolt.fill", color: .yellow, text: "Lightning-fast capture")
                OnboardingFeatureRow(icon: "doc.on.clipboard.fill", color: .green, text: "Clipboard-first workflow")
                OnboardingFeatureRow(icon: "sparkles", color: .blue, text: "Beautiful native experience")
            }
            .padding(.horizontal, 80)

            Spacer()
        }
    }

    // MARK: - Page 1: Screen Recording

    private var screenRecordingPage: some View {
        PermissionPageContent(
            icon: "rectangle.dashed.badge.record",
            grantedIcon: "checkmark.shield.fill",
            color: .red,
            title: "Screen Recording",
            description: "SwiftSnap needs permission to capture\nyour screen content.",
            isGranted: permissionService.screenRecordingGranted,
            actionLabel: "Grant Access",
            hint: "If macOS asks to restart, your progress here is saved.",
            action: { permissionService.requestScreenRecording() },
            refreshAction: { permissionService.checkScreenRecording() }
        )
    }

    // MARK: - Page 2: Accessibility

    private var accessibilityPage: some View {
        PermissionPageContent(
            icon: "hand.raised.fill",
            grantedIcon: "checkmark.shield.fill",
            color: .blue,
            title: "Accessibility",
            description: "Enables the global keyboard shortcut\nand window detection.",
            isGranted: permissionService.accessibilityGranted,
            actionLabel: "Grant Access",
            hint: "A system dialog will appear. Click \"Open System Settings\" to enable.",
            action: { permissionService.requestAccessibility() },
            refreshAction: { permissionService.checkAccessibility() }
        )
    }

    // MARK: - Page 3: Shortcut

    private var shortcutPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.orange)
                .padding(.bottom, 28)

            Text("Your Shortcut")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("Press anytime to start capturing")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            HStack(spacing: 10) {
                OnboardingKeyCap(symbol: "\u{2318}", size: .large)
                OnboardingKeyCap(symbol: "\u{21E7}", size: .large)
                OnboardingKeyCap(symbol: "S", size: .large)
            }
            .padding(.bottom, 16)

            Text("Works globally from anywhere on your Mac")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    // MARK: - Page 4: Clipboard First

    private var clipboardPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.green)
                .padding(.bottom, 28)

            Text("Clipboard First")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("Every screenshot is instantly copied to your clipboard.\nJust paste anywhere.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 36)

            HStack(spacing: 0) {
                OnboardingWorkflowStep(label: "Capture", icon: "camera.viewfinder")
                OnboardingWorkflowArrow()
                OnboardingWorkflowStep(label: "Clipboard", icon: "doc.on.clipboard")
                OnboardingWorkflowArrow()
                OnboardingWorkflowStep(label: "Paste", icon: "doc.on.doc")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Page 5: Save Folder

    private var saveFolderPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "folder.fill")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.blue)
                .padding(.bottom, 28)

            Text("Save Location")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("Choose where to save screenshots,\nor use clipboard-only mode.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 28)

            VStack(spacing: 14) {
                if let folder = settingsStore.saveFolderURL {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 14))
                        Text(folder.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.green.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.green.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 60)
                }

                Button(action: chooseSaveFolder) {
                    Label(
                        settingsStore.saveFolderURL == nil ? "Choose Folder" : "Change Folder",
                        systemImage: "folder.badge.plus"
                    )
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .tint(.blue)

                Button(action: { settingsStore.clipboardOnly.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: settingsStore.clipboardOnly ? "checkmark.square.fill" : "square")
                            .foregroundStyle(settingsStore.clipboardOnly ? .blue : .secondary)
                            .font(.system(size: 14))
                        Text("Clipboard only — don't save files")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    // MARK: - Page 6: Launch at Startup

    private var startupPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "sunrise.fill")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.orange)
                .padding(.bottom, 28)

            Text("Launch at Startup")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("Have SwiftSnap ready whenever you need it")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            Toggle(isOn: $settingsStore.launchAtStartup) {
                Text("Open SwiftSnap when you log in")
                    .font(.system(size: 14, weight: .medium))
            }
            .toggleStyle(.switch)
            .tint(.blue)
            .padding(.horizontal, 100)

            Spacer()
        }
    }

    // MARK: - Page 7: Ready

    private var readyPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.green.opacity(0.15), Color.clear],
                        center: .center, startRadius: 0, endRadius: 60
                    ))
                    .frame(width: 120, height: 120)
                    .blur(radius: 6)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.25), radius: 10)
            }
            .padding(.bottom, 28)

            Text("You're All Set")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.bottom, 8)

            Text("SwiftSnap is running in your menu bar.\nCapture anytime with:")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 24)

            HStack(spacing: 8) {
                OnboardingKeyCap(symbol: "\u{2318}", size: .small)
                OnboardingKeyCap(symbol: "\u{21E7}", size: .small)
                OnboardingKeyCap(symbol: "S", size: .small)
            }

            Spacer()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            HStack(spacing: 7) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.15))
                        .frame(width: index == currentPage ? 7 : 6, height: index == currentPage ? 7 : 6)
                        .animation(.easeOut(duration: 0.2), value: currentPage)
                }
            }

            Spacer()

            HStack(spacing: 14) {
                if currentPage > 0 {
                    Button("Back") {
                        goBack()
                    }
                    .buttonStyle(.glass)
                    .font(.system(size: 13, weight: .medium))
                }

                Button(action: goForward) {
                    Text(currentPage == totalPages - 1 ? "Start Capturing" : "Continue")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
            }
        }
    }

    // MARK: - Navigation

    private func goForward() {
        if currentPage == totalPages - 1 {
            finishOnboarding()
        } else {
            slideDirection = .trailing
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                currentPage += 1
            }
        }
    }

    private func goBack() {
        slideDirection = .leading
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
            currentPage -= 1
        }
    }

    private func finishOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboardingPage")
        settingsStore.hasCompletedOnboarding = true
        onComplete()
    }

    // MARK: - Permission Polling

    private func startPermissionPolling() {
        stopPermissionPolling()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            DispatchQueue.main.async {
                permissionService.checkAllPermissions()
            }
        }
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: - Helpers

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.saveFolderURL = url
            settingsStore.clipboardOnly = false
        }
    }
}


// MARK: - Permission Page Content

struct PermissionPageContent: View {
    let icon: String
    let grantedIcon: String
    let color: Color
    let title: String
    let description: String
    let isGranted: Bool
    let actionLabel: String
    let hint: String
    let action: () -> Void
    let refreshAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [(isGranted ? Color.green : color).opacity(0.12), Color.clear],
                        center: .center, startRadius: 0, endRadius: 50
                    ))
                    .frame(width: 100, height: 100)

                Image(systemName: isGranted ? grantedIcon : icon)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(isGranted ? .green : color)
            }
            .animation(.spring(response: 0.5), value: isGranted)
            .padding(.bottom, 24)

            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .padding(.bottom, 10)

            if isGranted {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                Button(action: action) {
                    Label(actionLabel, systemImage: "lock.open")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(color)
                .padding(.bottom, 10)

                Button(action: refreshAction) {
                    Label("Check again", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.glass)
                .padding(.bottom, 10)

                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Spacer()
        }
        .animation(.spring(response: 0.4), value: isGranted)
    }
}

// MARK: - Feature Row

struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .glassEffect(.regular.tint(color.opacity(0.15)), in: Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Key Cap

enum KeyCapSize {
    case small, large

    var dimension: CGFloat {
        switch self {
        case .small: return 38
        case .large: return 48
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small: return 15
        case .large: return 19
        }
    }
}

struct OnboardingKeyCap: View {
    let symbol: String
    let size: KeyCapSize

    var body: some View {
        Text(symbol)
            .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
            .frame(width: size.dimension, height: size.dimension)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Workflow Visualization

struct OnboardingWorkflowStep: View {
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .glassEffect(.regular.tint(.blue.opacity(0.1)), in: Circle())

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingWorkflowArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.quaternary)
            .frame(width: 20)
    }
}
