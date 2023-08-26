//
//  HTMLParser.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/20/20.
//

import Foundation
import SwiftSoup
import os

class HTMLParser {
    private let logger = Logger()
    
    var document: Document?
    var title = ""
    var ogTitle = ""
    
    var titleToReturn: String {
        if self.ogTitle != "" {
            return self.ogTitle
        } else if self.title != "" {
            return self.title
        } else {
            return ""
        }
    }
    
    func parse(url: URL, html: String, completionHandler: @escaping (_ result: String?) -> Void) {
        do {
            self.document = try SwiftSoup.parse(html)
        } catch Exception.Error(let type, let message) {
            logger.log("Caught an error: \(String(describing: type), privacy: .public) - \(String(describing: message), privacy: .public)")
            completionHandler(nil)
        } catch {
            logger.log("Cannot initialize HTMLParser for url = \(url, privacy: .public)")
            completionHandler(nil)
        }
        
        if self.document != nil {
            do {
                let titleTags = try document!.select("title")
                for titleTag in titleTags {
                    let titleText = try titleTag.text()
                    self.title = titleText
                }
            } catch {
                logger.log("Cannot find any title tags")
            }
            
            do {
                let metaTags = try document!.select("meta")
                
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
        
        if let host = url.host {
            if host.contains("youtube.com") {
                findYouTubeTitle(url) { result in
                    self.ogTitle = result.title
                    completionHandler(self.titleToReturn)
                }
            } else {
                completionHandler(titleToReturn)
            }
        } else {
            completionHandler(titleToReturn)
        }
        
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
        
        let request = URLRequest(url: url)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard (error == nil) else {
                self.logger.log("There was an error with your request: \(error!.localizedDescription, privacy: .public)")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                let statusCode = (response as? HTTPURLResponse)!.statusCode
                self.logger.log("The status code was not between 200 and 299: \(statusCode, privacy: .public)")
                return
            }
            
            guard let data = data else {
                self.logger.log("There was no data downloaded")
                return
            }
            
            self.logger.log("data = \(data, privacy: .public)")
            var youTubeOMebed: YouTubeOEmbed?
            do {
                youTubeOMebed = try JSONDecoder().decode(YouTubeOEmbed.self, from: data)
            } catch {
                self.logger.log("Cannot parse data: \(data, privacy: .public)")
            }
            
            guard let oEmbed = youTubeOMebed else {
                self.logger.log("Decoding JSON failed: \(String(describing: youTubeOMebed), privacy: .public)")
                return
            }
                
            completionHandler(oEmbed)
        }
        
        task.resume()
    }
}
