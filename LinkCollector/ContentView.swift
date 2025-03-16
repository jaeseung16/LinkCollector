//
//  ContentView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    @State private var selectedLink: LinkEntity?
    
    var body: some View {
        VStack {
            NavigationSplitView {
                LinkListView(selectedLink: $selectedLink)
                    .navigationTitle("Links")
            } detail: {
                if let selectedLink = selectedLink {
                    LinkDetailView(entity: selectedLink, tags: selectedLink.getTagList())
                        .navigationTitle(selectedLink.title ?? "")
                        .id(selectedLink)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.fetchAll()
            } else {
                do {
                    try viewModel.save()
                } catch {
                    // TODO:
                }
                viewModel.writeWidgetEntries()
            }
        }
        
    }
    
}
