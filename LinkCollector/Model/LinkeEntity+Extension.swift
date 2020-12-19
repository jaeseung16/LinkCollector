//
//  LinkeEntity+Extension.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import Foundation
import CoreData

extension LinkEntity {
    static func create(title: String?, url: String?, latitude: String?, longitude: String?, context: NSManagedObjectContext) {
        let newLink = LinkEntity(context: context)
        newLink.id = UUID()
        newLink.title = title?.isEmpty == false ? title! : nil
        newLink.url = url?.isEmpty == false ? URL(string: url!) : nil
        newLink.latitude = latitude?.isEmpty == false ? (Double(latitude!) ?? 0.0) : 0.0
        newLink.longitude = longitude?.isEmpty == false ? (Double(longitude!) ?? 0.0) : 0.0
        newLink.created = Date()
        context.saveContext()
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        created = Date()
    }
    
}

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
}
