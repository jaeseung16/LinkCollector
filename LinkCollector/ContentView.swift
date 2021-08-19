//
//  ContentView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/15/20.
//

import SwiftUI

struct ContentView: View {
    @FetchRequest(entity: LinkEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \LinkEntity.created, ascending: false)]) private var links: FetchedResults<LinkEntity>
    @Environment(\.managedObjectContext) private var viewContext
    
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @State var showAddLinkView = false
    @State var showEditLinkView = false
    
    let calendar = Calendar(identifier: .iso8601)
    let today = Date()
    
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                List {
                    Section(header: ListHeader(text: "today")) {
                        ForEach(
                            links.filter { (entity) -> Bool in
                                return entity.id == nil ? false : calendar.isDateInToday(entity.created!)
                            },
                            id: \.id
                        ) { link in
                            NavigationLink(destination: makeDetailView(from: link)) {
                                Text(link.title ?? dateFormatter.string(from: link.created!))
                                    .font(.body)
                            }
                        }
                        .onDelete(perform: self.removeLink)
                    }
                    
                    Section(header: ListHeader(text: "this week")) {
                        ForEach(
                            links.filter { (entity) -> Bool in
                                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
                                let todayStartOfDay = calendar.startOfDay(for: today)
                                
                                let dateInterval = DateInterval(start: sevenDaysAgo, end: todayStartOfDay)
                                
                                return entity.id == nil ? false : dateInterval.contains(entity.created!)
                            },
                            id: \.id
                        ) { link in
                            NavigationLink(destination: makeDetailView(from: link)) {
                                Text(link.title ?? dateFormatter.string(from: link.created!))
                                    .font(.body)
                            }
                        }
                        .onDelete(perform: self.removeLink)
                    }
                    
                    Section(header: ListHeader(text: "this month")) {
                        ForEach(
                            links.filter { (entity) -> Bool in
                                let daysOfMonth = calendar.component(.day, from: today)
                        
                                let firstDayOfMonth = calendar.date(byAdding: .day, value: -daysOfMonth, to: today)!
                                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
                                
                                let dateInterval = DateInterval(start: firstDayOfMonth, end: sevenDaysAgo)
                                
                                return entity.id == nil ? false : dateInterval.contains(entity.created!)
                            },
                            id: \.id
                        ) { link in
                            NavigationLink(destination: makeDetailView(from: link)) {
                                Text(link.title ?? dateFormatter.string(from: link.created!))
                                    .font(.body)
                            }
                        }
                        .onDelete(perform: self.removeLink)
                    }
                    
                    Section(header: ListHeader(text: "past")) {
                        ForEach(
                            links.filter { (entity) -> Bool in
                                let daysOfMonth = calendar.component(.day, from: today)
                                let firstDayOfMonth = calendar.date(byAdding: .day, value: -daysOfMonth, to: today)!
                                
                                return entity.id == nil ? false : entity.created! < firstDayOfMonth
                            },
                            id: \.id
                        ) { link in
                            NavigationLink(destination: makeDetailView(from: link)) {
                                Text(link.title ?? dateFormatter.string(from: link.created!))
                                    .font(.body)
                            }
                        }
                        .onDelete(perform: self.removeLink)
                    }
                }
                .listStyle(GroupedListStyle())
            }
            .navigationBarTitle("Link Collector")
            .navigationBarItems(trailing:
                                    Button(action: {
                                        self.showAddLinkView = true
                                    }, label: {
                                        Label("Add", systemImage: "plus")
                                    })
            )
            .sheet(isPresented: $showAddLinkView) {
                AddLinkView()
                    .environmentObject(linkCollectorViewModel)
            }
        }
    }
    
    @State var isActive = false
    
    private func makeDetailView(from link: LinkEntity) -> some View {
        return LinkDetailView(entity: link)
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(linkCollectorViewModel)
            .navigationTitle(link.title ?? "")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        self.showEditLinkView = true
                    } label: {
                        Label("Edit", systemImage: "pencil.circle")
                    }
                }
            })
            .sheet(isPresented: $showEditLinkView) {
                EditLinkView(id: link.id!,
                             title: link.title ?? "",
                             note: link.note ?? "",
                             tags: link.tags?.allObjects as? [TagEntity] ?? [TagEntity]() )
                    .environmentObject(linkCollectorViewModel)
            }
    }
    
    private func removeLink(indexSet: IndexSet) -> Void {
        for index in indexSet {
            let link = links[index]
            viewContext.delete(link)
        }
        
        do {
            try viewContext.save()
        } catch {
            print(error)
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
