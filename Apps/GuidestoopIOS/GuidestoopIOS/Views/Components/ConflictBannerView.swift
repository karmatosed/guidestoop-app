import SwiftUI

struct ConflictBannerView: View {
    let conflictCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                    .font(.subheadline)
                Text(conflictCount == 1
                     ? "1 task edited elsewhere"
                     : "\(conflictCount) tasks edited elsewhere")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
            }
            .foregroundStyle(GuidestoopTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(GuidestoopTheme.warning.opacity(0.15))
        }
        .buttonStyle(.plain)
    }
}
