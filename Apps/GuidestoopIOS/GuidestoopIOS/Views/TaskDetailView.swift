import SwiftUI
import GuidestoopCore

/// Placeholder detail view — expanded in Task 15 with form and markdown tabs.
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let task: Task

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(task.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(GuidestoopTheme.textPrimary)

                    LabeledContent("Status") {
                        Text(task.status.rawValue.capitalized)
                    }

                    if let project = task.project, !project.isEmpty {
                        LabeledContent("Project", value: project)
                    }

                    if !task.tags.isEmpty {
                        LabeledContent("Tags", value: task.tags.joined(separator: ", "))
                    }

                    if !task.body.isEmpty {
                        Text(task.body)
                            .font(.body)
                            .foregroundStyle(GuidestoopTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(GuidestoopTheme.background)
            .foregroundStyle(GuidestoopTheme.textPrimary)
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
