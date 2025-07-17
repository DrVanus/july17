import Foundation
import Combine

/// Polls CoinGecko’s REST API for live prices of multiple coins every interval and allows single-symbol streaming.
final class LivePriceManager {
    static let shared = LivePriceManager()

    // MARK: - Batched Polling

    /// Emits a mapping of symbol -> USD price
    private let priceSubject = PassthroughSubject<[String: Double], Never>()

    /// Batched publisher for all symbols
    var publisher: AnyPublisher<[String: Double], Never> {
        priceSubject.eraseToAnyPublisher()
    }

    private var timer: Timer?
    private let geckoIDMap: [String: String] = [
        "btc":"bitcoin","eth":"ethereum","bnb":"binancecoin","usdt":"tether",
        "usdc":"usd-coin","ada":"cardano","xrp":"ripple","sol":"solana",
        "doge":"dogecoin","matic":"matic-network","dot":"polkadot","avax":"avalanche-2",
        "trx":"tron","bch":"bitcoin-cash","xlm":"stellar","link":"chainlink",
        "sui":"sui","wsteth":"wrapped-steth","wbtc":"wrapped-bitcoin","steth":"staked-ether",
        "hype":"hyperliquid","leo":"leo-token"
    ]

    /// Start polling multiple symbols in batch
    func startPolling(ids: [String], interval: TimeInterval = 5) {
        stopPolling()
        fetchPrices(for: ids)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchPrices(for: ids)
        }
    }

    /// Stop the polling timer
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// Fetch prices for given symbols with retry
    private func fetchPrices(for symbols: [String]) {
        let idList = symbols.map { geckoIDMap[$0.lowercased()] ?? $0.lowercased() }
                             .joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(idList)&vs_currencies=usd") else {
            return
        }

        Task {
            for attempt in 1...3 {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let json = try JSONDecoder().decode([String: [String: Double]].self, from: data)
                    let prices: [String: Double] = json.compactMapKeys { coinID, dict in
                        guard let usd = dict["usd"] else { return nil }
                        let symbol = symbols.first(where: {
                            (geckoIDMap[$0.lowercased()] ?? $0.lowercased()) == coinID
                        }) ?? coinID
                        return (symbol.lowercased(), usd)
                    }
                    priceSubject.send(prices)
                    break
                } catch {
                    if attempt == 3 {
                        print("🔴 LivePriceManager fetch failed after 3 attempts:", error)
                    } else {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
        }
    }

    // MARK: - Single-Symbol Streaming

    /// Emits just one coin’s USD price
    private let singlePriceSubject = PassthroughSubject<Double, Never>()
    private var singleSubscription: AnyCancellable?

    /// Stream of live price for a single symbol
    var pricePublisher: AnyPublisher<Double, Never> {
        singlePriceSubject.eraseToAnyPublisher()
    }

    /// Begin streaming live updates for a single symbol
    func connect(symbol: String) {
        singleSubscription = publisher
            .compactMap { $0[symbol.lowercased()] }
            .removeDuplicates()
            .sink { [weak self] price in
                self?.singlePriceSubject.send(price)
            }
    }

    /// Stop the single-symbol stream
    func disconnect() {
        singleSubscription?.cancel()
        singleSubscription = nil
    }
}

private extension Dictionary {
    /// Helper to map entries and drop nil values
    func compactMapKeys<K, V>(_ transform: (Key, Value) -> (K, V)?) -> [K: V] {
        var result = [K: V]()
        for (key, value) in self {
            if let (newKey, newValue) = transform(key, value) {
                result[newKey] = newValue
            }
        }
        return result
    }
}
