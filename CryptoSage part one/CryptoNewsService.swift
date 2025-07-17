//
//  NewsAPIResponse 2.swift
//  CryptoSage
//
//  Created by DM on 5/26/25.
//


//
// CryptoNewsService.swift
// CryptoSage
//

import Foundation

// MARK: - NewsAPI Models
struct NewsAPIResponse: Codable {
    let articles: [NewsAPIArticle]
}

struct NewsAPIArticle: Codable {
    let source: NewsAPISource
    let title: String
    let description: String?
    let url: URL
    let urlToImage: URL?
    let publishedAt: Date
}

/// Represents the source object from NewsAPI
struct NewsAPISource: Codable {
    let id: String?
    let name: String?
}

// MARK: - CryptoNews Service
actor CryptoNewsService {
    private let apiKey = "46517a8f35a34c0e88e7c2cc31f63fac"

    /// Helper to perform a URLRequest with retries
    private func fetchDataWithRetry(_ request: URLRequest, retries: Int = 1) async throws -> Data {
        var lastError: Error?
        for attempt in 0...retries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
                return data
            } catch {
                lastError = error
                if (error as NSError).code == NSURLErrorCancelled {
                    throw error
                }
                // Brief pause before retry
                try? await Task.sleep(nanoseconds: 500 * 1_000_000)
            }
        }
        throw lastError!
    }

    /// Fetch a small preview of news (for the home screen)
    func fetchPreviewNews() async throws -> [CryptoNewsArticle] {
        try await fetchNews(page: 5)
    }

    /// Fetch the latest full list of news
    func fetchLatestNews() async throws -> [CryptoNewsArticle] {
        try await fetchNews(page: 20)
    }

    /// Internal helper to call NewsAPI
    func fetchNews(page: Int) async throws -> [CryptoNewsArticle] {
        guard var components = URLComponents(string: "https://newsapi.org/v2/everything") else {
            return []
        }
        components.queryItems = [
            .init(name: "q", value: "crypto"),
            .init(name: "pageSize", value: "\(page)"),
            .init(name: "sortBy", value: "publishedAt")
        ]
        guard let url = components.url else {
            print("🗞️ CryptoNewsService: failed to construct URL from components")
            return []
        }
        // Build a request with a timeout
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 15

        let data = try await fetchDataWithRetry(request, retries: 1)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let apiResponse = try decoder.decode(NewsAPIResponse.self, from: data)
        return apiResponse.articles.map { article in
            CryptoNewsArticle(
                title: article.title,
                description: article.description,
                url: article.url,
                urlToImage: article.urlToImage,
                sourceName: article.source.name ?? "Unknown Source",
                publishedAt: article.publishedAt
            )
        }
    }
}
