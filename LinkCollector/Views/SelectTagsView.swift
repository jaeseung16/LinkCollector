//
//  SelectTagsView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 5/8/22.
//

import SwiftUI

struct SelectTagsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: LinkCollectorViewModel
    
    @Binding var selectedTags: Set<TagEntity>
    
    private var filteredTags: [TagEntity] {
        viewModel.tags.filter { !selectedTags.contains($0) }
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
