import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var timer: PomodoroTimer
    @State private var newTitle = ""

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            timerPanel
                .frame(width: 280)
                .padding(24)

            Divider()

            todoPanel
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .tint(.ember)
    }

    // MARK: Timer

    private var timerPanel: some View {
        VStack(spacing: 20) {
            Picker("Mode", selection: Binding(get: { timer.mode }, set: { timer.select($0) })) {
                ForEach(PomodoroTimer.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(timer.display)
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Reset") { timer.reset() }
                    .controlSize(.large)
            }

            Text("Focus sessions completed: \(timer.completedFocusSessions)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            DisclosureGroup("Durations") {
                VStack(alignment: .leading, spacing: 10) {
                    DurationField(title: "Focus", minutes: $timer.focusMinutes, range: 1...180)
                    DurationField(title: "Short break", minutes: $timer.shortMinutes, range: 1...60)
                    DurationField(title: "Long break", minutes: $timer.longMinutes, range: 1...120)
                    Button("Restore defaults") { timer.restoreDefaults() }
                        .controlSize(.small)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }

    // MARK: Tasks

    private var todoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stream of change")
                .font(.title2.bold())

            summary

            HStack {
                TextField("New task", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTask)
                Button("Add", action: addTask)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.roots) { item in
                        TodoRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var summary: some View {
        TimelineView(.everyMinute) { context in
            let total = Planner.totalSeconds(
                pomodoros: store.pendingPomodoros,
                completedSoFar: timer.completedFocusSessions,
                durations: timer.durations
            )
            let finish = context.date.addingTimeInterval(TimeInterval(total))
            HStack(spacing: 24) {
                stat("Pomodoros left", "\(store.pendingPomodoros)")
                stat("Time needed", Planner.formatDuration(total))
                stat("Done around", store.pendingPomodoros == 0 ? "—" : finish.formatted(date: .omitted, time: .shortened))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).monospacedDigit()
        }
    }

    private func addTask() {
        store.add(newTitle)
        newTitle = ""
    }
}

struct TodoRow: View {
    let item: TodoItem
    @EnvironmentObject var store: TaskStore
    @State private var showingSubtask = false
    @State private var subtaskTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button { store.toggle(item.id) } label: {
                    Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.isDone ? Color.ember : .secondary)
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)

                Spacer()

                pomodoroControls

                Button { showingSubtask.toggle() } label: {
                    Image(systemName: "plus.bubble")
                }
                .buttonStyle(.plain)
                .help("Add subtask")

                Button(role: .destructive) { store.delete(item.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if showingSubtask {
                TextField("Subtask", text: $subtaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading, 26)
                    .onSubmit {
                        store.add(subtaskTitle, parent: item.id)
                        subtaskTitle = ""
                        showingSubtask = false
                    }
            }

            ForEach(store.children(of: item.id)) { child in
                TodoRow(item: child)
                    .padding(.leading, 26)
            }
        }
    }

    private var pomodoroControls: some View {
        HStack(spacing: 4) {
            Button { store.update(item.id) { $0.estimate = max(1, $0.estimate - 1) } } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("Fewer planned pomodoros")

            Text("\(item.spent)/\(item.estimate) 🍅")
                .font(.caption)
                .monospacedDigit()
                .frame(minWidth: 52)

            Button { store.update(item.id) { $0.estimate += 1 } } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .help("More planned pomodoros")

            Button { store.update(item.id) { $0.spent += 1 } } label: {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.plain)
            .help("Log a finished pomodoro")
        }
        .foregroundStyle(.secondary)
    }
}

struct DurationField: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { isFocused in
                    if !isFocused { commit() }
                }
            Text("min")
                .foregroundStyle(.secondary)
        }
        .onAppear { text = String(minutes) }
        .onChange(of: minutes) { newValue in
            text = String(newValue)
        }
    }

    /// Accepts typed minutes, clamps them to the allowed range, and reverts invalid input.
    private func commit() {
        if let value = Int(text.trimmingCharacters(in: .whitespaces)) {
            minutes = min(max(value, range.lowerBound), range.upperBound)
        }
        text = String(minutes)
    }
}

extension Color {
    /// The ember orange from the app icon (#E4572E).
    static let ember = Color(red: 0.894, green: 0.341, blue: 0.180)
}
