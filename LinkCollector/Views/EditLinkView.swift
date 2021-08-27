//
//  EditLinkView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/17/21.
//

import SwiftUI

struct EditLinkView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject var linkCollectorViewModel: LinkCollectorViewModel
    
    @State var titleColor = Color.white
    @State var noteColor = Color.white
    
    @State var saveButtonEnabled = false
    
    @State var id: UUID
    @State var title: String
    @State var note: String
    @State var tags: [String]
    @State var editTags = false
    
    @State var titleBeforeEditing = ""
    @State var noteBeforeEditing = ""
    
    @Binding var saveButtonClicked: Bool
    
    @State var originalTags = [String]()
    
    var body: some View {
        VStack {
            editLinkForm()
            editLinkButtons()
        }
        .padding()
    }
    
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
            
            Section(header: NoteLabel(title: "Note")) {
                TextField("Note", text: $note) { isEditing in
                    if isEditing && noteBeforeEditing == "" {
                        noteBeforeEditing = note
                    }
                } onCommit: {
                    saveButtonEnabled = noteBeforeEditing != note
                }
            }
            
            Section(header: tagSectionHeaderView()) {
                LazyVGrid(columns: Array(repeating: GridItem.init(.flexible()), count: 3)) {
                    ForEach(self.tags, id: \.self) { tag in
                        TagLabel(title: tag)
                            .foregroundColor(.primary)
                    }
                }
                .sheet(isPresented: $editTags) {
                    AddTagView(tags: $tags)
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(linkCollectorViewModel)
                }
            }
        }
    }
    
    private func tagSectionHeaderView() -> some View {
        HStack {
            TagLabel(title: "Tags")
            
            Spacer()
            
            Button {
                originalTags.removeAll()
                originalTags.append(contentsOf: tags)
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
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Label("Cancel", systemImage: "chevron.backward")
            })
            .foregroundColor(Color.blue)
            
            Spacer()
            
            Button(action: {
                saveEntities()
                saveButtonClicked = true
                presentationMode.wrappedValue.dismiss()
            }, label: {
                Label("Save", systemImage: "square.and.arrow.down")
            })
            .disabled(!saveButtonEnabled)
            .foregroundColor(saveButtonEnabled ? Color.blue : Color.gray)
        }
    }
    
    private func saveEntities() -> Void {
        let linkDTO = LinkDTO(id: id, title: title, note: note)
        linkCollectorViewModel.linkDTO = linkDTO
        
        for tag in tags {
            linkCollectorViewModel.tagDTO = TagDTO(name: tag, link: linkDTO)
            
            if let index = originalTags.firstIndex(of: tag) {
                originalTags.remove(at: index)
            }
        }
        
        for tag in originalTags {
            linkCollectorViewModel.remove(tag: tag, from: linkDTO)
        }
    }
}

struct EditLinkView_Previews: PreviewProvider {
    @State static var saveButtonClicked = false
    static var previews: some View {
        EditLinkView(id: UUID(), title: "title", note: "note", tags: [String](), saveButtonClicked: $saveButtonClicked)
    }
}
