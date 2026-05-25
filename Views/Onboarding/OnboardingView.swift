import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: PermissionService
    @State private var currentPage = 0
    @State private var animateIn = false
    @State private var iconFloat = false
    @Environment(\.dismiss) private var dismiss

    private var totalPages: Int {
        permissions.hasScreenRecordingPermission ? 4 : 5
    }

    private var pageIndex: Int {
        if permissions.hasScreenRecordingPermission && currentPage >= 1 {
            return currentPage + 1
        }
        return currentPage
    }

    var body: some View {
        ZStack {
            OnboardingBackground(page: currentPage)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack {
                    if pageIndex == 0 {
                        welcomePage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    if pageIndex == 1 {
                        permissionPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    if pageIndex == 2 {
                        shortcutPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    if pageIndex == 3 {
                        saveLocationPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    if pageIndex == 4 {
                        readyPage
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 0)

                navigationBar
            }
        }
        .frame(width: 620, height: 500)
        .onAppear {
            permissions.checkPermissions()
            withAnimation(.easeOut(duration: 0.8)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                iconFloat = true
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.25))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentPage -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .transition(.opacity)
                }

                Button {
                    if currentPage == totalPages - 1 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            settings.hasCompletedOnboarding = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            dismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            currentPage += 1
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                            .font(.system(size: 13, weight: .semibold))

                        if currentPage < totalPages - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .padding(.top, 12)
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 40)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 20, y: 0)
                    .offset(y: iconFloat ? -6 : 6)
            }
            .padding(.bottom, 32)

            Text("Welcome to SwiftSnap")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)

            Text("Lightning-fast screenshots,\nbeautifully simple.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 15)

            Spacer()

            HStack(spacing: 10) {
                FeaturePill(icon: "doc.on.clipboard", text: "Clipboard-first")
                FeaturePill(icon: "bolt.fill", text: "Instant capture")
                FeaturePill(icon: "sparkles", text: "Retina quality")
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
            .padding(.bottom, 8)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Page 1: Permission

    private var permissionPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(permissions.hasScreenRecordingPermission ? Color.green.opacity(0.15) : Color.orange.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 35)

                Image(systemName: permissions.hasScreenRecordingPermission ? "checkmark.shield.fill" : "lock.shield")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(
                        permissions.hasScreenRecordingPermission
                            ? AnyShapeStyle(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    )
                    .offset(y: iconFloat ? -4 : 4)
            }
            .padding(.bottom, 28)

            Text("Screen Recording")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("SwiftSnap needs this permission to\ncapture your screen content.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer()

            VStack(spacing: 14) {
                if permissions.hasScreenRecordingPermission {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Permission Granted")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("You're all set to capture screenshots")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                } else {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.orange)

                            Text("Permission required to continue")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))

                            Spacer()
                        }

                        Button {
                            permissions.requestScreenRecordingPermission()
                        } label: {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 12))
                                Text("Grant Screen Recording Access")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor)
                            }
                        }
                        .buttonStyle(.plain)

                        Button("Open System Settings Manually") {
                            permissions.openScreenRecordingSettings()
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .frame(maxWidth: 380)

            Spacer()
        }
        .padding(.horizontal, 40)
        .onAppear {
            permissions.checkPermissions()
        }
    }

    // MARK: - Page 2: Shortcut

    private var shortcutPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 35)

                Image(systemName: "keyboard")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: iconFloat ? -4 : 4)
            }
            .padding(.bottom, 28)

            Text("Global Shortcut")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Capture from anywhere, instantly.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    KeyCap(label: "⌘", subtitle: "Cmd")

                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))

                    KeyCap(label: "⇧", subtitle: "Shift")

                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))

                    KeyCap(label: "S", subtitle: nil)
                }

                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Image(systemName: "clipboard.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Every capture is instantly copied to your clipboard")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .frame(maxWidth: 380)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Page 3: Save Location

    private var saveLocationPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 35)

                Image(systemName: "folder.fill")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: iconFloat ? -4 : 4)
            }
            .padding(.bottom, 28)

            Text("Save Preferences")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Choose how your screenshots are stored.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 10) {
                SaveOptionCard(
                    icon: "doc.on.clipboard.fill",
                    title: "Save + Clipboard",
                    subtitle: "Saves to folder and copies to clipboard",
                    isSelected: settings.saveEnabled
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        settings.saveEnabled = true
                    }
                }

                SaveOptionCard(
                    icon: "clipboard.fill",
                    title: "Clipboard Only",
                    subtitle: "Screenshots only go to your clipboard",
                    isSelected: !settings.saveEnabled
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        settings.saveEnabled = false
                    }
                }

                if settings.saveEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text(settings.saveFolder.lastPathComponent)
                            .font(.system(size: 12))
                        Button("Change") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.saveFolder = url
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: 380)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Page 4: Ready

    private var readyPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 40)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: iconFloat ? -6 : 6)
            }
            .padding(.bottom, 28)

            Text("You're all set")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("SwiftSnap is ready to capture.\nLook for the icon in your menu bar.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        KeyCapSmall(label: "⌘")
                        KeyCapSmall(label: "⇧")
                        KeyCapSmall(label: "S")
                    }
                    Text("Capture anytime")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text("Always in menu bar")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clipboard.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text("Instant clipboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .frame(maxWidth: 420)

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Components

struct OnboardingBackground: View {
    let page: Int

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1))

            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(
                    x: CGFloat(page) * -30 + 80,
                    y: CGFloat(page) * -20 - 60
                )
                .animation(.easeInOut(duration: 0.8), value: page)

            Circle()
                .fill(Color.purple.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(
                    x: CGFloat(page) * 25 - 100,
                    y: CGFloat(page) * 15 + 80
                )
                .animation(.easeInOut(duration: 0.8), value: page)

            Rectangle()
                .fill(.white.opacity(0.012))
        }
        .ignoresSafeArea()
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

struct KeyCap: View {
    let label: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: 56, height: 52)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

struct KeyCapSmall: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 28, height: 26)
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
    }
}

struct SaveOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : .white.opacity(0.04))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundStyle(isSelected ? Color.accentColor : .white.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(.white.opacity(isSelected ? 0 : 0.15), lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(isSelected ? 0.06 : (isHovered ? 0.04 : 0.02)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.3) : .white.opacity(0.08),
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
