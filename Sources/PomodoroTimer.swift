import Foundation
import AppKit

@MainActor
final class PomodoroTimer: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case focus = "Focus"
        case shortBreak = "Short break"
        case longBreak = "Long break"
        var id: String { rawValue }
    }

    @Published var focusMinutes: Int {
        didSet {
            UserDefaults.standard.set(focusMinutes, forKey: "focusMinutes")
            syncIfIdle(.focus)
        }
    }
    @Published var shortMinutes: Int {
        didSet {
            UserDefaults.standard.set(shortMinutes, forKey: "shortMinutes")
            syncIfIdle(.shortBreak)
        }
    }
    @Published var longMinutes: Int {
        didSet {
            UserDefaults.standard.set(longMinutes, forKey: "longMinutes")
            syncIfIdle(.longBreak)
        }
    }

    @Published var mode: Mode = .focus
    @Published private(set) var remaining: Int
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocusSessions = 0

    private var ticker: Timer?

    init() {
        let d = UserDefaults.standard
        let focus = d.object(forKey: "focusMinutes") as? Int ?? 25
        focusMinutes = focus
        shortMinutes = d.object(forKey: "shortMinutes") as? Int ?? 5
        longMinutes = d.object(forKey: "longMinutes") as? Int ?? 15
        remaining = focus * 60
    }

    var durations: TimerDurations {
        TimerDurations(focus: focusMinutes * 60, short: shortMinutes * 60, long: longMinutes * 60)
    }

    func seconds(for mode: Mode) -> Int {
        switch mode {
        case .focus: return focusMinutes * 60
        case .shortBreak: return shortMinutes * 60
        case .longBreak: return longMinutes * 60
        }
    }

    var display: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func start() {
        guard !isRunning, remaining > 0 else { return }
        isRunning = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    func restoreDefaults() {
        focusMinutes = 25
        shortMinutes = 5
        longMinutes = 15
    }

    func reset() {
        pause()
        remaining = seconds(for: mode)
    }

    func select(_ newMode: Mode) {
        pause()
        mode = newMode
        remaining = seconds(for: newMode)
    }

    private func syncIfIdle(_ changed: Mode) {
        if !isRunning && mode == changed {
            remaining = seconds(for: changed)
        }
    }

    private func tick() {
        guard isRunning, remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 {
            if mode == .focus { completedFocusSessions += 1 }
            pause()
            if mode == .longBreak {
                // Long break is over: play a louder sound and bounce the Dock icon until the app is opened.
                NSSound(named: "Hero")?.play()
                NSApp.requestUserAttention(.criticalRequest)
            } else {
                NSSound.beep()
            }
        }
    }
}
