import SwiftUI

struct CaptureToolbarView: View {
    @ObservedObject var captureService: CaptureService

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CaptureMode.allCases) { mode in
                ToolbarButton(
                    mode: mode,
                    isSelected: captureService.selectedMode == mode
                ) {
                    captureService.selectMode(mode)
                }
            }

            Divider()
                .frame(height: 28)
                .padding(.horizontal, 6)

            Button(action: { captureService.cancelCapture() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBackground()
    }
}

struct ToolbarButton: View {
    let mode: CaptureMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                Text(mode.rawValue)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(width: 64, height: 44)
            .background {
                if isSelected || isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(isSelected ? 0.15 : 0.08))
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

// MARK: - Shared Glass Background Modifier

extension View {
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background {
            NativeGlassView(cornerRadius: cornerRadius)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.08), .white.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Native Glass NSView

struct NativeGlassView: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true

        // Top edge specular highlight — simulates light catching the glass rim
        let specularLayer = CAGradientLayer()
        specularLayer.colors = [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0.06).cgColor,
            NSColor.clear.cgColor
        ]
        specularLayer.locations = [0, 0.3, 1]
        specularLayer.startPoint = CGPoint(x: 0.5, y: 0)
        specularLayer.endPoint = CGPoint(x: 0.5, y: 1)
        specularLayer.frame = CGRect(x: 0, y: 0, width: 600, height: 2)
        specularLayer.cornerRadius = cornerRadius
        specularLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        specularLayer.autoresizingMask = [.layerWidthSizable]
        effectView.layer?.addSublayer(specularLayer)

        // Subtle inner border for glass edge definition
        let innerBorder = CALayer()
        innerBorder.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        innerBorder.borderWidth = 0.5
        innerBorder.cornerRadius = cornerRadius
        innerBorder.masksToBounds = true
        innerBorder.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        effectView.layer?.addSublayer(innerBorder)

        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Visual Effect Background (for Settings/other views)

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
