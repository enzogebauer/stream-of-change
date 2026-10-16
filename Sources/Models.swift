import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var parentID: UUID?
    var estimate: Int      // pomodoros planned
    var spent: Int         // pomodoros finished
    var isBacklog: Bool    // false = Today, true = Backlog

    init(id: UUID = UUID(), title: String, isDone: Bool = false, parentID: UUID? = nil,
         estimate: Int = 1, spent: Int = 0, isBacklog: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.parentID = parentID
        self.estimate = estimate
        self.spent = spent
        self.isBacklog = isBacklog
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
    }
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
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = decoded
        } else {
            items = TaskStore.seed
        }
    }

    /// Top-level tasks in the Today or Backlog section.
    func roots(backlog: Bool) -> [TodoItem] {
        items.filter { $0.parentID == nil && $0.isBacklog == backlog }
    }

    func children(of id: UUID) -> [TodoItem] { items.filter { $0.parentID == id } }

    /// Pomodoros still needed across unfinished Today tasks.
    var pendingPomodoros: Int {
        items.filter { !$0.isDone && !$0.isBacklog }.reduce(0) { $0 + max($1.estimate - $1.spent, 0) }
    }

    func add(_ title: String, parent: UUID? = nil, backlog: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let inheritedBacklog = parent.flatMap { id in items.first { $0.id == id }?.isBacklog } ?? backlog
        items.append(TodoItem(title: trimmed, parentID: parent, isBacklog: inheritedBacklog))
    }

    func toggle(_ id: UUID) {
        update(id) { $0.isDone.toggle() }
    }

    /// Moves a task and its subtasks between Today and Backlog.
    func move(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let target = !item.isBacklog
        for i in items.indices where items[i].id == id || items[i].parentID == id {
            items[i].isBacklog = target
        }
    }

    func update(_ id: UUID, _ change: (inout TodoItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id || $0.parentID == id }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
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
