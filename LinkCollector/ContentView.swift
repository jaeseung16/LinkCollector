//
//  ContentView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    let calendar = Calendar(identifier: .iso8601)
    let today = Date()

    private var todayStartOfDay: Date {
        calendar.startOfDay(for: today)
    }
    
    private var sevenDaysAgo: Date {
        return calendar.date(byAdding: .day, value: -7, to: today)!
    }
    
    private var firstDayOfMonth: Date {
        let daysOfMonth = calendar.component(.day, from: today)
        return calendar.date(byAdding: .day, value: -daysOfMonth, to: today)!
    }
    
    private var thisWeek: DateInterval {
        return DateInterval(start: sevenDaysAgo, end: todayStartOfDay)
    }
    
    private var thisMonth: DateInterval {
        return DateInterval(start: firstDayOfMonth, end: sevenDaysAgo)
    }
    
    @State private var selectedLink: LinkEntity?
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                NavigationSplitView {
                    LinkListView(selectedLink: $selectedLink)
                } detail: {
                    if let selectedLink = selectedLink {
                        LinkDetailView(entity: selectedLink, tags: selectedLink.getTagList())
                            .navigationTitle(selectedLink.title ?? "")
                            .id(selectedLink)
                    }
                }
            }
        }
        
    }
    
}
