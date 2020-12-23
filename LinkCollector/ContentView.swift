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
    
    @EnvironmentObject var locationViewModel: LocationViewModel
    
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
                    ForEach(links, id: \.id) { link in
                        NavigationLink(destination: makeDetailView(from: link)) {
                            Text(link.title ?? dateFormatter.string(from: link.created!))
                                .font(.body)
                        }
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: AddLinkView().environmentObject(locationViewModel)) {
                    HStack {
                        Text("Add Link")
                    }
                }
            }
            .navigationBarTitle("Link Collector")
        }
    }
    
    private func makeDetailView(from link: LinkEntity) -> LinkDetailView {
        return LinkDetailView(entity: link)
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
