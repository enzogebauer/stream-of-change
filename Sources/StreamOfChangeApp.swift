import SwiftUI
import Combine

@main
struct StreamOfChangeApp: App {
    @StateObject private var store = TaskStore()
    @StateObject private var timer = PomodoroTimer()
    @StateObject private var quotes = DailyQuoteStore()

    var body: some Scene {
        WindowGroup("Stream of change") {
            ContentView()
                .environmentObject(store)
                .environmentObject(timer)
                .environmentObject(quotes)
                .task { await quotes.refreshIfNeeded() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await quotes.refreshIfNeeded() }
                }
                .frame(minWidth: 700, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

        Window("Edit tasks as JSON", id: "json-editor") {
            JSONEditorView()
                .environmentObject(store)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(timer)
        } label: {
            MenuBarLabel()
                .environmentObject(timer)
        }
        .menuBarExtraStyle(.menu)
    }
}
