//
//  PriceService.swift
//  CryptoSage
//
//  Created by DM on 5/28/25.
//


import Combine
import Foundation

/// Protocol for services that publish live price updates for given symbols.
protocol PriceService {
  func pricePublisher(for symbols: [String], interval: TimeInterval)
    -> AnyPublisher<[String: Double], Never>
}

/// Live implementation using Binance WebSocket for real-time price updates.
final class BinanceWebSocketPriceService: PriceService {
    private var cancellables = Set<AnyCancellable>()

    func pricePublisher(for symbols: [String], interval: TimeInterval) -> AnyPublisher<[String: Double], Never> {
        let symbolPublishers = symbols.map { symbol in
            LivePriceManager.shared.pricePublisher
                .map { price in
                    [symbol.lowercased(): price]
                }
        }
        // Merge all symbol publishers into one stream and accumulate latest values
        return Publishers.MergeMany(symbolPublishers)
            .scan([String: Double]()) { latest, updateDict in
                var merged = latest
                for (sym, price) in updateDict {
                    merged[sym] = price
                }
                return merged
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

/// Live implementation using CoinGecko's simple price API to emit up-to-date prices.
final class CoinGeckoPriceService: PriceService {
  func pricePublisher(
    for symbols: [String],
    interval: TimeInterval
  ) -> AnyPublisher<[String: Double], Never> {
    let ids = symbols.joined(separator: ",")
    let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?vs_currency=usd&ids=\(ids)")!

    return Timer.publish(every: interval, on: .main, in: .common)
      .autoconnect()
      .flatMap { _ in
        URLSession.shared.dataTaskPublisher(for: url)
          .map(\.data)
          .decode(type: [String: [String: Double]].self, decoder: JSONDecoder())
          .map { dict in
            dict.compactMapValues { $0["usd"] }
          }
          .replaceError(with: [:])
      }
      .eraseToAnyPublisher()
  }
}
