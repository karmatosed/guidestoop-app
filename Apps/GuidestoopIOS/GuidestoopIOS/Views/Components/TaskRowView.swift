import SwiftUI
import GuidestoopCore

struct TaskRowView: View {
    let task: Task
    let onToggleDone: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleDone) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.status == .done ? GuidestoopTheme.accent : GuidestoopTheme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.status == .done ? GuidestoopTheme.textSecondary : GuidestoopTheme.textPrimary)
                    .strikethrough(task.status == .done, color: GuidestoopTheme.textSecondary)

                HStack(spacing: 8) {
                    if let project = task.project, !project.isEmpty {
                        Text(project)
                            .font(.caption)
                            .foregroundStyle(GuidestoopTheme.textSecondary)
                    }

                    if let scheduled = task.scheduled, !scheduled.isEmpty {
                        Text(formatScheduled(scheduled))
                            .font(.caption)
                            .foregroundStyle(GuidestoopTheme.textSecondary)
                    }

                    if !task.tags.isEmpty {
                        Text(task.tags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(GuidestoopTheme.accent.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formatScheduled(_ scheduled: String) -> String {
        if scheduled.count == 10 { return scheduled }
        let ymd = ScheduleLogic.localYmdFromIso(scheduled)
        if scheduled.contains("T"), ymd.count == 10 {
            let timePart = scheduled.split(separator: "T").dropFirst().first.map(String.init) ?? ""
            let hhmm = timePart.prefix(5)
            return hhmm.isEmpty ? ymd : "\(ymd) \(hhmm)"
        }
        return ymd.isEmpty ? scheduled : ymd
    }
}

struct DeletedTaskRowView: View {
    let deletedTask: DeletedTask
    let daysUntilPurge: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deletedTask.title)
                .font(.body)
                .foregroundStyle(GuidestoopTheme.textPrimary)

            Text(purgeLabel)
                .font(.caption)
                .foregroundStyle(GuidestoopTheme.textSecondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purgeLabel: String {
        if daysUntilPurge <= 0 {
            return "Expires soon"
        }
        if daysUntilPurge == 1 {
            return "Purges in 1 day"
        }
        return "Purges in \(daysUntilPurge) days"
    }
}
