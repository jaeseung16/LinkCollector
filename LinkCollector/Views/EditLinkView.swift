//
//  EditLinkView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/17/21.
//

import SwiftUI

struct EditLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    @State var titleColor = Color.white
    @State var noteColor = Color.white
    
    @State var saveButtonEnabled = false
    
    @State var id: UUID
    @State var title: String
    @State var note: String
    @State var tags: [TagEntity]
    @State var editTags = false
    
    @State var titleBeforeEditing = ""
    @State var noteBeforeEditing = ""
    
    var body: some View {
        VStack {
            editLinkButtons()
            editLinkForm()
        }
        .padding()
    }
    
    @ScaledMetric(relativeTo: .body) var bodyTextHeight: CGFloat = 40.0
    
    private func editLinkForm() -> some View {
        Form {
            Section(header: TitleLabel(title: "Title")) {
                TextField("Title", text: $title) { isEditing in
                    if isEditing && titleBeforeEditing == "" {
                        titleBeforeEditing = title
                    }
                } onCommit: {
                    saveButtonEnabled = titleBeforeEditing != title
                }
            }
            
            Section(header: tagSectionHeaderView()) {
                List {
                    ForEach(self.tags, id: \.self) { tag in
                        Button {
                            if let index = tags.firstIndex(of: tag) {
                                tags.remove(at: index)
                            }
                        } label: {
                            TagLabel(title: tag.name ?? "")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(minHeight: bodyTextHeight * CGFloat(self.tags.count))
                .listStyle(PlainListStyle())
                .sheet(isPresented: $editTags) {
                    AddTagView(tags: $tags, isUpdate: true)
                        .environmentObject(viewModel)
                }
            }
            
            Section(header: NoteLabel(title: "Note")) {
                TextEditor(text: $note)
                    .onChange(of: note, perform: { _ in
                        saveButtonEnabled = true
                    })
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.leading)
                    .border(Color.secondary)
                    .frame(minHeight: 150)
            }
        }
    }
    
    private func tagSectionHeaderView() -> some View {
        HStack {
            TagLabel(title: "Tags")
            
            Spacer()
            
            Button {
                editTags.toggle()
                saveButtonEnabled = true
            } label: {
                TagLabel(title: "Edit tags")
                    .foregroundColor(Color.blue)
            }
        }
    }
    
    private func editLinkButtons() -> some View {
        HStack {
            Button(action: {
                dismiss.callAsFunction()
            }, label: {
                Label("Cancel", systemImage: "chevron.backward")
            })
            .foregroundColor(Color.blue)
            
            Spacer()
            
            Text("Edit a link")
            
            Spacer()
            
            Button(action: {
                saveEntities()
                dismiss.callAsFunction()
            }, label: {
                Label("Save", systemImage: "square.and.arrow.down")
            })
            .disabled(!saveButtonEnabled)
            .foregroundColor(saveButtonEnabled ? Color.blue : Color.gray)
        }
    }
    
    private func saveEntities() -> Void {
        let linkDTO = LinkDTO(id: id, title: title, note: note)
        viewModel.linkDTO = linkDTO
        viewModel.update(link: linkDTO, with: tags)
    }
}

