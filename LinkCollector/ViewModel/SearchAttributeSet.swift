//
//  SearchAttributeSet.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/9/25.
//

import CoreSpotlight

struct SearchAttributeSet: Sendable {
    private let contentType = UTType.text
    
    let uid: String
    let url: URL?
    let title: String?
    let note: String?
    let locality: String?
    
    func getCSSearchableItemAttributeSet() -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: contentType)
        attributeSet.url = url
        attributeSet.title = title
        attributeSet.displayName = title
        attributeSet.comment = note
        attributeSet.city = locality
        return attributeSet
    }
}
