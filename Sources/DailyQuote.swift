import Foundation

struct Quote: Equatable {
    let content: String
    let author: String
}

/// One quote per day from the free Quotable API (philosophy, science, wisdom).
/// The day's quote is cached. The app checks every 10 minutes and whenever it becomes active,
/// so the quote changes at midnight even if the app stays open.
@MainActor
final class DailyQuoteStore: ObservableObject {
    @Published private(set) var quote: Quote

    private static let dayKey = "quoteDay"
    private static let textKey = "quoteText"
    private static let authorKey = "quoteAuthor"
    private static let refreshInterval: TimeInterval = 600

    /// Used when the API can't be reached. Rotates by day of the year.
    private static let fallback: [Quote] = [
        Quote(content: "No man ever steps in the same river twice.", author: "Heraclitus"),
        Quote(content: "The impediment to action advances action. What stands in the way becomes the way.", author: "Marcus Aurelius"),
        Quote(content: "Somewhere, something incredible is waiting to be known.", author: "Carl Sagan"),
        Quote(content: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Aristotle")
    ]

    private var refreshTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: DailyQuoteStore.dayKey) == DailyQuoteStore.todayKey(),
           let text = defaults.string(forKey: DailyQuoteStore.textKey),
           let author = defaults.string(forKey: DailyQuoteStore.authorKey) {
            quote = Quote(content: text, author: author)
        } else {
            quote = DailyQuoteStore.fallback[DailyQuoteStore.dayIndex() % DailyQuoteStore.fallback.count]
        }
        startAutoRefresh()
    }

    /// Re-checks periodically, so a new day brings a new quote without a restart.
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: DailyQuoteStore.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshIfNeeded() }
        }
    }

    /// Fetches today's quote once per day. Offline on a new day, it shows today's built-in quote
    /// instead of yesterday's, and tries the API again at the next check.
    func refreshIfNeeded() async {
        let today = DailyQuoteStore.todayKey()
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: DailyQuoteStore.dayKey) != today else { return }

        if let fresh = await DailyQuoteStore.fetchQuote() {
            defaults.set(today, forKey: DailyQuoteStore.dayKey)
            defaults.set(fresh.content, forKey: DailyQuoteStore.textKey)
            defaults.set(fresh.author, forKey: DailyQuoteStore.authorKey)
            quote = fresh
        } else {
            quote = DailyQuoteStore.fallback[DailyQuoteStore.dayIndex() % DailyQuoteStore.fallback.count]
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
