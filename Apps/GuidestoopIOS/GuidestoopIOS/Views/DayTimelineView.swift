import SwiftUI
import SwiftData
import GuidestoopCore

struct DayTimelineView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Query(sort: \CachedTask.updated, order: .reverse) private var cachedTasks: [CachedTask]

    @State private var selectedDate = Date()
    @State private var saveError: String?

    private var allTasks: [Task] {
        cachedTasks.map { $0.toTask() }
    }

    private var dateYmd: String {
        TaskFilters.localDateYmd(date: selectedDate)
    }

    private var timeline: (scheduled: [Task], focus: [Task]) {
        TaskFilters.dayTimelineTasks(allTasks, dateYmd: dateYmd)
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Day", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            List {
                Section {
                    QuickAddField(placeholder: "Add for \(dateYmd)…") { title in
                        addScheduledTask(title: title)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if !timeline.focus.isEmpty {
                    Section("Focus") {
                        ForEach(timeline.focus) { task in
                            TimelineRowView(task: task)
                                .listRowBackground(Color.clear)
                        }
                    }
                }

                Section("Scheduled") {
                    if timeline.scheduled.isEmpty {
                        Text("Nothing scheduled")
                            .font(.subheadline)
                            .foregroundStyle(GuidestoopTheme.textSecondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(timeline.scheduled) { task in
                            TimelineRowView(task: task)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(GuidestoopTheme.background)
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func addScheduledTask(title: String) {
        var task = TaskFactory.create(title: title, status: .scheduled)
        task.scheduled = dateYmd
        save(task)
    }

    private func save(_ task: Task) {
        do {
            try appEnvironment.localStore.saveTask(task)
            Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct TimelineRowView: View {
    let task: Task

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let timeLabel = scheduledTimeLabel {
                    Text(timeLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(GuidestoopTheme.accent)
                }
                if let durationLabel = durationLabel {
                    Text(durationLabel)
                        .font(.caption2)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                }
            }
            .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(GuidestoopTheme.textPrimary)

                if let project = task.project, !project.isEmpty {
                    Text(project)
                        .font(.caption)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var scheduledTimeLabel: String? {
        guard let scheduled = task.scheduled else { return nil }
        if scheduled.count == 10 { return "All day" }
        let parts = scheduled.split(separator: "T")
        guard parts.count > 1 else { return scheduled }
        return String(parts[1].prefix(5))
    }

    private var durationLabel: String? {
        guard let minutes = task.duration, minutes > 0 else { return nil }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}
