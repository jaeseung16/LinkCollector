//
//  SnapshotView.swift
//  LinkPiler
//
//  Created by Jae Seung Lee on 3/2/25.
//

import SwiftUI
import PDFKit

struct SnapshotView: UIViewRepresentable {
    @State var pdfData: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.document = PDFDocument(data: pdfData)
    }
}
