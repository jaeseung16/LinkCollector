//
//  LinkCollectorDownloader.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 9/3/23.
//

import Foundation
import os
import FaviconFinder

actor LinkCollectorDownloader {
    private static let logger = Logger()
    
    private let urlString: String
    
    init(url: String) {
        self.urlString = url
    }
    
    public func getUrlAndHtml() async -> (URL?, String?) {
        var url: URL?
        var html: String?
        
        if isValid() {
            (url, html) = await download()
        } else {
            (url, html) = await downloadHttps()
            if html == nil {
                (url, html) = await downloadHttp()
            }
        }
        return (url, html)
    }
    
    private func download() async -> (URL?, String?) {
        guard let url = URL(string: urlString) else {
            LinkCollectorDownloader.logger.log("Invalid url: \(self.urlString, privacy: .public)")
            return (nil, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return (url, String(data: data, encoding: .utf8))
        } catch {
            LinkCollectorDownloader.logger.log("Error while downloading data from \(self.urlString)")
            return (url, nil)
        }
    }
    
    private func downloadHttps() async -> (URL?, String?) {
        guard let url = URL(string: "https://\(urlString)") else {
            LinkCollectorDownloader.logger.log("Invalid url: \(self.urlString, privacy: .public)")
            return (nil, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return (url, String(data: data, encoding: .utf8))
        } catch {
            LinkCollectorDownloader.logger.log("Error while downloading data from \(self.urlString)")
            return (url, nil)
        }
    }
    
    private func downloadHttp() async -> (URL?, String?) {
        guard let url = URL(string: "http://\(urlString)") else {
            LinkCollectorDownloader.logger.log("Invalid url: \(self.urlString, privacy: .public)")
            return (nil, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return (url, String(data: data, encoding: .utf8))
        } catch {
            LinkCollectorDownloader.logger.log("Error while downloading data from \(self.urlString)")
            return (url, nil)
        }
    }
    
    public func isValid() -> Bool {
        guard let urlComponent = URLComponents(string: urlString), let scheme = urlComponent.scheme else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
    
    public func findFavicon() async -> Data? {
        guard let url = URL(string: urlString) else {
            LinkCollectorDownloader.logger.log("Invalid url: \(self.urlString, privacy: .public)")
            return nil
        }
        
        do {
            let favicon = try await FaviconFinder(url: url, configuration: .init(preferredSource: .ico, acceptHeaderImage: true))
                .fetchFaviconURLs()
                .download()
                .largest()
            return favicon.image?.data
        } catch {
            LinkCollectorDownloader.logger.log("Cannot find favicon from \(self.urlString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
