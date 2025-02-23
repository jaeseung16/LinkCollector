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
