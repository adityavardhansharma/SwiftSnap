import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            CaptureSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }
                .tag(1)

            ShortcutSettingsTab(settingsStore: settingsStore)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(2)
        }
        .frame(width: 480, height: 380)
        .padding(12)
        .appleLiquidGlass(cornerRadius: 24)
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Launch at startup", isOn: $settingsStore.launchAtStartup)

                Toggle("Show notification toast", isOn: $settingsStore.showNotification)

                Toggle("Play capture sound", isOn: $settingsStore.captureSound)
            }

            Section("Save Location") {
                HStack {
                    if let folder = settingsStore.saveFolderURL {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(folder.path)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No folder selected")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Choose...") {
                        chooseSaveFolder()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .scrollContentBackgroundIfAvailable()
    }

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.saveFolderURL = url
            settingsStore.clipboardOnly = false
        }
    }
}

struct CaptureSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Save Mode") {
                Picker("Mode", selection: Binding(
                    get: { settingsStore.clipboardOnly },
                    set: { settingsStore.clipboardOnly = $0 }
                )) {
                    Text("Clipboard Only").tag(true)
                    Text("Save + Clipboard").tag(false)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Image Format") {
                Picker("Format", selection: $settingsStore.imageFormat) {
                    ForEach(ImageFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Filename") {
                TextField("Format", text: $settingsStore.filenameFormat)
                    .textFieldStyle(.roundedBorder)

                Text("Available tokens: {date}, {time}")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .scrollContentBackgroundIfAvailable()
    }
}

struct ShortcutSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Global Shortcut") {
                HStack {
                    Text("Capture Screenshot")
                    Spacer()
                    HStack(spacing: 4) {
                        OnboardingKeyCap(symbol: "\u{2318}", size: .small)
                            .scaleEffect(0.75)
                        OnboardingKeyCap(symbol: "\u{21E7}", size: .small)
                            .scaleEffect(0.75)
                        OnboardingKeyCap(symbol: "S", size: .small)
                            .scaleEffect(0.75)
                    }
                }
            }

            Section {
                Text("Shortcut customization coming in a future update.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .scrollContentBackgroundIfAvailable()
    }
}

private extension View {
    @ViewBuilder
    func appleLiquidGlass(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.42), .white.opacity(0.12), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        }
    }

    @ViewBuilder
    func scrollContentBackgroundIfAvailable() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
