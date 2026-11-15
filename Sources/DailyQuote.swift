import Foundation

struct Quote: Equatable {
    let content: String
    let author: String
    let field: String
}

/// One quote per day from a built-in collection that mixes philosophy, science, computing and literature.
/// No network needed. The app checks every 10 minutes and whenever it becomes active,
/// so the quote changes at midnight even if the app stays open.
@MainActor
final class DailyQuoteStore: ObservableObject {
    @Published private(set) var quote: Quote

    private static let refreshInterval: TimeInterval = 600
    private var refreshTimer: Timer?

    init() {
        quote = DailyQuoteStore.quoteForToday()
        startAutoRefresh()
    }

    /// Re-checks periodically, so a new day brings a new quote without a restart.
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: DailyQuoteStore.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshIfNeeded() }
        }
    }

    func refreshIfNeeded() async {
        let today = DailyQuoteStore.quoteForToday()
        if today != quote { quote = today }
    }

    /// Steps through the collection with a stride, so neighbouring days come from different fields.
    private static func quoteForToday() -> Quote {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let stride = collection.count % 13 == 0 ? 7 : 13
        return collection[(day * stride) % collection.count]
    }

    private static let collection: [Quote] = [
        // Philosophy
        Quote(content: "No man ever steps in the same river twice, for it is not the same river and he is not the same man.", author: "Heraclitus", field: "Philosophy"),
        Quote(content: "The impediment to action advances action. What stands in the way becomes the way.", author: "Marcus Aurelius", field: "Stoicism"),
        Quote(content: "Men are disturbed not by things, but by the views which they take of them.", author: "Epictetus", field: "Stoicism"),
        Quote(content: "While we are postponing, life speeds by.", author: "Seneca", field: "Stoicism"),
        Quote(content: "Dare to know! Have the courage to use your own understanding.", author: "Immanuel Kant", field: "Philosophy"),
        Quote(content: "The limits of my language mean the limits of my world.", author: "Ludwig Wittgenstein", field: "Philosophy"),
        Quote(content: "One must still have chaos in oneself to be able to give birth to a dancing star.", author: "Friedrich Nietzsche", field: "Philosophy"),
        Quote(content: "Learning without thought is labor lost; thought without learning is perilous.", author: "Confucius", field: "Philosophy"),
        Quote(content: "Man is condemned to be free.", author: "Jean-Paul Sartre", field: "Existentialism"),
        Quote(content: "The unexamined life is not worth living.", author: "Socrates", field: "Philosophy"),
        Quote(content: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Will Durant, on Aristotle", field: "Philosophy"),
        Quote(content: "Attention is the rarest and purest form of generosity.", author: "Simone Weil", field: "Philosophy"),
        Quote(content: "The good life is one inspired by love and guided by knowledge.", author: "Bertrand Russell", field: "Philosophy"),

        // Science
        Quote(content: "We are a way for the cosmos to know itself.", author: "Carl Sagan", field: "Science"),
        Quote(content: "The first principle is that you must not fool yourself, and you are the easiest person to fool.", author: "Richard Feynman", field: "Science"),
        Quote(content: "The important thing is not to stop questioning. Curiosity has its own reason for existing.", author: "Albert Einstein", field: "Science"),
        Quote(content: "If I have seen further, it is by standing on the shoulders of giants.", author: "Isaac Newton", field: "Science"),
        Quote(content: "Nothing in life is to be feared, it is only to be understood.", author: "Marie Curie", field: "Science"),
        Quote(content: "The book of nature is written in the language of mathematics.", author: "Galileo Galilei", field: "Science"),
        Quote(content: "Chance favors only the prepared mind.", author: "Louis Pasteur", field: "Science"),
        Quote(content: "It is not knowledge, but the act of learning, not possession but the act of getting there, which grants the greatest enjoyment.", author: "Carl Friedrich Gauss", field: "Mathematics"),
        Quote(content: "The saddest aspect of life right now is that science gathers knowledge faster than society gathers wisdom.", author: "Isaac Asimov", field: "Science"),

        // Computing
        Quote(content: "We can only see a short distance ahead, but we can see plenty there that needs to be done.", author: "Alan Turing", field: "Computing"),
        Quote(content: "The most dangerous phrase in the language is: we've always done it this way.", author: "Grace Hopper", field: "Computing"),
        Quote(content: "Premature optimization is the root of all evil.", author: "Donald Knuth", field: "Computing"),
        Quote(content: "Simplicity is prerequisite for reliability.", author: "Edsger Dijkstra", field: "Computing"),

        // Literature and humanities
        Quote(content: "All that you touch you change. All that you change changes you.", author: "Octavia E. Butler", field: "Literature"),
        Quote(content: "It is good to have an end to journey toward; but it is the journey that matters, in the end.", author: "Ursula K. Le Guin", field: "Literature"),
        Quote(content: "A woman must have money and a room of her own if she is to write fiction.", author: "Virginia Woolf", field: "Literature"),
        Quote(content: "I have always imagined that Paradise will be a kind of library.", author: "Jorge Luis Borges", field: "Literature"),
        Quote(content: "Tudo vale a pena se a alma não é pequena.", author: "Fernando Pessoa", field: "Literatura"),
        Quote(content: "Viver é muito perigoso.", author: "João Guimarães Rosa", field: "Literatura"),
        Quote(content: "Ninguém educa ninguém, ninguém educa a si mesmo, os homens se educam entre si, mediatizados pelo mundo.", author: "Paulo Freire", field: "Educação"),
        Quote(content: "Es ist nicht genug zu wissen, man muss auch anwenden; es ist nicht genug zu wollen, man muss auch tun.", author: "Johann Wolfgang von Goethe", field: "Literatur")
    ]
}
