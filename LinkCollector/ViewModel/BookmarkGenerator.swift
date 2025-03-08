//
//  BookmarkGenerator.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/8/25.
//

import Foundation
import os

class BookmarkGenerator {
    private let logger = Logger()
    
    private let emptyTagName = ""
    private let links: [LinkEntity]
    private var linksByTag: [String: [LinkEntity]] = [:]
    
    init(links: [LinkEntity]) {
        self.links = links
        
        populateLinksByTag()
    }
    
    private func populateLinksByTag() -> Void {
        for link in links {
            if let tags = link.tags, tags.count > 0 {
                for tag in tags {
                    if let tag = tag as? TagEntity, let tagName = tag.name {
                        if var existingLinks = linksByTag[tagName] {
                            existingLinks.append(link)
                            linksByTag[tagName] = existingLinks
                        } else {
                            linksByTag[tagName] = [link]
                        }
                    } else {
                        logger.log("Found a link with an invalid tag=\(String(describing: tag), privacy: .public): link=\(link)")
                    }
                }
            } else {
                if var existingLinks = linksByTag[emptyTagName] {
                    existingLinks.append(link)
                    linksByTag[emptyTagName] = existingLinks
                } else {
                    linksByTag[emptyTagName] = [link]
                }
            }
        }
    }
    
    func getBookmarkFile() -> String {
        var contents = [String]()
        contents.append("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
        contents.append("<HTML>")
        contents.append("<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">")
        contents.append("<TITLE>Bookmarks</TITLE>")
        contents.append("<H1>Bookmarks</H1>")
        
        for (tagName, links) in linksByTag.sorted(by: { $0.key < $1.key }) {
            contents.append("<DT><H3>\(tagName)</H3>")
            contents.append("<DL><p>")
            
            for link in links {
                if let title = link.title, let url = link.url {
                    contents.append("<DT><A HREF=\"\(url.absoluteString)\">\(title)</A>")
                }
            }
            
            contents.append("</DL><p>")
        }
        
        contents.append("</HTML>")
        
        return contents.joined(separator: "\n")
    }
}
