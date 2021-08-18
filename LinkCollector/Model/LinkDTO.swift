//
//  LinkDTO.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/18/21.
//

import Foundation

struct LinkDTO: CustomStringConvertible {
    var id: UUID
    var title: String
    var note: String
    
    var description: String {
        return "LinkDTO[id: \(id), title: \(title), note: \(note)]"
    }
}
