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
    var title: Title?
    var ogTitle: Title?
    
    init(url: URL) {
        do {
            let html = try String(contentsOf: url)
            self.document = try SwiftSoup.parse(html)
        } catch Exception.Error(let type, let message) {
            print("Caught an error: \(type) - \(message)")
        } catch {
            print("Cannot initialize HTMLParser for url = \(url)")
        }
        
        if self.document != nil {
            do {
                let titleTags = try document!.select("title")
                
                for titleTag in titleTags {
                    let titleText = try titleTag.text()
                    self.title = Title(text: titleText)
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
                        self.ogTitle = Title(text: content)
                    }
                }
            } catch {
                print("Cannot find any title tags")
            }
        }
    }
}
