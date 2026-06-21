import SwiftUI
import GuidestoopCore

struct DayTimelineView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @State private var tasks: [Task] = []
    @State private var selectedDate = Date()
    @State private var saveError: String?

    private var dateYmd: String {
        TaskFilters.localDateYmd(date: selectedDate)
    }

    private var timeline: (scheduled: [Task], focus: [Task]) {
        TaskFilters.dayTimelineTasks(tasks, dateYmd: dateYmd)
    }

    var body: some View {
        List {
            Section {
                DatePicker("Day", selection: $selectedDate, displayedComponents: .date)
            }

            Section {
                QuickAddField(placeholder: "Add for \(dateYmd)…") { title in
                    addScheduledTask(title: title)
                }
            }

            if !timeline.focus.isEmpty {
                Section("Focus") {
                    ForEach(timeline.focus) { task in
                        TimelineRowView(task: task)
                    }
                }
            }

            Section("Scheduled") {
                if timeline.scheduled.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing scheduled", systemImage: "calendar")
                    }
                } else {
                    ForEach(timeline.scheduled) { task in
                        TimelineRowView(task: task)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(GuidestoopTheme.background)
        .guidestoopSyncToolbar(
            isSyncing: appEnvironment.syncCoordinator.isSyncing,
            outboxCount: appEnvironment.syncCoordinator.outboxCount
        ) {
            Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
        }
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .task { reloadTasks() }
        .onChange(of: appEnvironment.syncCoordinator.lastSyncedAt) { _, _ in
            reloadTasks()
        }
    }

    private func reloadTasks() {
        tasks = (try? appEnvironment.localStore.allCachedTasks()) ?? []
    }

    private func addScheduledTask(title: String) {
        var task = TaskFactory.create(title: title, status: .scheduled)
        task.scheduled = dateYmd
        save(task)
    }

    private func save(_ task: Task) {
        do {
            try appEnvironment.localStore.saveTask(task)
            reloadTasks()
            appEnvironment.syncCoordinator.noteLocalChange()
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
                        .font(GuidestoopTypography.meta)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                }
                if let durationLabel = durationLabel {
                    Text(durationLabel)
                        .font(GuidestoopTypography.meta)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(GuidestoopTypography.body)

                if let project = task.project, !project.isEmpty {
                    Text(project)
                        .font(GuidestoopTypography.meta)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var scheduledTimeLabel: String? {
        guard let scheduled = task.scheduled else { return nil }
        if scheduled.count == 10 { return "all day" }
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
