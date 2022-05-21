//
//  LinkPilerWidget.swift
//  LinkPilerWidget
//
//  Created by Jae Seung Lee on 4/17/22.
//

import WidgetKit
import SwiftUI

@main
struct LinkPilerWidget: Widget {
    @Environment(\.widgetFamily) var family
    
    let kind: String = "LinkPilerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recents")
        .description("Recently added links")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
