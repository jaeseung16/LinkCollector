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
    
    private var exampleEntry: WidgetEntry {
        WidgetEntry(id: UUID(),
                    title: "Link Piler",
                    url: URL(fileURLWithPath: ""),
                    created: Date(),
                    date: Date(),
                    favicon: UIImage(named: "LinkPiler")?.pngData())
    }
    
    func placeholder(in context: Context) -> WidgetEntry {
        exampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        completion(exampleEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        var widgetEntries = [WidgetEntry]()
        
        let archiveURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.resonance.jaeseung.LinkCollector")!
        
        let decoder = JSONDecoder()
        if let codeData = try? Data(contentsOf: archiveURL.appendingPathComponent("contents.json")) {
            do {
                widgetEntries = try decoder.decode([WidgetEntry].self, from: codeData)
            } catch {
                print("Error: Can't decode contents")
            }
        }
         
        let currentDate = Date()
        let interval = 10
        for index in 0 ..< widgetEntries.count {
            widgetEntries[index].date = Calendar.current.date(byAdding: .second, value: index * interval, to: currentDate)!
        }

        let timeline = Timeline(entries: widgetEntries, policy: .atEnd)
        completion(timeline)
    }
}
