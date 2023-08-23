//
//  LinkeEntity+Extension.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import Foundation
import CoreData

extension LinkEntity {
    static func create(title: String?, url: String?, favicon: Data?, note: String?, latitude: Double, longitude: Double, locality: String?, context: NSManagedObjectContext) -> LinkEntity {
        let newLink = LinkEntity(context: context)
        newLink.id = UUID()
        newLink.title = title?.isEmpty == false ? title! : nil
        newLink.url = url?.isEmpty == false ? URL(string: url!) : nil
        newLink.favicon = favicon
        newLink.note = note?.isEmpty == false ? note! : nil
        newLink.latitude = latitude
        newLink.longitude = longitude
        newLink.locality = locality
        newLink.created = Date()
        newLink.lastupd = Date()
        context.saveContext()
        
        return newLink
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        created = Date()
    }
    
    public func getTagList() -> [TagEntity] {
        self.tags?.compactMap { $0 as? TagEntity) ?? [TagEntity]()
    }
    
}
