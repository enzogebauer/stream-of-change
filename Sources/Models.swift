import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var parentID: UUID?
    var estimate: Double      // rivers planned
    var spent: Double         // rivers finished
    var isBacklog: Bool    // false = Today, true = Backlog
    var completedAt: Date? // set when checked off, nil when open

    init(id: UUID = UUID(), title: String, isDone: Bool = false, parentID: UUID? = nil,
         estimate: Double = 1, spent: Double = 0, isBacklog: Bool = false, completedAt: Date? = nil) {
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
        estimate = try c.decodeIfPresent(Double.self, forKey: .estimate) ?? 1
        spent = try c.decodeIfPresent(Double.self, forKey: .spent) ?? 0
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

    /// Rivers logged across all tasks.
    var riversLogged: Double { items.filter { isLeaf($0) }.reduce(0.0) { $0 + $1.spent } }

    /// A task with no subtasks. Only these hold rivers; a parent shows the sum of its subtasks.
    func isLeaf(_ item: TodoItem) -> Bool {
        !items.contains { $0.parentID == item.id }
    }

    /// Planned rivers for a task, including all of its subtasks.
    func estimate(of item: TodoItem) -> Double {
        let kids = children(of: item.id)
        return kids.isEmpty ? item.estimate : kids.reduce(0.0) { $0 + estimate(of: $1) }
    }

    /// Finished rivers for a task, including all of its subtasks.
    func spent(of item: TodoItem) -> Double {
        let kids = children(of: item.id)
        return kids.isEmpty ? item.spent : kids.reduce(0.0) { $0 + spent(of: $1) }
    }


    func children(of id: UUID) -> [TodoItem] { items.filter { $0.parentID == id } }

    /// Rivers still needed across unfinished Today tasks.
    var pendingRivers: Double {
        roots(backlog: false).reduce(0.0) { $0 + openRivers(in: $1) }
    }

    /// Rivers still open in a task: its own remaining estimate, or the sum over its subtasks.
    private func openRivers(in item: TodoItem) -> Double {
        if item.isDone { return 0 }
        let kids = children(of: item.id)
        if kids.isEmpty { return max(item.estimate - item.spent, 0) }
        return kids.reduce(0.0) { $0 + openRivers(in: $1) }
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

    /// A task plus all of its subtasks, at any depth.
    private func subtreeIDs(_ id: UUID) -> Set<UUID> {
        var ids: Set<UUID> = [id]
        for kid in children(of: id) { ids.formUnion(subtreeIDs(kid.id)) }
        return ids
    }

    /// Moves a top-level task (with its subtasks) next to another top-level task.
    /// Dragging down places it after the target; dragging up places it before. Crossing sections changes its section.
    func reorder(_ draggedID: UUID, onto targetID: UUID) {
        guard draggedID != targetID,
              let dragged = items.first(where: { $0.id == draggedID }), dragged.parentID == nil,
              let target = items.first(where: { $0.id == targetID }), target.parentID == nil,
              let draggedIndex = items.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = items.firstIndex(where: { $0.id == targetID }) else { return }

        let movingDown = draggedIndex < targetIndex
        let movingIDs = subtreeIDs(draggedID)
        var block = items.filter { movingIDs.contains($0.id) }
        for i in block.indices { block[i].isBacklog = target.isBacklog }
        let rest = items.filter { !movingIDs.contains($0.id) }

        let insertAt: Int
        if movingDown {
            let targetIDs = subtreeIDs(targetID)
            guard let last = rest.lastIndex(where: { targetIDs.contains($0.id) }) else { return }
            insertAt = last + 1
        } else {
            guard let first = rest.firstIndex(where: { $0.id == targetID }) else { return }
            insertAt = first
        }
        var result = rest
        result.insert(contentsOf: block, at: insertAt)
        items = result
    }

    /// Moves a top-level task (with its subtasks) to the end of the Today or Backlog section.
    func moveToEnd(_ draggedID: UUID, backlog: Bool) {
        guard let dragged = items.first(where: { $0.id == draggedID }), dragged.parentID == nil else { return }
        let movingIDs = subtreeIDs(draggedID)
        var block = items.filter { movingIDs.contains($0.id) }
        for i in block.indices { block[i].isBacklog = backlog }
        let rest = items.filter { !movingIDs.contains($0.id) }
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

    /// Sets a task's planned rivers. A parent splits its total evenly across its subtasks.
    /// Changing a subtask updates its parent's total to the sum of its subtasks.
    func setEstimate(_ id: UUID, to value: Double) {
        distribute(id, total: max(0, value))
        refreshParents(from: id)
    }

    /// Adds or removes a fraction of a river.
    func adjustEstimate(_ id: UUID, by delta: Double) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        setEstimate(id, to: max(0, estimate(of: item) + delta))
    }

    /// Logs one finished river on a task (less if the task needs less than a full one).
    func logRiver(_ id: UUID) {
        update(id) {
            let remaining = $0.estimate - $0.spent
            if remaining > 0 { $0.spent += min(1, remaining) }
        }
    }

    private func distribute(_ id: UUID, total: Double) {
        update(id) { $0.estimate = total }
        let kids = children(of: id)
        guard !kids.isEmpty else { return }
        for kid in kids {
            distribute(kid.id, total: total / Double(kids.count))
        }
    }

    private func refreshParents(from id: UUID) {
        var current = items.first { $0.id == id }?.parentID
        while let parentID = current {
            let total = children(of: parentID).reduce(0.0) { $0 + estimate(of: $1) }
            update(parentID) { $0.estimate = total }
            current = items.first { $0.id == parentID }?.parentID
        }
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
