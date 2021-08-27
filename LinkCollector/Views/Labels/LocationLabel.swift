//
//  LocationLabel.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 8/26/21.
//

import SwiftUI

struct LocationLabel: View {
    var title: String
    
    var body: some View {
        Label(title, systemImage: "location")
    }
}

struct LocationLabel_Previews: PreviewProvider {
    static var previews: some View {
        LocationLabel(title: "Location")
    }
}
