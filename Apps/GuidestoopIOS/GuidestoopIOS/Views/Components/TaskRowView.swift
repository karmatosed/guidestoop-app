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
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(task.status == .done ? GuidestoopTheme.textPrimary : GuidestoopTheme.textSecondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if task.highPriority {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GuidestoopTheme.textPrimary)
                            .accessibilityLabel("High priority")
                    }
                    Text(task.title)
                        .font(GuidestoopTypography.body)
                        .foregroundStyle(task.status == .done ? .secondary : .primary)
                        .strikethrough(task.status == .done, color: .secondary)
                }

                if !metadataParts.isEmpty {
                    Text(metadataParts)
                        .font(GuidestoopTypography.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var metadataParts: String {
        var parts: [String] = []
        if let project = task.project, !project.isEmpty {
            parts.append(project)
        }
        if let scheduled = task.scheduled, !scheduled.isEmpty {
            parts.append(formatScheduled(scheduled))
        }
        if !task.tags.isEmpty {
            parts.append(task.tags.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
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
                .font(GuidestoopTypography.body)

            Text(purgeLabel)
                .font(GuidestoopTypography.meta)
                .foregroundStyle(.secondary)
        }
    }

    private var purgeLabel: String {
        if daysUntilPurge <= 0 {
            return "expires soon"
        }
        if daysUntilPurge == 1 {
            return "purges in 1d"
        }
        return "purges in \(daysUntilPurge)d"
    }
}
