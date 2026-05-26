import SwiftUI

struct NotificationToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)

            Text("Copied to clipboard")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 22)
    }
}
