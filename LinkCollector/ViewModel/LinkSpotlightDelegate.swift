//
//  LinkSpotlightDelegate.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 8/26/23.
//

import Foundation
import CoreSpotlight
import CoreData

class LinkSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    override func domainIdentifier() -> String {
        return LinkPilerConstants.domainIdentifier.rawValue
    }
    
    override func indexName() -> String? {
        return LinkPilerConstants.linkIndexName.rawValue
    }
    
    override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let link = object as? LinkEntity {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = link.title
            attributeSet.displayName = link.title
            return attributeSet
        }
        return nil
    }
}
