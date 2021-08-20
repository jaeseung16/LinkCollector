//
//  LinkDetailView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI
import MapKit

struct LinkDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @Environment(\.presentationMode) private var presentationMode
    
    @State var showEditLinkView = false
    @State var saveButtonClicked = false {
        didSet {
            if saveButtonClicked {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    let entity: LinkEntity!
    
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    private var location: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: entity.latitude,
                                      longitude: entity.longitude)
    }
    
    private var tags: [TagEntity] {
        if entity.tags != nil, let tags = entity.tags?.allObjects as? [TagEntity] {
            return tags
        } else {
            return [TagEntity]()
        }
    }
    
    var body: some View {
        VStack {
            entity.created.map {
                Text(dateFormatter.string(from: $0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            entity.url.map {
                #if targetEnvironment(macCatalyst)
                Link(destination: $0) {
                    Label("Open in Browser", systemImage: "link")
                }
                .foregroundColor(.blue)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
                #else
                Link(destination: $0) {
                    Label("Open in Browser", systemImage: "link")
                }
                .foregroundColor(.blue)
                #endif
            }
            
            entity.note.map {
                Text($0)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if !self.tags.isEmpty {
                HStack {
                    Image(systemName: "tag")
                    
                    LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
                        ForEach(self.tags, id: \.id) { tag in
                            if let name = tag.name {
                                Text(name)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            entity.url.map {
                WebView(url: $0)
                    .shadow(color: Color.gray, radius: 1.0)
                    //.border(Color.gray, width: 1.0)
                    .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $linkCollectorViewModel.showAlert, content: {
            Alert(title: Text("Unable to Save Data"),
                  message: Text(linkCollectorViewModel.message),
                  dismissButton: .default(Text("Dismiss")))
        })
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
            EditLinkView(id: entity.id!,
                         title: entity.title ?? "",
                         note: entity.note ?? "",
                         tags: getTagList(of: entity),
                         saveButtonClicked: $saveButtonClicked)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(linkCollectorViewModel)
        }
    }
    
    private func getTagList(of link: LinkEntity) -> [String] {
        var tagList = [String]()
        
        if let tags = link.tags {
            for tag in tags {
                if let tag = tag as? TagEntity {
                    if let name = tag.name {
                        tagList.append(name)
                    }
                }
            }
        }
        return tagList
    }
    
}

struct LinkDetailView_Previews: PreviewProvider {
    static var linkEntity: LinkEntity {
        let link = LinkEntity()
        link.id = UUID()
        link.title = "example"
        link.url = URL(string: "http://www.google.com")
        link.latitude = -97.822
        link.longitude = 37.751
        return link
    }
    
    static var previews: some View {
        LinkDetailView(entity: linkEntity)
    }
}
