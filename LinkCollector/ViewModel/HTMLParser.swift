//
//  HTMLParser.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/20/20.
//

import Foundation
import SwiftSoup

class HTMLParser {
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
            print("Caught an error: \(type) - \(message)")
            completionHandler(nil)
        } catch {
            print("Cannot initialize HTMLParser for url = \(url)")
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
                print("Cannot find any title tags")
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
                print("Cannot find any title tags")
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
            print("Check if url belongs to YouTube: \(youTubeUrl)")
            return
        }
        
        print("url = \(url)")
        
        let request = URLRequest(url: url)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard (error == nil) else {
                print("There was an error with your request: \(error!)")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                let statusCode = (response as? HTTPURLResponse)!.statusCode
                print("The status code was not between 200 and 299: \(statusCode)")
                return
            }
            
            guard let data = data else {
                print("There was no data downloaded")
                return
            }
            
            print("data = \(data)")
            var youTubeOMebed: YouTubeOEmbed?
            do {
                youTubeOMebed = try JSONDecoder().decode(YouTubeOEmbed.self, from: data)
            } catch {
                print("Cannot parse data: \(data)")
            }
            
            guard let oEmbed = youTubeOMebed else {
                print("Decoding JSON failed: \(String(describing: youTubeOMebed))")
                return
            }
                
            completionHandler(oEmbed)
        }
        
        task.resume()
    }
}
