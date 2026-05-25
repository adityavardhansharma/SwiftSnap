import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                SettingsTab(icon: "gear", label: "General", isSelected: selectedTab == 0) {
                    withAnimation(.easeOut(duration: 0.2)) { selectedTab = 0 }
                }
                SettingsTab(icon: "camera", label: "Capture", isSelected: selectedTab == 1) {
                    withAnimation(.easeOut(duration: 0.2)) { selectedTab = 1 }
                }
                SettingsTab(icon: "command", label: "Shortcuts", isSelected: selectedTab == 2) {
                    withAnimation(.easeOut(duration: 0.2)) { selectedTab = 2 }
                }
                SettingsTab(icon: "info.circle", label: "About", isSelected: selectedTab == 3) {
                    withAnimation(.easeOut(duration: 0.2)) { selectedTab = 3 }
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ZStack {
                if selectedTab == 0 {
                    GeneralSettingsContent(settings: settings)
                        .transition(.opacity)
                }
                if selectedTab == 1 {
                    CaptureSettingsContent(settings: settings)
                        .transition(.opacity)
                }
                if selectedTab == 2 {
                    ShortcutSettingsContent()
                        .transition(.opacity)
                }
                if selectedTab == 3 {
                    AboutContent()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .frame(width: 500, height: 400)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Tab Button

struct SettingsTab: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .primary : .secondary.opacity(isHovered ? 0.8 : 0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }
}

// MARK: - Settings Row

struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    let content: () -> Content

    init(icon: String, title: String, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String?
    let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                content()
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }
}

// MARK: - General

struct GeneralSettingsContent: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            SettingsSection {
                SettingsRow(icon: "sunrise", title: "Launch at startup") {
                    Toggle("", isOn: $settings.launchAtStartup)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.launchAtStartup) { _, newValue in
                            do {
                                if newValue { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch { settings.launchAtStartup = !newValue }
                        }
                }

                Divider().padding(.horizontal, 16).opacity(0.3)

                SettingsRow(icon: "bell", title: "Show notifications") {
                    Toggle("", isOn: $settings.showNotifications)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                Divider().padding(.horizontal, 16).opacity(0.3)

                SettingsRow(icon: "speaker.wave.2", title: "Capture sound") {
                    Toggle("", isOn: $settings.playCaptureSound)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Capture

struct CaptureSettingsContent: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "Output") {
                SettingsRow(icon: "doc.on.clipboard", title: "Save mode") {
                    Picker("", selection: $settings.saveEnabled) {
                        Text("Clipboard only").tag(false)
                        Text("Save + Clipboard").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                Divider().padding(.horizontal, 16).opacity(0.3)

                SettingsRow(icon: "photo", title: "Format") {
                    Picker("", selection: $settings.imageFormat) {
                        ForEach(ImageFormat.allCases) { f in
                            Text(f.label).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }

            if settings.saveEnabled {
                SettingsSection(title: "Save Location") {
                    SettingsRow(icon: "folder", title: settings.saveFolder.lastPathComponent) {
                        Button("Change...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.saveFolder = url
                            }
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }

                    Divider().padding(.horizontal, 16).opacity(0.3)

                    SettingsRow(icon: "textformat", title: "Filename") {
                        Picker("", selection: $settings.filenameFormat) {
                            ForEach(FilenameFormat.allCases) { f in
                                Text(f.label).tag(f)
                            }
                        }
                        .frame(width: 160)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
    }
}

// MARK: - Shortcuts

struct ShortcutSettingsContent: View {
    var body: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "Global Shortcut") {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    Text("Capture screenshot")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 4) {
                        ShortcutKey(label: "⌘")
                        ShortcutKey(label: "⇧")
                        ShortcutKey(label: "S")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Spacer()
        }
    }
}

struct ShortcutKey: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(width: 26, height: 24)
            .glassEffect(.regular, in: .rect(cornerRadius: 5))
    }
}

// MARK: - About

struct AboutContent: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(.primary)
            }

            Text("SwiftSnap")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Version 1.0.0")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Text("A fast, clipboard-first screenshot\nutility for macOS.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()
        }
    }
}
