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

extension NSManagedObjectContext {
    func delete(_ tags: [TagEntity]) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TagEntity")
        request.predicate = NSPredicate(format: "id IN %@", tags.map { $0.id?.uuidString })
        do {
            let results = (try fetch(request) as? [TagEntity]) ?? []
            results.forEach { delete($0) }
        } catch {
            print("Failed removing provided objects")
            return
        }
        saveContext()
    }
}
