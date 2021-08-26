//
//  NSManagedObject+Extension.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/26/21.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    func saveContext() {
        do {
            try save()
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }

    func delete(_ links: [LinkEntity]) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "LinkEntity")
        request.predicate = NSPredicate(format: "id IN %@", links.map { $0.id?.uuidString })
        do {
            let results = (try fetch(request) as? [LinkEntity]) ?? []
            results.forEach { delete($0) }
        } catch {
            print("Failed removing provided objects")
            return
        }
        saveContext()
    }
    
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
