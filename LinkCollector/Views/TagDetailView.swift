//
//  TagDetailView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 4/6/25.
//

import SwiftUI

struct TagDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    var entity: TagEntity
    
    private var links: [LinkEntity] {
        entity.links?.compactMap {
            if let link = $0 as? LinkEntity {
                return link
            } else {
                return nil
            }
        } ?? [LinkEntity]()
    }
    
    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(links) { link in
                    if let url = link.url {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "link")
                                Spacer()
                                LinkLabel(link: link)
                            }
                        }
                    } else {
                        VStack {
                            LinkLabel(link: link)
                            Text("Cannot open this link in brower.")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
