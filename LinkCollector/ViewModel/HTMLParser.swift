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
    
    // Elements that never contribute to the readable content of a page. The landmark roles cover
    // the site chrome of pages that mark it up with divs instead of nav/aside/header/footer tags.
    private static let noiseSelector = "script, style, noscript, template, nav, aside, form, iframe, svg, [role=navigation], [role=banner], [role=complementary], [role=contentinfo], [role=search]"
    // Containers that, when present, usually hold the article body itself
    private static let contentSelector = "article, main, [role=main]"
    // Below this length a candidate container is treated as boilerplate and the whole body is used instead
    private static let minimumContentLength = 200
    
    private let logger = Logger()
    
    private var document: Document?
    private var title = HTMLParser.emptyString
    private var ogTitle = HTMLParser.emptyString
    private var ogDescription = HTMLParser.emptyString
    private var metaDescription = HTMLParser.emptyString
    private var bodyText = HTMLParser.emptyString
    
    private var titleToUse: String {
        return !ogTitle.isEmpty ? ogTitle : (!title.isEmpty ? title : HTMLParser.emptyString)
    }
    
    // og:description is what a page says about itself; <meta name="description"> is the older form
    // of the same thing, and plenty of pages still ship only that one.
    private var descriptionToUse: String {
        return !ogDescription.isEmpty ? ogDescription : metaDescription
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
    
    private func populateDescription(document: Document) -> Void {
        do {
            let metaTags = try document.select("meta")
            
            for metaTag in metaTags {
                let property = try metaTag.attr("property")
                let name = try metaTag.attr("name")
                
                if property == "og:description" {
                    self.ogDescription = try metaTag.attr("content")
                } else if name == "description" {
                    self.metaDescription = try metaTag.attr("content")
                }
            }
        } catch {
            logger.log("Cannot find any meta tags")
        }
    }
    
    private func populateBodyText(document: Document) -> Void {
        do {
            try document.select(HTMLParser.noiseSelector).remove()
            
            let candidates = try document.select(HTMLParser.contentSelector).map { try $0.text() }
            
            if let content = candidates.max(by: { $0.count < $1.count }), content.count >= HTMLParser.minimumContentLength {
                self.bodyText = content
            } else if let body = document.body() {
                self.bodyText = try body.text()
            } else {
                logger.log("Cannot find a body tag")
            }
        } catch Exception.Error(let type, let message) {
            logger.log("Caught an error: \(String(describing: type), privacy: .public) - \(String(describing: message), privacy: .public)")
        } catch {
            logger.log("Cannot extract the body text")
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
    
    // Extracts the readable text of the page to feed a summarizer. Parses the html again
    // rather than reusing any document left over from parse(url:html:), since the noise
    // elements are stripped from the document in place.
    func parseBodyText(url: URL, html: String) -> String? {
        if !populateDocument(url: url, html: html) {
            return nil
        }
        
        if let document = document {
            populateBodyText(document: document)
        }
        
        return bodyText.isEmpty ? nil : bodyText
    }
    
    // The description the page publishes about itself, used as a summary when the on-device model
    // is unavailable or won't summarize the page.
    func parseDescription(url: URL, html: String) -> String? {
        if !populateDocument(url: url, html: html) {
            return nil
        }
        
        if let document = document {
            populateDescription(document: document)
        }
        
        let description = descriptionToUse.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
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
