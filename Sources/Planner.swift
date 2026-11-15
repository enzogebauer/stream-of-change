import Foundation

struct TimerDurations {
    let focus: Int   // seconds
    let short: Int
    let long: Int
}

enum Planner {
    /// Seconds needed for `rivers` (decimals allowed; one river = one focus block), including the breaks between them.
    /// Every 4th completed focus session gets a long break, like the Pomodoro technique.
    static func totalSeconds(rivers: Double, completedSoFar: Int, durations: TimerDurations) -> Int {
        guard rivers > 0 else { return 0 }
        let sessions = Int(rivers.rounded(.up))
        var total = Int((rivers * Double(durations.focus)).rounded())
        for i in 0..<(sessions - 1) {
            let sessionNumber = completedSoFar + i + 1
            total += sessionNumber % 4 == 0 ? durations.long : durations.short
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

/// Shows rivers with at most two decimals and no trailing zeros: 2 → "2", 2.5 → "2.5", 0.3333 → "0.33".
func riverText(_ value: Double) -> String {
    let rounded = (value * 100).rounded() / 100
    return rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rounded)) : String(format: "%g", rounded)
}
