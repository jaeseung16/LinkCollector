//
//  Title.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/20/20.
//

import Foundation

struct Title: Hashable {
    let id = UUID()
    let text: String
}

class TitleFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        if obj is Title {
            let title = obj as! Title
            return title.text
        } else {
            return nil
        }
    }
}
