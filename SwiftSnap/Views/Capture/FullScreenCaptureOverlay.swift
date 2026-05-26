import SwiftUI
import AppKit

struct FullScreenCaptureOverlay: View {
    @ObservedObject var captureService: CaptureService
    let screen: NSScreen

    @State private var isHovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dim overlay that lightens on hover
                Color.black.opacity(isHovered ? 0.05 : 0.2)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)

                // Border highlight
                if isHovered {
                    RoundedRectangle(cornerRadius: 0)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.blue.opacity(0.7), .blue.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 4
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 15)
                        .transition(.opacity)
                }

                // Display label
                VStack(spacing: 8) {
                    Image(systemName: "display")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.5))

                    Text("Click to capture")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.5))
                }
                .padding(16)
                .background {
                    if isHovered {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isHovered)

                Color.clear
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHovered = hovering
                    }
                    .onTapGesture {
                        captureService.captureFullScreen(screen: screen)
                    }
            }
        }
        .ignoresSafeArea()
    }
}
