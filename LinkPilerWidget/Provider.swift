//
//  Provider.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/30/22.
//

import WidgetKit
import SwiftUI
import OSLog

struct Provider: TimelineProvider {
    private let logger = Logger()
    
    private let title = "Link Piler"
    private let imageName = "LinkPiler"
    private let contentsJson = "contents.json"
    
    private var exampleEntry: WidgetEntry {
        WidgetEntry(id: UUID(),
                    title: title,
                    url: URL(fileURLWithPath: ""),
                    created: Date(),
                    date: Date(),
                    favicon: UIImage(named: imageName)?.pngData())
    }
    
    func placeholder(in context: Context) -> WidgetEntry {
        logger.info("placeholder")
        return exampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        logger.info("snapshot")
        completion(exampleEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        var widgetEntries = [WidgetEntry]()
        
        let archiveURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: LinkPilerConstants.groupIdentifier.rawValue)!
        logger.info("timeline: archiveURL=\(archiveURL)")
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: archiveURL.appendingPathComponent(contentsJson)) {
            do {
                widgetEntries = try decoder.decode([WidgetEntry].self, from: data)
            } catch {
                logger.error("Can't decode contents: data=\(data)")
            }
        }
        logger.info("timeline: widgetEntries.count=\(widgetEntries.count)")
        let currentDate = Date()
        let interval = 1
        for index in 0 ..< widgetEntries.count {
            widgetEntries[index].date = Calendar.current.date(byAdding: .hour, value: index * interval, to: currentDate)!
        }

        let timeline = Timeline(entries: widgetEntries, policy: .atEnd)
        completion(timeline)
    }
}
