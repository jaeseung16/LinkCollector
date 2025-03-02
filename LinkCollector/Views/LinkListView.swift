//
//  LinkListView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 5/8/22.
//

import SwiftUI

struct LinkListView: View {
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @State private var showAddLinkView = false
    @State private var showTagListView = false
    @State private var showAlert = false
    @State private var message = ""
    @State private var searchString = ""
    @State private var selected: UUID?
    @State private var showDateRangePickerView = false
    
    @State private var selectedTags = Set<TagEntity>()
    @State private var dateInterval: DateInterval?
    
    var filteredLinks: [LinkEntity] {
        viewModel.links.filter { link in
            var filter = true
            if let tags = link.tags as? Set<TagEntity> {
                filter = selectedTags.isEmpty || !selectedTags.intersection(tags).isEmpty
            }
            return filter
        }
        .filter { link in
            var filter = true
            if let dateInterval = dateInterval, let created = link.created {
                filter = dateInterval.contains(created)
            }
            return filter
        }
    }
    
    @Binding var selectedLink: LinkEntity?
    
    var body: some View {
        GeometryReader { geometry in
            List(selection: $selectedLink) {
                ForEach(filteredLinks) { link in
                    if link.created != nil {
                        NavigationLink(value: link) {
                            LinkLabel(link: link)
                        }
                        .id(link)
                    }
                }
                .onDelete(perform: removeLink)
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Links")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showDateRangePickerView = true
                    } label: {
                        Label("Date Range", systemImage: "calendar")
                    }
                    .foregroundColor(Color.blue)
                    
                    Button {
                        showTagListView = true
                    } label: {
                        TagLabel(title: "Tags")
                    }
                    .foregroundColor(Color.blue)
                    
                    Button {
                        showAddLinkView = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .foregroundColor(Color.blue)
                }
            }
            .sheet(isPresented: $showAddLinkView) {
                AddLinkView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showTagListView) {
                SelectTagsView(selectedTags: $selectedTags)
            }
            .sheet(isPresented: $showDateRangePickerView) {
                if let start = dateInterval?.start, let end = dateInterval?.end {
                    DateRangePickerView(dateInterval: $dateInterval, start: start, end: end)
                } else {
                    DateRangePickerView(dateInterval: $dateInterval)
                }
            }
            .alert("Unable to Save Data", isPresented: $showAlert) {
                Button {
                    showAlert.toggle()
                } label: {
                    Text("Dismiss")
                }
            } message: {
                Text(message)
            }
            .searchable(text: $viewModel.searchString)
            .refreshable {
                viewModel.fetchAll()
            }
            .onChange(of: viewModel.selected) {
                selected = viewModel.selected
            }
            .onChange(of: viewModel.searchString) {
                viewModel.searchLink()
            }
        }
    }
    
    private func removeLink(indexSet: IndexSet) -> Void {
        for index in indexSet {
            let link = filteredLinks[index]
            viewModel.delete(link: link)
        }
        
        do {
            try viewModel.save()
        } catch {
            message = "Failed to delete the selected link"
            showAlert = true
        }
        
        viewModel.fetchAll()
    }
    
}
