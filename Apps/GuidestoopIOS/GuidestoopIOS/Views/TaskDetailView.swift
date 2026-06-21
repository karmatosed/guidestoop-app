import SwiftUI
import GuidestoopCore

private enum DetailTab: String, CaseIterable {
    case form = "Form"
    case markdown = "Markdown"
}

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var appEnvironment: AppEnvironment

    let task: Task

    @State private var draft: Task
    @State private var selectedTab: DetailTab = .form
    @State private var hasScheduledTime = false
    @State private var isScheduled = false
    @State private var scheduledDate = Date()
    @State private var scheduledTime = Date()
    @State private var tagsText = ""
    @State private var markdownText = ""
    @State private var saveError: String?

    init(task: Task) {
        self.task = task
        _draft = State(initialValue: task)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: 0) {
                    formContent
                        .frame(maxWidth: .infinity)
                    Divider()
                    markdownContent
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if selectedTab == .form {
                        formContent
                    } else {
                        markdownContent
                    }
                }
            }
        }
        .background(GuidestoopTheme.background)
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndDismiss() }
            }
        }
        .onAppear(perform: loadFromDraft)
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var formContent: some View {
        Form {
            Section {
                TextField("Title", text: $draft.title, axis: .vertical)
                    .lineLimit(1 ... 3)
            }

            Section {
                Picker("Status", selection: $draft.status) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(status)
                    }
                }

                DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                    .disabled(!isScheduled)

                Toggle("Scheduled", isOn: $isScheduled)

                Toggle("Include time", isOn: $hasScheduledTime)
                    .disabled(!isScheduled)

                if hasScheduledTime {
                    DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                }

                Stepper(value: Binding(
                    get: { draft.duration ?? 0 },
                    set: { draft.duration = $0 > 0 ? $0 : nil }
                ), in: 0 ... 480, step: 15) {
                    Text("Duration: \(draft.duration ?? 0) min")
                }
            }

            Section {
                TextField("Project", text: Binding(
                    get: { draft.project ?? "" },
                    set: { draft.project = $0.isEmpty ? nil : $0 }
                ))

                TextField("Tags (comma-separated)", text: $tagsText)
            }

            Section {
                Toggle("High priority", isOn: $draft.highPriority)
            }

            Section("Notes") {
                TextEditor(text: $draft.body)
                    .frame(minHeight: 120)
                    .font(GuidestoopTypography.mono)
            }
        }
        .guidestoopFormStyle()
    }

    private var markdownContent: some View {
        ScrollView {
            Text(markdownText)
                .font(GuidestoopTypography.mono)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
    }

    private func loadFromDraft() {
        tagsText = draft.tags.joined(separator: ", ")
        applyScheduledFields(from: draft.scheduled)
        refreshMarkdownPreview()
    }

    private func applyScheduledFields(from scheduled: String?) {
        isScheduled = scheduled != nil && !(scheduled?.isEmpty ?? true)
        guard let scheduled, !scheduled.isEmpty else {
            scheduledDate = Date()
            scheduledTime = Date()
            hasScheduledTime = false
            return
        }

        if scheduled.count == 10 {
            scheduledDate = dateFromYmd(scheduled) ?? Date()
            hasScheduledTime = false
            return
        }

        if let date = ISO8601DateFormatter().date(from: scheduled) {
            scheduledDate = date
            scheduledTime = date
            hasScheduledTime = scheduled.contains("T")
        }
    }

    private func dateFromYmd(_ ymd: String) -> Date? {
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return Calendar.current.date(from: components)
    }

    private func composeScheduledValue() -> String? {
        guard isScheduled else { return nil }
        let ymd = TaskFilters.localDateYmd(date: scheduledDate)
        guard hasScheduledTime else { return ymd }

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        guard let hour = time.hour, let minute = time.minute else { return ymd }
        return String(format: "%@T%02d:%02d:00Z", ymd, hour, minute)
    }

    private func applyEditsToDraft() {
        draft.tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        draft.scheduled = composeScheduledValue()
        draft.updated = ISO8601DateFormatter().string(from: Date())
        refreshMarkdownPreview()
    }

    private func refreshMarkdownPreview() {
        markdownText = (try? TaskMarkdown.serialize(draft)) ?? "Could not serialize task"
    }

    private func saveAndDismiss() {
        applyEditsToDraft()
        do {
            try appEnvironment.localStore.saveTask(draft)
            appEnvironment.syncCoordinator.noteLocalChange()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
