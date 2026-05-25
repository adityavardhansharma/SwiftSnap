import SwiftUI

struct CaptureToolbarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CaptureMode.allCases) { mode in
                ToolbarButton(
                    icon: mode.icon,
                    label: mode.label,
                    isSelected: appState.captureMode == mode
                ) {
                    appState.switchMode(mode)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 28)
                .padding(.horizontal, 6)

            ToolbarButton(icon: "xmark", label: "Cancel", isSelected: false) {
                appState.cancelCapture()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary.opacity(isHovered ? 0.9 : 0.6))

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary.opacity(isHovered ? 0.7 : 0.4))
            }
            .frame(width: 64, height: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.12))
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(isHovered && !isSelected ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
