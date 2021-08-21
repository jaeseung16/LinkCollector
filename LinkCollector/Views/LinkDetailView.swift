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
    
    @State var showNote = false
    @State var showTags = false
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
            return tags.sorted(by: { ($0.name ?? "") < ($1.name ?? "") })
        } else {
            return [TagEntity]()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                headerView(geometry: geometry)
                    .frame(width: geometry.size.width, height: 30, alignment: .center)
                    .scaledToFit()
                
                entity.created.map {
                    Text("Added on \(dateFormatter.string(from: $0))")
                        .font(.body)
                        .foregroundColor(.secondary)
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
    }
    
    private func headerView(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            
            openInBrowser(geometry: geometry)
            
            Spacer()
            
            note(geometry: geometry)
            
            Spacer()
            
            showTagsView(geometry: geometry)
            
            Spacer()
        }
    }
    
    private func openInBrowser(geometry: GeometryProxy) -> some View {
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
    }
    
    private func note(geometry: GeometryProxy) -> some View {
        Button {
            showNote = true
        } label: {
            Label("note", systemImage: "note")
        }
        .popover(isPresented: $showNote) {
                if let note = entity.note {
                    Text(note)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 0.5 * geometry.size.width)
                        .padding()
                } else {
                    Text("No note added")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 0.5 * geometry.size.width)
                        .padding()
                }
        }
    }
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    private func showTagsView(geometry: GeometryProxy) -> some View {
        Button {
            showTags = true
        } label: {
            Label("tags", systemImage: "tag")
        }
        .popover(isPresented: $showTags) {
            if !self.tags.isEmpty {
                List {
                    ForEach(self.tags, id: \.id) { tag in
                        if let name = tag.name {
                            Text(name)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 0.25 * geometry.size.width, height: bodyTextHeight * CGFloat(self.tags.count))
                .padding()
            } else {
                Text("No tags added")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 0.25 * geometry.size.width)
                    .padding()
            }
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
