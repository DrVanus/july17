//
//  CryptoNewsArticle.swift
//  CryptoSage
//
//  Created by DM on 5/26/25.
//


//
// CryptoNewsArticle.swift
// CryptoSage
//

import Foundation

/// Represents a single news article in the CryptoSage app.
struct CryptoNewsArticle: Codable, Identifiable, Equatable {
    /// Unique identifier for SwiftUI lists
    let id: UUID
    
    /// Headline of the article
    let title: String
    
    /// Optional subtitle or summary
    let description: String?
    
    /// Link to the full article
    let url: URL
    
    /// Optional URL to an image
    let urlToImage: URL?

    /// Name of the news source
    let sourceName: String
    
    /// Publication date
    let publishedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case url
        case urlToImage
        case publishedAt
        case sourceName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.url = try container.decode(URL.self, forKey: .url)
        self.urlToImage = try container.decodeIfPresent(URL.self, forKey: .urlToImage)
        self.sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName) ?? "Unknown Source"
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        // Debug: log the raw timestamp string
        print("PublishedAt raw string: \(dateString)")
        
        var parsedDate: Date?
        
        // 1) Try ISO8601 with fractional seconds, full date/time, and colon separators
        let isoFormatter1 = ISO8601DateFormatter()
        isoFormatter1.formatOptions = [
            .withFullDate,
            .withFullTime,
            .withFractionalSeconds,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        parsedDate = isoFormatter1.date(from: dateString)
        
        // 2) If still nil, try ISO8601 without fractional seconds
        if parsedDate == nil {
            let isoFormatter2 = ISO8601DateFormatter()
            isoFormatter2.formatOptions = [
                .withInternetDateTime,
                .withColonSeparatorInTimeZone
            ]
            parsedDate = isoFormatter2.date(from: dateString)
        }
        
        // 3) If still nil, try multiple fallback formats
        if parsedDate == nil {
            let fallbackPatterns = [
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ssZ"
            ]
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            for pattern in fallbackPatterns {
                df.dateFormat = pattern
                if let d = df.date(from: dateString) {
                    parsedDate = d
                    break
                }
            }
        }
        
        // 4) Assign final parsed date or default to now
        if let date = parsedDate {
            self.publishedAt = date
        } else {
            self.publishedAt = Date()
            print("Warning: Failed to parse publishedAt ('\(dateString)'), defaulting to now.")
        }
    }
    
    /// Provides a default UUID when decoding or initializing
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        url: URL,
        urlToImage: URL? = nil,
        sourceName: String = "Unknown Source",
        publishedAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.urlToImage = urlToImage
        self.sourceName = sourceName
        self.publishedAt = publishedAt
    }

    /// Returns a relative time like "1d, 7h", "7h, 26m", or "45m"
    var relativeTime: String {
        let interval = Date().timeIntervalSince(publishedAt)
        let totalMinutes = max(Int(interval / 60), 0)
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else if totalMinutes < 1440 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h, \(minutes)m"
        } else {
            let days = totalMinutes / 1440
            let hours = (totalMinutes % 1440) / 60
            return "\(days)d, \(hours)h"
        }
    }
}
