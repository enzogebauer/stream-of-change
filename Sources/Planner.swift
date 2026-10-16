import Foundation

struct TimerDurations {
    let focus: Int   // seconds
    let short: Int
    let long: Int
}

enum Planner {
    /// Seconds needed to finish `pomodoros` focus sessions, including the breaks between them.
    /// Every 4th completed focus session gets a long break, like the Pomodoro technique.
    static func totalSeconds(pomodoros: Int, completedSoFar: Int, durations: TimerDurations) -> Int {
        guard pomodoros > 0 else { return 0 }
        var total = 0
        for i in 0..<pomodoros {
            total += durations.focus
            if i < pomodoros - 1 {
                let sessionNumber = completedSoFar + i + 1
                total += sessionNumber % 4 == 0 ? durations.long : durations.short
            }
        }
        return total
    }

    static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
