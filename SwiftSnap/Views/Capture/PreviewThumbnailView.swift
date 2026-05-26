import SwiftUI

struct PreviewThumbnailView: View {
    @ObservedObject var captureService: CaptureService
    let result: CaptureResult
    let onDismiss: () -> Void

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Action buttons
            HStack(spacing: 4) {
                ActionButton(icon: "square.and.arrow.down", label: "Save As") {
                    captureService.saveAs()
                }

                ActionButton(icon: "pencil", label: "Rename") {
                    renameText = result.displayName
                    isRenaming = true
                }

                ActionButton(icon: "trash", label: "Delete") {
                    captureService.deleteFile()
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Thumbnail
            Image(nsImage: result.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 256, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            // Rename field
            if isRenaming {
                HStack(spacing: 6) {
                    TextField("Filename", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))
                        .onSubmit {
                            captureService.rename(newName: renameText)
                            isRenaming = false
                        }

                    Button("Done") {
                        captureService.rename(newName: renameText)
                        isRenaming = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassBackground(cornerRadius: 14)
        .frame(width: 280)
        .animation(.easeInOut(duration: 0.2), value: isRenaming)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if isHovered {
                    Capsule().fill(.white.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
