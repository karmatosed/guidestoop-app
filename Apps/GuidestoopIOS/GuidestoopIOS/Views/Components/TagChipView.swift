import SwiftUI

struct TagChipView: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? GuidestoopTheme.accent.opacity(0.25) : GuidestoopTheme.surface)
                .foregroundStyle(isSelected ? GuidestoopTheme.accent : GuidestoopTheme.textSecondary)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? GuidestoopTheme.accent : GuidestoopTheme.dashedBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
