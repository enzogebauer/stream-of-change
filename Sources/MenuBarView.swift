import SwiftUI
import AppKit

/// The timer shown in the menu bar, e.g. "24:59".
struct MenuBarLabel: View {
    @EnvironmentObject var timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image)
            Text(timer.display)
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
        }
    }
}

/// Monochrome template icon: macOS tints it for light and dark menu bars automatically.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
            ?? NSImage()
        image.size = NSSize(width: 22, height: 22)
        image.isTemplate = true
        return image
    }()
}

/// The menu that opens when clicking the menu bar item.
struct MenuBarView: View {
    @EnvironmentObject var timer: PomodoroTimer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("\(timer.mode.rawValue) · \(timer.display)")

        Button(timer.isRunning ? "Pause" : "Start") {
            timer.isRunning ? timer.pause() : timer.start()
        }

        Button("Reset") { timer.reset() }

        Divider()

        ForEach(PomodoroTimer.Mode.allCases) { mode in
            Button {
                timer.select(mode)
            } label: {
                if timer.mode == mode {
                    Label(mode.rawValue, systemImage: "checkmark")
                } else {
                    Text(mode.rawValue)
                }
            }
        }

        Divider()

        Button("Show Stream of change") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
        }

        Button("Edit Tasks as JSON…") {
            openWindow(id: "json-editor")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
