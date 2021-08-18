//
//  EditLinkViewModel.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/17/21.
//

import Foundation
import Combine
import CoreData

class EditLinkViewModel: NSObject, ObservableObject {
    @Published var title: String = ""
    @Published var note: String = ""
    @Published var tags = [String]()
    
    var entity: LinkEntity
    
    var titleUpdated = false
    var noteUpdated = false
    
    private let persistenteContainer = PersistenceController.shared.container
    
    init(linkEntity: LinkEntity) {
        self.entity = linkEntity
        self.title = entity.title ?? ""
        
        super.init()
    }
    
}
