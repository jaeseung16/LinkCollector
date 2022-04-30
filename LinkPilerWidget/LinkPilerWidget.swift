//
//  LinkPilerWidget.swift
//  LinkPilerWidget
//
//  Created by Jae Seung Lee on 4/17/22.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(id: UUID(), title: "title", url: URL(fileURLWithPath: ""), created: Date(), date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = WidgetEntry(id: UUID(), title: "title", url: URL(fileURLWithPath: ""), created: Date(), date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [WidgetEntry] = []
        
        let archiveURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.resonance.jaeseung.LinkCollector")!
        
        let decoder = JSONDecoder()
        if let codeData = try? Data(contentsOf: archiveURL.appendingPathComponent("contents.json")) {
            do {
                entries = try decoder.decode([WidgetEntry].self, from: codeData)
            } catch {
                print("Error: Can't decode contents")
            }
        }
        
        let currentDate = Date()
        let interval = 15
        for index in 0 ..< entries.count {
            entries[index].date = Calendar.current.date(byAdding: .second, value: index * interval, to: currentDate)!
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct LinkPilerWidgetEntryView : View {
    var entry: Provider.Entry
    
    private var widgetURL: URL {
        URL(string: "widget-linkpiler:///\(entry.id)")!
    }

    var body: some View {
        VStack {
            Spacer()
            Text(entry.title)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            Spacer()
            Text(entry.created, style: .date)
                .font(.footnote)
        }
        .widgetURL(widgetURL)
        .padding()
    }
}

@main
struct LinkPilerWidget: Widget {
    let kind: String = "LinkPilerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LinkPilerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}
