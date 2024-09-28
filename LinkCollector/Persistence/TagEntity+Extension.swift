//
//  TagEntity+Extension.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/18/21.
//

import Foundation
import CoreData

extension TagEntity {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        created = Date()
    }
    
}
