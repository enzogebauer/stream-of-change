import SwiftUI
import AppKit

/// Shows all tasks as editable JSON, so the list can be changed by hand or with an AI assistant.
struct JSONEditorView: View {
    @EnvironmentObject var store: TaskStore
    @State private var text = ""
    @State private var message = ""
    @State private var messageIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tasks as JSON")
                .font(.headline)
            Text("Each task has: id, title, isDone, parentID (null for top-level tasks), estimate, spent, isBacklog, completedAt (ISO date or null). Keep every id unique. Copy the text into an AI assistant, paste its edited version here, and press Save.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Reload") { load() }
                Button("Copy") { copy() }
                Spacer()
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(messageIsError ? Color.red : Color.secondary)
                }
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 580, minHeight: 440)
        .onAppear { load() }
    }

    private func load() {
        text = store.exportJSON()
        message = ""
        messageIsError = false
    }

    private func save() {
        do {
            try store.importJSON(text)
            text = store.exportJSON()
            message = "Saved."
            messageIsError = false
        } catch {
            message = "Not saved: \(error.localizedDescription)"
            messageIsError = true
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = "Copied."
        messageIsError = false
    }
}
