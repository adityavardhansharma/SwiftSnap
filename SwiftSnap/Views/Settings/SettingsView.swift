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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .scrollContentBackground(.hidden)
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
        .scrollContentBackground(.hidden)
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
        .scrollContentBackground(.hidden)
    }
}
