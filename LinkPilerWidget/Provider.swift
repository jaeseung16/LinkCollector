//
//  Provider.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/30/22.
//

import WidgetKit
import SwiftUI
import CoreData

struct Provider: TimelineProvider {
    private let persistenceController = PersistenceController.shared
    
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(id: UUID(), title: "title", url: URL(fileURLWithPath: ""), created: Date(), date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = WidgetEntry(id: UUID(), title: "title", url: URL(fileURLWithPath: ""), created: Date(), date: Date())
        completion(entry)
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
        let interval = 15
        for index in 0 ..< widgetEntries.count {
            widgetEntries[index].date = Calendar.current.date(byAdding: .second, value: index * interval, to: currentDate)!
        }

        let timeline = Timeline(entries: widgetEntries, policy: .atEnd)
        completion(timeline)
    }
}
