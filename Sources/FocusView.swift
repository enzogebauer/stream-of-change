import SwiftUI

/// Full-screen view: the big timer in the middle, today's open tasks faded underneath.
struct FocusView: View {
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var timer: PomodoroTimer
    let onExit: () -> Void

    private var nextTasks: [TodoItem] {
        Array(store.roots(backlog: false).filter { !$0.isDone }.prefix(5))
    }

    var body: some View {
        VStack(spacing: 20) {
            TimelineView(.everyMinute) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(timer.display)
                .font(.system(size: 180, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text(timer.mode.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)

            TimelineView(.everyMinute) { context in
                let total = Planner.totalSeconds(
                    pomodoros: store.pendingPomodoros,
                    completedSoFar: timer.completedFocusSessions,
                    durations: timer.durations
                )
                let finish = context.date.addingTimeInterval(TimeInterval(total))
                Text(store.pendingPomodoros == 0
                     ? "Nothing left for today"
                     : "\(store.pendingPomodoros) pomodoros · \(Planner.formatDuration(total)) with breaks · done around \(finish.formatted(date: .omitted, time: .shortened))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Reset") { timer.reset() }
                    .controlSize(.large)

                Button("Exit focus", action: onExit)
                    .controlSize(.large)
            }

            VStack(spacing: 6) {
                ForEach(nextTasks) { task in
                    Text(task.title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .opacity(0.6)
                }
            }
            .padding(.top, 24)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand(perform: onExit)
    }
}
