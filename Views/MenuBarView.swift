import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var recentCaptures: RecentCapturesManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                MenuActionButton(icon: "crop", label: "Capture Area", shortcut: "⌘⇧S") {
                    appState.startCapture(mode: .area)
                }

                MenuActionButton(icon: "macwindow", label: "Capture Window", shortcut: nil) {
                    appState.startCapture(mode: .window)
                }

                MenuActionButton(icon: "display", label: "Capture Full Screen", shortcut: nil) {
                    appState.startCapture(mode: .fullScreen)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            if !recentCaptures.captures.isEmpty {
                Divider()
                    .padding(.vertical, 6)

                Text("RECENT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)

                ForEach(recentCaptures.captures) { capture in
                    RecentCaptureRow(capture: capture) {
                        recentCaptures.copyAgain(capture)
                    } onReveal: {
                        recentCaptures.revealInFinder(capture)
                    }
                }
                .padding(.horizontal, 6)
            }

            Divider()
                .padding(.vertical, 6)

            VStack(spacing: 2) {
                MenuActionButton(icon: "gear", label: "Settings...", shortcut: "⌘,") {
                    appState.showSettings = true
                    NSApp.activate(ignoringOtherApps: true)
                }

                MenuActionButton(icon: "power", label: "Quit SwiftSnap", shortcut: "⌘Q") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 260)
    }
}

struct MenuActionButton: View {
    let icon: String
    let label: String
    let shortcut: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? .primary : .secondary)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13))

                Spacer()

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? .white.opacity(0.1) : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

struct RecentCaptureRow: View {
    let capture: CaptureResult
    let onCopy: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: capture.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(capture.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(timeAgo)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 3) {
                    MiniButton(icon: "doc.on.clipboard", tooltip: "Copy") { onCopy() }

                    if capture.savedURL != nil {
                        MiniButton(icon: "folder", tooltip: "Reveal") { onReveal() }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? .white.opacity(0.08) : .clear)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(capture.timestamp)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: capture.timestamp)
    }
}

struct MiniButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.white.opacity(isHovered ? 0.15 : 0.08))
                }
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
