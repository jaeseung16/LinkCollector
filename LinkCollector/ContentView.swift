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
    
    @State private var selectedMenu: LinkCollectorMenu? = .links
    @State private var selectedLink: LinkEntity?
    @State private var selectedTag: TagEntity?
    
    var body: some View {
        VStack {
            NavigationSplitView {
                List(selection: $selectedMenu) {
                    ForEach(LinkCollectorMenu.allCases) { menu in
                        NavigationLink(value: menu) {
                            Text(menu.rawValue)
                        }
                    }
                }
            } content: {
                switch selectedMenu {
                case .links:
                    LinkListView(selectedLink: $selectedLink)
                        .navigationTitle("Links")
                case .tags:
                    TagListView(selectedTag: $selectedTag)
                        .navigationTitle("Tags")
                case nil:
                    EmptyView()
                }
            } detail: {
                if let selectedLink = selectedLink {
                    LinkDetailView(entity: selectedLink, tags: selectedLink.getTagList())
                        .navigationTitle(selectedLink.title ?? "")
                        .id(selectedLink)
                } else if let selectedTag = selectedTag {
                    TagDetailView(entity: selectedTag)
                        .navigationTitle(selectedTag.name ?? "")
                        .id(selectedTag)
                } else {
                    EmptyView()
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.fetchAll()
            } else {
                do {
                    try  viewModel.save()
                } catch {
                    // TODO:
                }
                viewModel.writeWidgetEntries()
            }
        }
        .onChange(of: selectedMenu) { oldValue, newValue in
            selectedLink = nil
            selectedTag = nil
        }
        
    }
    
}
