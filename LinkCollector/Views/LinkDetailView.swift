//
//  LinkDetailView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/17/20.
//

import SwiftUI
import MapKit

struct LinkDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    @State var showNote = false
    @State var showTags = false
    @State var showEditLinkView = false
    @State private var showSummary = false
    
    // Observed so that a change merged from iCloud — or a summary written by summarize() —
    // redraws this view instead of waiting for the next re-selection.
    @ObservedObject var entity: LinkEntity
    
    private var summary: String {
        entity.summary ?? ""
    }
    
    // Sorted by name to match the tag list elsewhere: getTagList() walks an NSSet, so its order
    // would otherwise shuffle between redraws.
    private var tags: [TagEntity] {
        entity.getTagList().sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    private static var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "en_US")
        return dateFormatter
    }
    
    private var location: String {
        let locality = entity.locality
        
        if locality == nil || locality == LinkCollectorViewModel.unknown {
            return "a unknown location"
        } else {
            return locality!
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                headerView(geometry: geometry)
                    .frame(width: geometry.size.width, height: 30, alignment: .center)
                    .scaledToFit()
                
                tagsView()
                    .padding()
                
                entity.created.map {
                    Text("Added on \(LinkDetailView.dateFormatter.string(from: $0)) from \(location)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
               
                entity.lastupd.map {
                    Text("Last updated on \(LinkDetailView.dateFormatter.string(from: $0))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                entity.url.map {
                    WebView(url: $0)
                        .environmentObject(viewModel)
                        .padding()
                }
            }
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert(isPresented: $viewModel.showAlert, content: {
                Alert(title: Text("Unable to Save Data"),
                      message: Text(viewModel.message),
                      dismissButton: .default(Text("Dismiss")))
            })
            .sheet(isPresented: $showEditLinkView) {
                EditLinkView(id: entity.id!,
                             title: entity.title ?? "",
                             note: entity.note ?? "",
                             tags: tags)
                    .environmentObject(viewModel)
                    .frame(height: 0.9 * geometry.size.height)
            }
        }
    }
    
    private func headerView(geometry: GeometryProxy) -> some View {
        HStack {
            Spacer()
            
            #if canImport(UIKit)
            openInBrowser(geometry: geometry)
            #else
            openInBrowser(geometry: geometry)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #endif
            
            Spacer()
            
            #if canImport(UIKit)
            note(geometry: geometry)
            #else
            note(geometry: geometry)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #endif
            
            Spacer()
            
            #if canImport(UIKit)
            summaryView(geometry: geometry)
            #else
            summaryView(geometry: geometry)
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #endif
            
            Spacer()
            
            #if canImport(UIKit)
            editLinkView()
            #else
            editLinkView()
                .onHover(perform: { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                })
            #endif
            
            Spacer()
        }
    }
    
    private func openInBrowser(geometry: GeometryProxy) -> some View {
        entity.url.map {
            Link(destination: $0) {
                Label("Open in Browser", systemImage: "link")
            }
        }
    }
    
    private func note(geometry: GeometryProxy) -> some View {
        Button {
            showNote = true
        } label: {
            NoteLabel(title: "note")
        }
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
                }
            }
            .padding()
        }
    }
    
    private func summaryView(geometry: GeometryProxy) -> some View {
        Button {
            showSummary = true
        } label: {
            SummaryLabel(title: "summary")
        }
        .popover(isPresented: $showSummary) {
            VStack {
                Spacer()
                
                if viewModel.isSummarizing(entity) {
                    ProgressView()
                    
                    Text("Summarizing this page may take a while")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 0.5 * geometry.size.width)
                } else if !summary.isEmpty {
                    ScrollView {
                        Text(summary)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(minWidth: 0.5 * geometry.size.width, maxWidth: geometry.size.width, minHeight: 0.2 * geometry.size.height, maxHeight: 0.8 * geometry.size.height)
                } else {
                    Text("No summary added")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 0.5 * geometry.size.width)
                }
                
                summaryModelUnavailable.map {
                    Text($0)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 0.5 * geometry.size.width)
                }
                
                Spacer()
                
                HStack {
                    Button {
                        Task {
                            await viewModel.summarize(link: entity)
                        }
                    } label: {
                        Text(summary.isEmpty ? "Summarize" : "Summarize Again")
                    }
                    .disabled(entity.url == nil || viewModel.isSummarizing(entity))
                    
                    Spacer()
                    
                    Button {
                        showSummary = false
                    } label: {
                        Text("Dismiss")
                    }
                }
            }
            .padding()
        }
    }
    
    // The summary falls back to the page's own description when the on-device model can't run, so
    // an unavailable model is explained rather than used to disable the button.
    private var summaryModelUnavailable: String? {
        guard case .unavailable(let reason) = viewModel.summaryModelAvailability else {
            return nil
        }
        
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so the page's own description is used."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off, so the page's own description is used."
        case .modelNotReady:
            return "The on-device model isn't ready yet, so the page's own description is used."
        @unknown default:
            return "On-device summarization isn't available, so the page's own description is used."
        }
    }
    
    private func tagsView() -> some View {
        VStack(alignment: .leading) {
            if !self.tags.isEmpty {
                ForEach(self.tags, id: \.id) { tag in
                    if let name = tag.name {
                        TagLabel(title: name)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
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
    }
}
