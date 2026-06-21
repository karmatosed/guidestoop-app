import SwiftUI

struct ConflictBannerView: View {
    let conflictCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label {
                Text(conflictCount == 1
                     ? "1 task edited elsewhere"
                     : "\(conflictCount) tasks edited elsewhere")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "doc.on.doc")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GuidestoopTheme.warning.opacity(0.12))
    }
}
