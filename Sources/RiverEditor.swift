import SwiftUI
import Foundation

/// Three wavy lines, like flowing water.
struct RiverShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let rows: [CGFloat] = [0.2, 0.5, 0.8]
        let amplitude = rect.height * 0.12
        let steps = 48
        for row in rows {
            let midY = rect.minY + rect.height * row
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let point = CGPoint(x: rect.minX + t * rect.width,
                                    y: midY + amplitude * sin(t * 4 * .pi))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        return path
    }
}

/// The river icon. `progress` (0 to 1) fills the waves from left to right as rivers are logged.
struct RiverGlyph: View {
    var progress: Double
    var lineWidth: CGFloat = 2

    var body: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
        ZStack {
            RiverShape()
                .stroke(Color.secondary.opacity(0.35), style: style)
            RiverShape()
                .stroke(Color.primary, style: style)
                .mask(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                    }
                }
        }
    }
}

/// Popover to set how many rivers a task needs, by typing rivers or a time in hours, minutes and seconds.
/// One river is one focus block, so the two always convert into each other.
struct RiverEditor: View {
    let itemID: UUID
    let onClose: () -> Void
    @EnvironmentObject var store: TaskStore
    @EnvironmentObject var timer: PomodoroTimer

    private let presets: [(value: Double, label: String)] = [
        (0.25, "¼"), (0.5, "½"), (1, "1"), (2, "2"), (4, "4")
    ]

    private var item: TodoItem? { store.items.first { $0.id == itemID } }
    private var childCount: Int { store.children(of: itemID).count }
    private var rivers: Double { item.map { store.estimate(of: $0) } ?? 0 }
    private var logged: Double { item.map { store.spent(of: $0) } ?? 0 }
    private var focusSeconds: Int { max(timer.focusMinutes * 60, 1) }
    private var totalSeconds: Int { Int((rivers * Double(focusSeconds)).rounded()) }

    private func setRivers(_ value: Double) {
        store.setEstimate(itemID, to: (max(0, value) * 10_000).rounded() / 10_000)
    }

    private func setSeconds(_ seconds: Int) {
        setRivers(Double(max(0, seconds)) / Double(focusSeconds))
    }

    private var riversBinding: Binding<Double> {
        Binding(get: { rivers }, set: { setRivers($0) })
    }

    private var hoursBinding: Binding<Int> {
        Binding(get: { totalSeconds / 3600 },
                set: { setSeconds($0 * 3600 + totalSeconds % 3600) })
    }

    private var minutesBinding: Binding<Int> {
        Binding(get: { (totalSeconds % 3600) / 60 },
                set: { setSeconds((totalSeconds / 3600) * 3600 + $0 * 60 + totalSeconds % 60) })
    }

    private var secondsBinding: Binding<Int> {
        Binding(get: { totalSeconds % 60 },
                set: { setSeconds((totalSeconds / 60) * 60 + $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RiverGlyph(progress: rivers > 0 ? logged / rivers : 0, lineWidth: 3)
                    .frame(width: 44, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item?.title ?? "")
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(riverText(logged)) of \(riverText(rivers)) rivers logged")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            LabeledContent("Rivers") {
                HStack(spacing: 6) {
                    TextField("", value: riversBinding, format: .number.precision(.fractionLength(0...2)))
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Stepper("", value: riversBinding, in: 0...200, step: 0.25)
                        .labelsHidden()
                }
            }

            LabeledContent("Time") {
                HStack(spacing: 6) {
                    timeField(hoursBinding, unit: "h")
                    timeField(minutesBinding, unit: "min")
                    timeField(secondsBinding, unit: "s")
                }
            }

            Text("1 river = \(timer.focusMinutes) min of focus. Type a time and the rivers follow, or the other way around. Press Return to apply.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("Quick set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(presets, id: \.label) { preset in
                    Button(preset.label) { setRivers(preset.value) }
                        .controlSize(.small)
                }
            }

            if childCount > 0 {
                Text("Shared evenly across its \(childCount) subtasks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 330)
    }

    private func timeField(_ value: Binding<Int>, unit: String) -> some View {
        HStack(spacing: 3) {
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
