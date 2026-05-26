import SwiftUI
import AppKit

struct OverlaySelectionView: View {
    @ObservedObject var captureService: CaptureService
    let screen: NSScreen

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var isDragging = false

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimming overlay
                if let rect = selectionRect {
                    DimmingOverlayShape(selectionRect: rect)
                        .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)

                    // Selection border
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .allowsHitTesting(false)

                    // Size indicator
                    if rect.width > 40 && rect.height > 20 {
                        Text("\(Int(rect.width * screen.backingScaleFactor)) x \(Int(rect.height * screen.backingScaleFactor))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule()
                                    .fill(.black.opacity(0.7))
                            }
                            .position(x: rect.midX, y: rect.maxY + 20)
                            .allowsHitTesting(false)
                    }
                } else {
                    Color.black.opacity(0.15)
                        .allowsHitTesting(false)
                }

                // Capture area for mouse events
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if startPoint == nil {
                                    startPoint = value.startLocation
                                    isDragging = true
                                }
                                currentPoint = value.location
                            }
                            .onEnded { _ in
                                if let rect = selectionRect, rect.width > 3, rect.height > 3 {
                                    captureService.captureArea(rect: rect, screen: screen)
                                }
                                startPoint = nil
                                currentPoint = nil
                                isDragging = false
                            }
                    )
                    .onTapGesture {
                        captureService.cancelCapture()
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

struct DimmingOverlayShape: Shape {
    let selectionRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(selectionRect)
        return path
    }
}
