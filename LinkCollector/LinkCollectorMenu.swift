//
//  LinkCollectorMenu.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/30/25.
//

import Foundation

enum LinkCollectorMenu: String, CaseIterable, Identifiable {
    case links = "Links"
    case tags = "Tags"
    
    var id: Self { self }
}
