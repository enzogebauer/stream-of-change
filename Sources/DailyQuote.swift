import Foundation

struct Quote: Equatable {
    let content: String
    let author: String
}

/// One quote per day from the free Quotable API (philosophy, science, wisdom).
/// The day's quote is cached, so it stays the same all day. Offline, a built-in quote is shown.
@MainActor
final class DailyQuoteStore: ObservableObject {
    @Published private(set) var quote: Quote

    private static let dayKey = "quoteDay"
    private static let textKey = "quoteText"
    private static let authorKey = "quoteAuthor"

    /// Used when the API can't be reached. Rotates by day of the year.
    private static let fallback: [Quote] = [
        Quote(content: "No man ever steps in the same river twice.", author: "Heraclitus"),
        Quote(content: "The impediment to action advances action. What stands in the way becomes the way.", author: "Marcus Aurelius"),
        Quote(content: "Somewhere, something incredible is waiting to be known.", author: "Carl Sagan"),
        Quote(content: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Aristotle")
    ]

    init() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: DailyQuoteStore.dayKey) == DailyQuoteStore.todayKey(),
           let text = defaults.string(forKey: DailyQuoteStore.textKey),
           let author = defaults.string(forKey: DailyQuoteStore.authorKey) {
            quote = Quote(content: text, author: author)
        } else {
            quote = DailyQuoteStore.fallback[DailyQuoteStore.dayIndex() % DailyQuoteStore.fallback.count]
        }
    }

    /// Fetches today's quote once. If the request fails, the fallback stays and it retries next launch.
    func refreshIfNeeded() async {
        let today = DailyQuoteStore.todayKey()
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: DailyQuoteStore.dayKey) != today else { return }

        if let fresh = await DailyQuoteStore.fetchQuote() {
            defaults.set(today, forKey: DailyQuoteStore.dayKey)
            defaults.set(fresh.content, forKey: DailyQuoteStore.textKey)
            defaults.set(fresh.author, forKey: DailyQuoteStore.authorKey)
            quote = fresh
        }
    }

    private struct APIQuote: Decodable {
        let content: String
        let author: String
    }

    private static func fetchQuote() async -> Quote? {
        var components = URLComponents(string: "https://api.quotable.io/quotes/random")
        components?.queryItems = [
            URLQueryItem(name: "tags", value: "philosophy|science|wisdom"),
            URLQueryItem(name: "maxLength", value: "160"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let items = try JSONDecoder().decode([APIQuote].self, from: data)
            guard let first = items.first else { return nil }
            return Quote(content: first.content, author: first.author)
        } catch {
            return nil
        }
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func dayIndex() -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }
}
