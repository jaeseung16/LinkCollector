//
//  LinkListView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 5/8/22.
//

import SwiftUI

struct LinkListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    @FetchRequest(entity: LinkEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \LinkEntity.created, ascending: false)]) private var links: FetchedResults<LinkEntity>
    
    @State var showAddLinkView = false
    @State var showTagListView = false
    @State var showAlert = false
    @State var message = ""
    @State var searchString = ""
    @State private var selected: UUID?
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    var filteredLinks: Array<LinkEntity> {
        links.filter { link in
            var filter = true
            if let tags = link.tags as? Set<TagEntity>, !viewModel.selectedTags.isEmpty && viewModel.selectedTags.intersection(tags).isEmpty {
                filter = false
            }
            return filter
        }
        .filter { link in
            if viewModel.searchString == "" {
                return true
            } else if let title = link.title {
                return title.lowercased().contains(viewModel.searchString.lowercased())
            } else {
                return false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                List {
                    ForEach(filteredLinks, id: \.id) { link in
                        if link.created != nil {
                            makeNavigationLink(from: link)
                        }
                    }
                    .onDelete(perform: self.removeLink)
                }
                .listStyle(GroupedListStyle())
            }
            .navigationBarTitle("Link Piler")
            .navigationBarItems(trailing: navigationBarItems())
            .sheet(isPresented: $showAddLinkView) {
                AddLinkView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showTagListView) {
                SelectTagsView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(viewModel)
            }
            .alert("Unable to Save Data", isPresented: $showAlert) {
                Button {
                    showAlert.toggle()
                } label: {
                    Text(message)
                }
            }
            .searchable(text: $viewModel.searchString)
        }
        .onChange(of: viewModel.selected) { newValue in
            selected = newValue
        }
    }
    
    private func makeNavigationLink(from link: LinkEntity) -> some View {
        NavigationLink(tag: link.id!, selection: $selected) {
            LinkDetailView(entity: link, tags: tagList(of: link))
                .navigationTitle(link.title ?? "")
        } label: {
            HStack {
                Text(link.title ?? "No title")
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack {
                    if let favicon = link.favicon, let uiImage = UIImage(data: favicon) {
                        Spacer()
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 24, maxHeight: 24)
                    }
                    
                    Spacer()
                    
                    Text(dateFormatter.string(from: link.created!))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func tagList(of link: LinkEntity) -> [TagEntity] {
        link.tags?.filter { $0 is TagEntity }.map { $0 as! TagEntity } ?? [TagEntity]()
    }
    
    private func removeLink(indexSet: IndexSet) -> Void {
        for index in indexSet {
            let link = filteredLinks[index]
            viewContext.delete(link)
        }
        
        do {
            try viewContext.save()
        } catch {
            message = "Failed to delete the selected link"
            showAlert = true
        }
    }
    
    private func navigationBarItems() -> some View {
        HStack {
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
