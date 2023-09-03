//
//  LinkCollectorDownloader.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 9/3/23.
//

import Foundation
import os
import FaviconFinder

class LinkCollectorDownloader {
    private static let logger = Logger()
    
    static func download(from urlString: String) async -> (URL?, String?) {
        guard let url = URL(string: urlString) else {
            logger.log("Invalid url: \(urlString, privacy: .public)")
            return (nil, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return (url, String(data: data, encoding: .utf8))
        } catch {
            logger.log("Error while downloading data from \(url)")
            return (url, nil)
        }
    }
    
    static func isValid(urlString: String) -> Bool {
        guard let urlComponent = URLComponents(string: urlString), let scheme = urlComponent.scheme else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
    
    static func findFavicon(url: URL) async -> Data? {
        do {
            let favicon = try await FaviconFinder(url: url).downloadFavicon()
            return favicon.data
        } catch {
            self.logger.log("Cannot find favicon from \(url, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
