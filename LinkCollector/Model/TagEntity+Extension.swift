//
//  TagEntity+Extension.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/18/21.
//

import Foundation
import CoreData

extension TagEntity {
    static func create(name: String?, link: LinkEntity?, context: NSManagedObjectContext) {
        let newTag = TagEntity(context: context)
        newTag.id = UUID()
        newTag.name = name
        newTag.created = Date()
        
        if link != nil {
            newTag.addToLinks(link!)
        }
        
        context.saveContext()
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        created = Date()
    }
    
}
