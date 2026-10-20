import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var parentID: UUID?
    var estimate: Int      // pomodoros planned
    var spent: Int         // pomodoros finished
    var isBacklog: Bool    // false = Today, true = Backlog
    var completedAt: Date? // set when checked off, nil when open

    init(id: UUID = UUID(), title: String, isDone: Bool = false, parentID: UUID? = nil,
         estimate: Int = 1, spent: Int = 0, isBacklog: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.parentID = parentID
        self.estimate = estimate
        self.spent = spent
        self.isBacklog = isBacklog
        self.completedAt = completedAt
    }

    // Missing fields fall back to defaults, so tasks saved by older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        estimate = try c.decodeIfPresent(Int.self, forKey: .estimate) ?? 1
        spent = try c.decodeIfPresent(Int.self, forKey: .spent) ?? 0
        isBacklog = try c.decodeIfPresent(Bool.self, forKey: .isBacklog) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

/// Dates are stored as ISO 8601 strings, so they're readable in the JSON editor.
enum TaskJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// One day's finished tasks in the Done section.
struct DoneGroup: Identifiable {
    let day: Date?   // nil = finished before dates were recorded
    let tasks: [TodoItem]
    var id: String { day.map { String($0.timeIntervalSince1970) } ?? "undated" }
}

@MainActor
final class TaskStore: ObservableObject {
    @Published var items: [TodoItem] = [] {
        didSet { save() }
    }

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StreamOfChange", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("tasks.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? TaskJSON.decoder().decode([TodoItem].self, from: data) {
            items = decoded
        } else {
            items = TaskStore.seed
        }
    }

    /// Top-level tasks in the Today or Backlog section.
    func roots(backlog: Bool) -> [TodoItem] {
        items.filter { $0.parentID == nil && $0.isBacklog == backlog && !$0.isDone }
    }

    /// Top-level tasks that are checked off.
    var doneRoots: [TodoItem] { items.filter { $0.parentID == nil && $0.isDone } }

    /// Done tasks grouped by the day they were checked off, newest first.
    /// Tasks finished before dates were recorded go into the last group.
    func doneGroups() -> [DoneGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: doneRoots.filter { $0.completedAt != nil }) {
            calendar.startOfDay(for: $0.completedAt!)
        }
        var groups = byDay.keys.sorted(by: >).map { day in
            DoneGroup(day: day, tasks: byDay[day]!.sorted { $0.completedAt! > $1.completedAt! })
        }
        let undated = doneRoots.filter { $0.completedAt == nil }
        if !undated.isEmpty { groups.append(DoneGroup(day: nil, tasks: undated)) }
        return groups
    }

    /// Top-level tasks checked off since `start`.
    func doneCount(since start: Date) -> Int {
        doneRoots.filter { ($0.completedAt ?? .distantPast) >= start }.count
    }

    /// Pomodoros logged across all tasks.
    var pomodorosLogged: Int { items.filter { isLeaf($0) }.reduce(0) { $0 + $1.spent } }

    /// A task with no subtasks. Only these hold pomodoros; a parent shows the sum of its subtasks.
    func isLeaf(_ item: TodoItem) -> Bool {
        !items.contains { $0.parentID == item.id }
    }

    /// Planned pomodoros for a task, including all of its subtasks.
    func estimate(of item: TodoItem) -> Int {
        let kids = children(of: item.id)
        return kids.isEmpty ? item.estimate : kids.reduce(0) { $0 + estimate(of: $1) }
    }

    /// Finished pomodoros for a task, including all of its subtasks.
    func spent(of item: TodoItem) -> Int {
        let kids = children(of: item.id)
        return kids.isEmpty ? item.spent : kids.reduce(0) { $0 + spent(of: $1) }
    }


    func children(of id: UUID) -> [TodoItem] { items.filter { $0.parentID == id } }

    /// Pomodoros still needed across unfinished Today tasks.
    var pendingPomodoros: Int {
        items.filter { isLeaf($0) && !$0.isDone && !$0.isBacklog }.reduce(0) { $0 + max($1.estimate - $1.spent, 0) }
    }

    func add(_ title: String, parent: UUID? = nil, backlog: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let inheritedBacklog = parent.flatMap { id in items.first { $0.id == id }?.isBacklog } ?? backlog
        items.append(TodoItem(title: trimmed, parentID: parent, isBacklog: inheritedBacklog))
    }

    func toggle(_ id: UUID) {
        update(id) {
            $0.isDone.toggle()
            $0.completedAt = $0.isDone ? Date() : nil
        }
    }

    /// Moves a task and its subtasks between Today and Backlog.
    func move(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let target = !item.isBacklog
        for i in items.indices where items[i].id == id || items[i].parentID == id {
            items[i].isBacklog = target
        }
    }

    /// Moves a top-level task (with its subtasks) to just before another top-level task.
    /// If the target is in the other section, the task moves there too.
    func reorder(_ draggedID: UUID, before targetID: UUID) {
        guard draggedID != targetID,
              let dragged = items.first(where: { $0.id == draggedID }), dragged.parentID == nil,
              let target = items.first(where: { $0.id == targetID }), target.parentID == nil else { return }
        var block = items.filter { $0.id == draggedID || $0.parentID == draggedID }
        for i in block.indices { block[i].isBacklog = target.isBacklog }
        var rest = items.filter { $0.id != draggedID && $0.parentID != draggedID }
        guard let index = rest.firstIndex(where: { $0.id == targetID }) else { return }
        rest.insert(contentsOf: block, at: index)
        items = rest
    }

    /// Moves a top-level task (with its subtasks) to the end of the Today or Backlog section.
    func moveToEnd(_ draggedID: UUID, backlog: Bool) {
        guard let dragged = items.first(where: { $0.id == draggedID }), dragged.parentID == nil else { return }
        var block = items.filter { $0.id == draggedID || $0.parentID == draggedID }
        for i in block.indices { block[i].isBacklog = backlog }
        let rest = items.filter { $0.id != draggedID && $0.parentID != draggedID }
        items = rest + block
    }

    func update(_ id: UUID, _ change: (inout TodoItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id || $0.parentID == id }
    }

    /// All tasks as pretty-printed JSON text.
    func exportJSON() -> String {
        let encoder = TaskJSON.encoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items), let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    /// Replaces all tasks with the JSON text. Throws if the text isn't a valid task list.
    func importJSON(_ text: String) throws {
        items = try TaskJSON.decoder().decode([TodoItem].self, from: Data(text.utf8))
    }

    private func save() {
        guard let data = try? TaskJSON.encoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static let seed: [TodoItem] = {
        let prep = UUID()
        let fen = UUID()
        let comp = UUID()
        return [
            TodoItem(id: prep, title: "Prep for DLP's presentation (90 min)", estimate: 3),
            TodoItem(title: "Princípios de Eletrônica Analógica prática", estimate: 2),
            TodoItem(title: "Artigo de Compiladores", estimate: 2),
            TodoItem(id: fen, title: "Estudar fenômenos"),
            TodoItem(title: "Lei de Coulomb", parentID: fen),
            TodoItem(title: "Campo elétrico contínuo e discreto", parentID: fen),
            TodoItem(title: "Lei de Gauss", parentID: fen),
            TodoItem(title: "Potencial elétrico", parentID: fen),
            TodoItem(title: "Capacitância", parentID: fen),
            TodoItem(title: "Corrente elétrica", parentID: fen),
            TodoItem(title: "Resistência elétrica", parentID: fen),
            TodoItem(title: "Übung des Woches", estimate: 2),
            TodoItem(id: comp, title: "Estudar compiladores"),
            TodoItem(title: "Lista de transformações", parentID: comp, estimate: 2),
            TodoItem(title: "Entender a fórmula gigante", parentID: comp, estimate: 2)
        ]
    }()
}
