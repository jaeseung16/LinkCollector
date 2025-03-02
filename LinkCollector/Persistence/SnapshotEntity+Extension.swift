//
//  SnapshotEntity+Extension.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 2/26/25.
//

import Foundation
import CoreData

extension SnapshotEntity {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        created = Date()
    }
    
}
