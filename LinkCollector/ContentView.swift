//
//  ContentView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @FetchRequest(entity: LinkEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \LinkEntity.created, ascending: false)]) private var links: FetchedResults<LinkEntity>
    @FetchRequest(entity: TagEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \TagEntity.name, ascending: true)]) private var tags: FetchedResults<TagEntity>
    
    @State var showAddLinkView = false
    @State var showTagListView = false
    @State var showAlert = false
    @State var message = ""
    
    @State var selectedTags = Set<TagEntity>()
    var filteredLinks: Array<LinkEntity> {
        if selectedTags.isEmpty {
            return links.map { $0 }
        } else {
            return links.filter { link in
                if let tags = link.tags, tags.count > 0 {
                    for tag in tags {
                        if selectedTags.contains(tag as! TagEntity) {
                            return true
                        }
                    }
                }
                return false
            }
        }
    }
    
    let calendar = Calendar(identifier: .iso8601)
    let today = Date()
    
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
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
            .navigationBarTitle("Link Collector")
            .navigationBarItems(trailing: navigationBarItems())
            .sheet(isPresented: $showAddLinkView) {
                AddLinkView()
                    .environmentObject(linkCollectorViewModel)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Unable to Save Data"),
                      message: Text(message),
                      dismissButton: .default(Text("Dismiss")))
            }
            .sheet(isPresented: $showTagListView) {
                selectTags()
            }
        }
    }
    
    private func makeNavigationLink(from link: LinkEntity) -> some View {
        NavigationLink(destination: makeDetailView(from: link)) {
            VStack(alignment: .leading) {
                Text(link.title ?? "No title")
                    .font(.body)
                    .foregroundColor(.primary)
                
                HStack {
                    Spacer()
                    
                    Text(dateFormatter.string(from: link.created!))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func makeDetailView(from link: LinkEntity) -> some View {
        return LinkDetailView(entity: link)
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(linkCollectorViewModel)
            .navigationTitle(link.title ?? "")
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
    
    private func selectTags() -> some View {
        GeometryReader { geometry in
            VStack {
                Form {
                    Section(header: Text("Selected Tags")) {
                        ForEach(Array(selectedTags), id: \.id) { tag in
                            if let name = tag.name {
                                Button {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    }
                                } label: {
                                    TagLabel(title: name)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Tags")) {
                        ForEach(tags, id: \.id) { tag in
                            if let name = tag.name {
                                Button {
                                    if !selectedTags.contains(tag) {
                                        selectedTags.insert(tag)
                                    } else {
                                        selectedTags.remove(tag)
                                    }
                                } label: {
                                    TagLabel(title: name)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    showTagListView = false
                } label: {
                    Text("Dismiss")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ListHeader: View {
    let text: String
    
    var body: some View {
        HStack {
            Text(text)
        }
    }
}

struct ListFooter: View {
    var body: some View {
        HStack {
            Text("Footer")
        }
    }
}
