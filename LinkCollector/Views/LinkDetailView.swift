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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @State var showNote = false
    @State var showTags = false
    @State var showEditLinkView = false
    
    var entity: LinkEntity
    
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    private var location: String {
        let locality = entity.locality
        
        if locality == nil || locality == "Unknown" {
            return "a unknown location"
        } else {
            return locality!
        }
    }
    
    var tags: [TagEntity]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                headerView(geometry: geometry)
                    .frame(width: geometry.size.width, height: 30, alignment: .center)
                    .scaledToFit()
                
                tagsView(geometry: geometry)
                    .padding()
                
                entity.created.map {
                    Text("Added on \(dateFormatter.string(from: $0)) from \(location)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
               
                entity.lastupd.map {
                    Text("Last updated on \(dateFormatter.string(from: $0))")
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
                             tags: linkCollectorViewModel.getTagList(of: entity))
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
            .foregroundColor(.blue)
        }
    }
    
    private func note(geometry: GeometryProxy) -> some View {
        Button {
            showNote = true
        } label: {
            NoteLabel(title: "note")
        }
        .foregroundColor(.blue)
        .popover(isPresented: $showNote) {
            VStack {
                Spacer()
                
                if let note = entity.note, !note.isEmpty {
                    Text(note)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(minWidth: 0.5 * geometry.size.width)
                } else {
                    Text("No note added")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 0.5 * geometry.size.width)
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
    
    private func tagsView(geometry: GeometryProxy) -> some View {
        VStack {
            if !self.tags.isEmpty {
                List {
                    ForEach(self.tags, id: \.id) { tag in
                        if let name = tag.name {
                            TagLabel(title: name)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .frame(height: bodyTextHeight * CGFloat(self.tags.count))
            } else {
                Text("No tags added")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
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
