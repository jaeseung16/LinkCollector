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
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @State var showNote = false
    @State var showTags = false
    @State var showEditLinkView = false
    
    // When edited, close the current view so the updated view will appear
    @State var saveButtonClicked = false {
        didSet {
            if saveButtonClicked {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    let entity: LinkEntity!
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .long
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    private var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: entity.latitude, longitude: entity.longitude)
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
                    Text("Added: \(dateFormatter.string(from: $0))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
               
                entity.lastupd.map {
                    Text("Last updated: \(dateFormatter.string(from: $0))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                entity.url.map {
                    WebView(url: $0)
                        .shadow(color: Color.gray, radius: 1.0)
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $linkCollectorViewModel.showAlert, content: {
                Alert(title: Text("Unable to Save Data"),
                      message: Text(linkCollectorViewModel.message),
                      dismissButton: .default(Text("Dismiss")))
            })
            .sheet(isPresented: $showEditLinkView) {
                EditLinkView(id: entity.id!,
                             title: entity.title ?? "",
                             note: entity.note ?? "",
                             tags: linkCollectorViewModel.getTagList(of: entity),
                             saveButtonClicked: $saveButtonClicked)
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(linkCollectorViewModel)
            }
        }
    }
    
    private func headerView(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            
            #if targetEnvironment(macCatalyst)
            openInBrowser(geometry: geometry)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #else
            openInBrowser(geometry: geometry)
            #endif
            
            Spacer()
            
            #if targetEnvironment(macCatalyst)
            note(geometry: geometry)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #else
            note(geometry: geometry)
            #endif
            
            Spacer()
            
            #if targetEnvironment(macCatalyst)
            showTagsView(geometry: geometry)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #else
            showTagsView(geometry: geometry)
            #endif
            
            Spacer()
            
            #if targetEnvironment(macCatalyst)
            editLinkView()
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #else
            editLinkView()
            #endif
            
            Spacer()
        }
    }
    
    private func openInBrowser(geometry: GeometryProxy) -> some View {
        entity.url.map {
            Link(destination: $0) {
                Label("Open in Browser", systemImage: "link")
            }
            .foregroundColor(.secondary)
        }
    }
    
    private func note(geometry: GeometryProxy) -> some View {
        Button {
            showNote = true
        } label: {
            Label("note", systemImage: "note")
        }
        .foregroundColor(.secondary)
        .popover(isPresented: $showNote) {
            VStack {
                Spacer()
                
                if let note = entity.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(width: 0.5 * geometry.size.width)
                } else {
                    Text("No note added")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 0.5 * geometry.size.width)
                }
                
                Spacer()
                
                Button {
                    showNote = false
                } label: {
                    Text("Dismiss")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    private func showTagsView(geometry: GeometryProxy) -> some View {
        Button {
            showTags = true
        } label: {
            Label("tags", systemImage: "tag")
        }
        .foregroundColor(Color.secondary)
        .popover(isPresented: $showTags) {
            VStack {
                Spacer()
                
                if !self.tags.isEmpty {
                    List {
                        ForEach(self.tags, id: \.id) { tag in
                            if let name = tag.name {
                                Label(name, systemImage: "tag")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .frame(width: 0.25 * geometry.size.width, height: bodyTextHeight * CGFloat(self.tags.count))
                } else {
                    VStack {
                        Text("No tags added")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 0.25 * geometry.size.width)
                    }
                }
                
                Spacer()
                
                Button {
                    showTags = false
                } label: {
                    Text("Dismiss")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
    
    private func editLinkView() -> some View {
        Button {
            self.showEditLinkView = true
        } label: {
            Label("EDIT", systemImage: "pencil.circle")
        }
        .foregroundColor(.blue)
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
