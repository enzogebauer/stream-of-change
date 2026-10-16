import SwiftUI

@main
struct StreamOfChangeApp: App {
    @StateObject private var store = TaskStore()
    @StateObject private var timer = PomodoroTimer()

    var body: some Scene {
        WindowGroup("Stream of change") {
            ContentView()
                .environmentObject(store)
                .environmentObject(timer)
                .frame(minWidth: 700, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}
