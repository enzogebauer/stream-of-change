import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
    var parentID: UUID? = nil
    var estimate: Int = 1   // pomodoros planned
    var spent: Int = 0      // pomodoros finished
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

    var roots: [TodoItem] { items.filter { $0.parentID == nil } }

    func children(of id: UUID) -> [TodoItem] { items.filter { $0.parentID == id } }

    /// Pomodoros still needed across all unfinished tasks.
    var pendingPomodoros: Int {
        items.filter { !$0.isDone }.reduce(0) { $0 + max($1.estimate - $1.spent, 0) }
    }

    func add(_ title: String, parent: UUID? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed, parentID: parent))
    }

    func toggle(_ id: UUID) {
        update(id) { $0.isDone.toggle() }
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
