import SwiftUI

struct PreviewThumbnailView: View {
    let result: CaptureResult
    let onSaveAs: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            if isHovered {
                HStack(spacing: 12) {
                    CircularGlassButton(icon: "square.and.arrow.down", tooltip: "Save As") {
                        onSaveAs()
                    }

                    CircularGlassButton(icon: "pencil", tooltip: "Rename") {
                        onRename()
                    }

                    CircularGlassButton(icon: "trash", tooltip: "Delete", isDestructive: true) {
                        onDelete()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.85)))
                .padding(.bottom, 8)
            }

            Button {
                if let url = result.savedURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(nsImage: result.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                Image(systemName: result.mode.icon)
                    .font(.system(size: 9))

                Text(result.mode.label)
                    .font(.system(size: 10, weight: .medium))

                Text("·")
                    .foregroundStyle(.secondary)

                Text(timeString)
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: result.timestamp)
    }
}

struct CircularGlassButton: View {
    let icon: String
    let tooltip: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    isDestructive && isHovered ? .red : .primary
                )
                .frame(width: 36, height: 36)
                .glassEffect(
                    Glass.regular.interactive(),
                    in: .circle
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
