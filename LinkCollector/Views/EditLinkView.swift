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
    @EnvironmentObject var editLinkViewModel: EditLinkViewModel
    
    @State var presenting = false
    
    @State var title = ""
    @State var note = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Title")
                
                Spacer()
                
                TextField("Title", text: $editLinkViewModel.title) { isEditing in
                    print("\(isEditing)")
                } onCommit: {
                    _ = editLinkViewModel.$title
                        .sink() { _ in
                            editLinkViewModel.titleUpdated.toggle()
                        }
                }
            }
            
            HStack {
                Text("Note")
                
                Spacer()
                
                TextField("Note", text: $editLinkViewModel.note) { isEditing in
                    print("\(isEditing)")
                } onCommit: {
                    _ = editLinkViewModel.$note
                        .sink() { _ in
                            editLinkViewModel.noteUpdated.toggle()
                        }
                }
            }
            
        }
        .navigationBarItems(trailing:
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }, label: {
                                    Label("Save", systemImage: "square.and.arrow.down")
                                }))
    }
    
    private func save() -> Void {
        
        
        self.presenting.toggle()
    }
}

struct EditLinkView_Previews: PreviewProvider {
    static var previews: some View {
        EditLinkView()
    }
}
