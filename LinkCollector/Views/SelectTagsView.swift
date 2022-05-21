//
//  SelectTagsView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 5/8/22.
//

import SwiftUI

struct SelectTagsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @FetchRequest(entity: TagEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \TagEntity.name, ascending: true)]) private var tags: FetchedResults<TagEntity>
    
    @State var selectedTags: Set<TagEntity>
    
    private var filteredTags: [TagEntity] {
        tags.filter { !selectedTags.contains($0) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                header()
                
                Form {
                    Section(header: Text("Selected")) {
                        ForEach(Array(selectedTags), id: \.id) { tag in
                            Button {
                               selectedTags.remove(tag)
                            } label: {
                                tagView(for: tag)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Section(header: Text("Tags")) {
                        ForEach(filteredTags, id: \.id) { tag in
                            Button {
                                selectedTags.insert(tag)
                            } label: {
                                tagView(for: tag)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func header() -> some View {
        HStack {
            Button {
                viewModel.selectedTags = selectedTags
                dismiss.callAsFunction()
            } label: {
                Label("Done", systemImage: "chevron.backward")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text("Select Tags")
            
            Spacer()
            
            Button {
                selectedTags.removeAll()
            } label: {
                Text("Reset")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func tagView(for tag: TagEntity) -> some View {
        HStack {
            Label(tag.name ?? "", systemImage: "tag")
            Spacer()
            Text("\(tag.links?.count ?? 0)")
        }
    }
}
