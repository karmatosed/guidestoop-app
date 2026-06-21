import SwiftUI

struct QuickAddField: View {
    let placeholder: String
    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(placeholder: String = "Add a task…", onSubmit: @escaping (String) -> Void) {
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.body.weight(.medium))
                .foregroundStyle(GuidestoopTheme.textSecondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(GuidestoopTheme.textPrimary)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(submit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(GuidestoopTheme.surface.opacity(0.5))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(GuidestoopTheme.dashedBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        text = ""
    }
}
