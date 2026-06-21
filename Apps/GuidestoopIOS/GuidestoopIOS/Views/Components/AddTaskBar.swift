import SwiftUI

struct AddTaskBar: View {
    @Binding var text: String
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedText.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.body.weight(.medium))
                .foregroundStyle(GuidestoopTheme.textSecondary)

            TextField("New task", text: $text)
                .font(GuidestoopTypography.body)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(submit)

            Button("Add", action: submit)
                .font(GuidestoopTypography.meta.weight(.semibold))
                .guidestoopProminentButton()
                .disabled(!canSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func submit() {
        guard canSubmit else { return }
        let title = trimmedText
        onSubmit(title)
        text = ""
        isFocused = true
    }
}
