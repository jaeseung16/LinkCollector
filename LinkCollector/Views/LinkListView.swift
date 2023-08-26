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
    
    var filteredLinks: Array<LinkEntity> {
        viewModel.links.filter { link in
            var filter = true
            if let tags = link.tags as? Set<TagEntity>, !viewModel.selectedTags.isEmpty && viewModel.selectedTags.intersection(tags).isEmpty {
                filter = false
            }
            return filter
        }
        .filter { link in
            var filter = true
            if let created = link.created {
                filter = viewModel.dateInterval?.contains(created) ?? true
            }
            return filter
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                List {
                    ForEach(filteredLinks, id: \.id) { link in
                        if link.created != nil {
                            NavigationLink(tag: link.id!, selection: $selected) {
                                LinkDetailView(entity: link, tags: link.getTagList())
                                    .navigationTitle(link.title ?? "")
                            } label: {
                                LinkLabel(link: link)
                            }
                        }
                    }
                    .onDelete(perform: self.removeLink)
                }
                .listStyle(GroupedListStyle())
            }
            .navigationBarTitle("Links")
            .navigationBarItems(trailing: navigationBarItems())
            .sheet(isPresented: $showAddLinkView) {
                AddLinkView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showTagListView) {
                SelectTagsView(selectedTags: viewModel.selectedTags)
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showDateRangePickerView) {
                DateRangePickerView(start: viewModel.dateInterval?.start ?? Date(), end: viewModel.dateInterval?.end ?? Date())
                    .environmentObject(viewModel)
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
        }
        .onChange(of: viewModel.selected) { newValue in
            selected = newValue
        }
        .onChange(of: viewModel.searchString) { _ in
            viewModel.searchLink()
        }
    }
    
    private func removeLink(indexSet: IndexSet) -> Void {
        for index in indexSet {
            let link = filteredLinks[index]
            viewModel.delete(link: link)
        }
        
        viewModel.saveContext { _ in
            DispatchQueue.main.async {
                message = "Failed to delete the selected link"
                showAlert = true
            }
        }
    }
    
    private func navigationBarItems() -> some View {
        HStack {
            Button(action: {
                self.showDateRangePickerView = true
            }, label: {
                Label("Date Range", systemImage: "calendar")
            })
            .foregroundColor(Color.blue)
            
            Button(action: {
                self.showTagListView = true
            }, label: {
                TagLabel(title: "Tags")
            })
            .foregroundColor(Color.blue)
            
            Button(action: {
                self.showAddLinkView = true
            }, label: {
                Label("Add", systemImage: "plus")
            })
            .foregroundColor(Color.blue)
        }
    }
}
