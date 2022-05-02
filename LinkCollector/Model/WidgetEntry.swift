//
//  WidgetContent.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/18/22.
//

import Foundation
import WidgetKit

struct WidgetEntry: TimelineEntry, Codable {
    let id: UUID
    let title: String
    let url: URL
    let created: Date
    var date: Date = Date()
    var favicon: Data?
}

