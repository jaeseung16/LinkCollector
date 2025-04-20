//
//  YouTube.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/24/20.
//

import Foundation

struct YouTubeOEmbed: Codable, Sendable {
    let title: String
    let type: String
    let providerName: String
    let thumbnailUrl: String
    let authorName: String

    enum CodingKeys: String, CodingKey {
        case title
        case type
        case providerName = "provider_name"
        case thumbnailUrl = "thumbnail_url"
        case authorName = "author_name"
    }
}
