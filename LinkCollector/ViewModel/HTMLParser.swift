//
//  HTMLParser.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/20/20.
//

import Foundation
import SwiftSoup
import os

actor HTMLParser {
    private static let emptyString = ""
    
    private let logger = Logger()
    
    private var document: Document?
    private var title = HTMLParser.emptyString
    private var ogTitle = HTMLParser.emptyString
    
    private var titleToUse: String {
        return !ogTitle.isEmpty ? ogTitle : (!title.isEmpty ? title : HTMLParser.emptyString)
    }
    
    func parse(url: URL, html: String, completionHandler: @escaping (_ result: String?) -> Void) -> Void {
        if !populateDocument(url: url, html: html) {
            completionHandler(nil)
        }
        
        if let document = document {
            populateTitle(document: document)
            populateOgTitle(document: document)
        }
        
        Task {
            if let host = url.host {
                if host.contains("youtube.com") {
                    await populateOgTitle(url)
                    completionHandler(titleToUse)
                } else {
                    completionHandler(titleToUse)
                }
            } else {
                completionHandler(titleToUse)
            }
        }
    }
    
    func parseTitle(url: URL, html: String) async -> String? {
        if !populateDocument(url: url, html: html) {
            return nil
        }
        
        if let document = document {
            populateTitle(document: document)
            populateOgTitle(document: document)
        }
        
        if let host = url.host, host.contains("youtube.com") {
            await populateOgTitle(url)
        }
        
        return titleToUse
    }
    
    private func populateDocument(url: URL, html: String) -> Bool {
        do {
            self.document = try SwiftSoup.parse(html)
            return true
        } catch Exception.Error(let type, let message) {
            logger.log("Caught an error: \(String(describing: type), privacy: .public) - \(String(describing: message), privacy: .public)")
            return false
        } catch {
            logger.log("Cannot initialize HTMLParser for url = \(url, privacy: .public)")
            return false
        }
    }
    
    private func populateTitle(document: Document) -> Void {
        do {
            let titleTags = try document.select("title")
            for titleTag in titleTags {
                let titleText = try titleTag.text()
                self.title = titleText
            }
        } catch {
            logger.log("Cannot find any title tags")
        }
    }
    
    private func populateOgTitle(document: Document) -> Void {
        do {
            let metaTags = try document.select("meta")
            
            for metaTag in metaTags {
                let property = try metaTag.attr("property")
                
                if property == "og:title" {
                    let content = try metaTag.attr("content")
                    self.ogTitle = content
                }
            }
        } catch {
            logger.log("Cannot find any title tags")
        }
    }
    
    private func populateOgTitle(_ url: URL) async -> Void {
        do {
            self.ogTitle = try await findTitle(youTubeUrl: url)
        } catch {
            logger.log("Can't find the title from \(url): \(error.localizedDescription, privacy: .public)")
            self.ogTitle = HTMLParser.emptyString
        }
    }
    
    func parse(url: URL, html: String) async -> String? {
        if !populateDocument(url: url, html: html) {
            return nil
        }
        
        if let document = document {
            populateTitle(document: document)
            populateOgTitle(document: document)
        }
        
        if let host = url.host, host.contains("youtube.com") {
            await populateOgTitle(url)
        }
        
        return titleToUse
    }
    
    private func findYouTubeTitle(_ youTubeUrl: URL, completionHandler: @escaping (_ result: YouTubeOEmbed) -> Void) {
        guard
            let escapedString = youTubeUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://www.youtube.com/oembed?url=\(escapedString)")
        else {
            logger.log("Check if url belongs to YouTube: \(youTubeUrl, privacy: .public)")
            return
        }
        
        logger.log("url = \(url, privacy: .public)")
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                self.logger.log("data = \(data, privacy: .public)")
                
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                    let statusCode = (response as? HTTPURLResponse)!.statusCode
                    self.logger.log("The status code was not between 200 and 299: \(statusCode, privacy: .public)")
                    throw HTMLParserError.invalidServerResponse
                }
                
                let youTubeOMebed = try JSONDecoder().decode(YouTubeOEmbed.self, from: data)
                    
                completionHandler(youTubeOMebed)
            } catch {
                self.logger.log("Error while finding youtube title for url=\(url): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func findTitle(youTubeUrl: URL) async throws -> String {
        guard
            let escapedString = youTubeUrl.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://www.youtube.com/oembed?url=\(escapedString)")
        else {
            logger.log("Check if url belongs to YouTube: \(youTubeUrl, privacy: .public)")
            throw HTMLParserError.invalidURL
        }
        
        logger.log("url=\(url, privacy: .public)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 else {
            logger.log("The status code was not between 200 and 299: \(response, privacy: .public)")
            throw HTMLParserError.invalidServerResponse
        }
        
        self.logger.log("data=\(data, privacy: .public)")
        
        guard let youTubeOEmbed = try? JSONDecoder().decode(YouTubeOEmbed.self, from: data) else {
            self.logger.log("Cannot parse data: \(data, privacy: .public)")
            throw HTMLParserError.cannotParseData
        }
        
        return youTubeOEmbed.title
        
    }
}
