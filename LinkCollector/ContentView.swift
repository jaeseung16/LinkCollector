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
    @State var showAlert = false
    @State var message = ""
    
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
                    ForEach(links, id: \.id) { link in
                        if link.created != nil {
                            makeNavigationLink(from: link)
                        }
                    }
                    .onDelete(perform: self.removeLink)
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
                                    .foregroundColor(Color.blue)
            )
            .sheet(isPresented: $showAddLinkView) {
                AddLinkView()
                    .environmentObject(linkCollectorViewModel)
            }
            .alert(isPresented: $showAlert, content: {
                Alert(title: Text("Unable to Save Data"),
                      message: Text(message),
                      dismissButton: .default(Text("Dismiss")))
            })
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
            let link = links[index]
            viewContext.delete(link)
        }
        
        do {
            try viewContext.save()
        } catch {
            message = "Failed to delete the selected link"
            showAlert = true
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
