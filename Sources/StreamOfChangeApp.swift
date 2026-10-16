import SwiftUI

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
                .frame(minWidth: 700, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

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
