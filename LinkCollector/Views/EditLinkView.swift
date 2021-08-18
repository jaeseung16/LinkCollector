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
    @State var tags: [TagEntity]
    
    @State var titleBeforeEditing = ""
    @State var noteBeforeEditing = ""
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Title", text: $title) { isEditing in
                        if isEditing && titleBeforeEditing == "" {
                            titleBeforeEditing = title
                        }
                    } onCommit: {
                        saveButtonEnabled = titleBeforeEditing != title
                    }
                }
                
                Section(header: Text("Note")) {
                    TextField("Note", text: $note) { isEditing in
                        if isEditing && noteBeforeEditing == "" {
                            noteBeforeEditing = note
                        }
                    } onCommit: {
                        saveButtonEnabled = noteBeforeEditing != note
                    }
                }
                
                Section(header: Text("Tags")) {
                    ForEach(tags) { tag in
                        Text(tag.name ?? "")
                    }
                }
            }
            
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Label("Cancel", systemImage: "chevron.backward")
                })
                
                Spacer()
                
                Button(action: {
                    self.save()
                }, label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                })
                .disabled(!saveButtonEnabled)
                .foregroundColor(saveButtonEnabled ? Color.blue : Color.gray)
            }
            
        }
        .padding()
    }
    
    private func save() -> Void {
        linkCollectorViewModel.linkDTO = LinkDTO(id: id, title: title, note: note)
        presentationMode.wrappedValue.dismiss()
    }
}

struct EditLinkView_Previews: PreviewProvider {
    static var previews: some View {
        EditLinkView(id: UUID(), title: "title", note: "note", tags: [TagEntity]())
    }
}
