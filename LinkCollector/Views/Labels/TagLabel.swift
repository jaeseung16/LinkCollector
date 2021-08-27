//
//  TagLabel.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/26/21.
//

import SwiftUI

struct TagLabel: View {
    var title: String
    
    var body: some View {
        Label(title, systemImage: "tag")
    }
}

struct TagLabel_Previews: PreviewProvider {
    static var previews: some View {
        TagLabel(title: "tag")
    }
}
